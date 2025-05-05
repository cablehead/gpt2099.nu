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
      } | if ($tools | is-not-empty) {
        insert "tools" ($tools | convert-mcp-toolslist-to-provider)
      } | if ($system_messages | is-not-empty) {
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
        
        # Extract the model name from the first event
        if ($events | length) > 0 {
          let first_event = $events | first
          if ($first_event | describe) =~ "list" {
            let model_version = $first_event | last
            $response.message.model = $model_version
          }
        }
        
        # Extract all text content and look for function calls
        mut text_content = ""
        mut has_tool_use = false
        mut tool_use_name = ""
        mut tool_use_input = {}

        for event in $events {
          if ($event | describe) =~ "list" {
            # Look for content in the event structure
            if ($event | get 1 | describe) =~ "list" {
              let candidate = $event | get 1
              
              # Check for text content
              if ($candidate | get 0? | get 0?) == "content" {
                if ($candidate | get 1? | get 0? | get parts?) != null {
                  let parts = $candidate | get 1 | get 0 | get parts
                  
                  # Extract text content
                  if ($parts | get 0? | get 0?) == "text" {
                    $text_content = $text_content + ($parts | get 0 | get 1)
                  }
                  
                  # Look for function call
                  if ($parts | get 0? | get 0?) == "functionCall" {
                    $has_tool_use = true
                    if ($parts | get 0? | get 1? | get 0? | get name?) != null {
                      $tool_use_name = $parts | get 0 | get 1 | get 0 | get name
                    }
                    if ($parts | get 0? | get 1? | get 0? | get args?) != null {
                      $tool_use_input = $parts | get 0 | get 1 | get 0 | get args
                    }
                  }
                }
              }

              # Check for finish reason to determine stop_reason
              if ($candidate | get 0? | get 0?) == "finishReason" {
                if ($candidate | get 1?) == "STOP" and $has_tool_use {
                  $response.message.stop_reason = "tool_use"
                }
              }
            }

            # Extract usage data
            if ($event | get 2? | describe) =~ "record" {
              let usage_data = $event | get 2
              if ($usage_data | get promptTokenCount?) != null {
                $response.message.usage = {
                  input_tokens: ($usage_data | get promptTokenCount)
                  cache_creation_input_tokens: 0
                  cache_read_input_tokens: 0
                  output_tokens: ($usage_data | get candidatesTokenCount | default 0)
                }
              }
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
        
        $response
      }
    }

    response_stream_streamer: {|event|
      $event
    }
  }
}
