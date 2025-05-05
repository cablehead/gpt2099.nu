def conditional-pipe [
  condition: bool
  action: closure
] {
  if $condition { do $action } else { $in }
}

export def convert-mcp-toolslist-to-provider [] {
  let tools = $in
  let decls = ($tools | rename -c {inputSchema: parameters})
  [{functionDeclarations: $decls}]
}

export def provider [] {
  {
    models: {|key|
      (
        http get $"https://generativelanguage.googleapis.com/v1beta/models?key=($key)"
        | get models | select name version supportedGenerationMethods
        | where {|it| 'generateContent' in $it.supportedGenerationMethods }
        | update name {|it| $it.name | str replace 'models/' '' } | get name | wrap id
      )
    }

    call: {|key: string model: string tools?: list|
      # gemini only supports a single system message as a top level attribute
      let messages = $in
      let system_messages = $messages | where role == "system"
      let messages = $messages | where role != "system"

      let data = {
        contents: (
          $messages | each {|msg|
            {
              role: (if $msg.role == "assistant" { 'model' } else { $msg.role })
              parts: (
                $msg.content | each {|content|
                  {text: $content.text}
                }
              )
            }
          }
        )
        generationConfig: {
          temperature: 1
          topP: 0.95
          maxOutputTokens: 8192
        }
      } | conditional-pipe ($tools | is-not-empty) {
        insert "tools" ($tools | convert-mcp-toolslist-to-provider)
      } | conditional-pipe ($system_messages | is-not-empty) {
        # system_instruction: {
        # parts: [{text: "You are a helpful assistant."}]
        # }
        insert "systemInstruction" {parts: ($system_messages | get content)}
      }

      let url = $"https://generativelanguage.googleapis.com/v1beta/models/($model):streamGenerateContent?alt=sse&key=($key)"

      # let res = $data | http post -f -e --content-type application/json $url
      # error make {msg: $"TBD:\n\n($messages | to json | table -e)\n\n($res | to json)"}

      $data | http post --content-type application/json $url
      | lines | each {|line| $line | split row -n 2 "data: " | get 1? }
      | each {|x| $x | from json }
    }

    response_stream_aggregate: {||
      # Start building the proper response incrementally
      collect {|events|
        # Initialize the basic structure
        mut response = {
          role: "assistant"
          mime_type: "application/json"
          message: {
            type: "message"
            role: "assistant"
            content: []
          }
        }

        # Extract model name and accumulate text content
        mut text_content = ""
        mut has_tool_use = false
        mut tool_use_name = ""
        mut tool_use_input = {}

        for event in $events {
          # Set model from version info
          if ($event | get modelVersion?) != null {
            $response.message.model = $event.modelVersion
          }

          # Process candidates
          if ($event | get candidates?) != null {
            for candidate in $event.candidates {
              # Process text content
              if ($candidate | get content? | get parts?) != null {
                for part in $candidate.content.parts {
                  if ($part | get text?) != null {
                    $text_content = $text_content + $part.text
                  }

                  # Process function call/tool use
                  if ($part | get functionCall?) != null {
                    $has_tool_use = true
                    $tool_use_name = $part.functionCall.name
                    $tool_use_input = $part.functionCall.args
                  }
                }
              }
            }
          }

          # Set finish reason
          if ($event | get finishReason?) != null {
            # If it's a STOP reason and we have a tool use, set stop_reason to tool_use
            if $event.finishReason == "STOP" and $has_tool_use {
              $response.message.stop_reason = "tool_use"
            }
          }

          # Process usage info
          if ($event | get usageMetadata?) != null {
            $response.message.usage = {
              input_tokens: ($event.usageMetadata.promptTokenCount)
              cache_creation_input_tokens: 0
              cache_read_input_tokens: 0
              output_tokens: ($event.usageMetadata | get candidatesTokenCount? | default 0)
            }
          }
        }

        # Add text content if we found any
        if $text_content != "" {
          $response.message.content = $response.message.content | append {
            type: "text"
            text: $text_content
          }
        }

        # Add tool use if found
        if $has_tool_use {
          $response.message.content = $response.message.content | append {
            type: "tool_use"
            name: $tool_use_name
            input: $tool_use_input
          }

          # Make sure stop_reason is set
          $response.message.stop_reason = "tool_use"
        }

        $response
      }
    }

    response_stream_streamer: {|event|
      $event | get candidates.0.content.parts.0 | transpose type content | first | if $in.type == "functionCall" {
        {
          type: "tool_use"
          name: $in.content.name
          content: $in.content.args
        }
      } else { $in }
    }

    response_to_mcp_toolscall: {||
      ignore
    }

    mcp_toolscall_response_to_provider: {||
      ignore
    }
  }
}
