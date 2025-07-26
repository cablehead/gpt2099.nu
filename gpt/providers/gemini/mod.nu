def conditional-pipe [
  condition: bool
  action: closure
] {
  if $condition { do $action } else { $in }
}

export def convert-mcp-toolslist-to-provider [] {
  let tools = $in
  return [
    {
      functionDeclarations: (
        $tools | each {|tool|
          $tool | reject -i annotations | rename -c {
            inputSchema: parameters
          } | update parameters {
            $in | reject -i additionalProperties examples "$schema" | update properties {
              $in | items {|k v|
                {
                  $k: (
                    $v | if ($in.items? != null) {
                      update items { reject -i additionalProperties }
                    } else { $in }
                    | into record
                  )
                }
              } | into record
            }
          }
        }
      )
    }
  ]
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

    prepare-request: {|ctx: record tools?: list<record>|
      # gemini only supports a single system message as a top level attribute
      let messages = $ctx.messages
      let system_messages = $messages | where role == "system"
      let messages = $messages | where role != "system"

      let search = $ctx.options.search? | default false

      let data = {
        contents: (
          $messages | each {|msg|
            {
              role: (if $msg.role == "assistant" { 'model' } else { $msg.role })
              parts: (
                $msg.content | each {|content|
                  match $content.type {
                    "text" => {text: $content.text}
                    "tool_use" => {functionCall: {name: $content.name args: ($content.input | default {})}}
                    "tool_result" => {
                      functionResponse: {
                        name: $content.name
                        # TODO: content length > 1
                        response: ($content.content | first)
                        # Note: Deliberately omit tool_use_id - Gemini doesn't use it
                      }
                    }
                    "document" => {
                      # Convert based on media type
                      let media_type = $content.source.media_type
                      if ($media_type | str starts-with "text/") or ($media_type == "application/json") {
                        # Decode base64 and convert to text
                        let decoded_content = $content.source.data | decode base64 | decode utf-8
                        {text: $decoded_content}
                      } else if ($media_type | str starts-with "image/") or ($media_type == "application/pdf") {
                        # Convert images and PDFs to Gemini's inline_data format
                        {
                          inline_data: {
                            mime_type: $media_type
                            data: $content.source.data
                          }
                        }
                      } else {
                        # For other document types, Gemini doesn't support them directly
                        # Convert to text representation
                        {text: $"[Document: ($media_type) - content not directly supported by Gemini]"}
                      }
                    }
                    _ => ( error make {msg: $"TBD: ($content)"})
                  }
                }
              )
            }
          }
        )
      }

      let data = $data | conditional-pipe ($system_messages | is-not-empty) {
        # system_instruction: {
        # parts: [{text: "You are a helpful assistant."}]
        # }
        insert "systemInstruction" {parts: ($system_messages | get content | flatten | each { reject type })}
      }

      let data = $data | insert generationConfig {
        temperature: 1
        topP: 0.95
        maxOutputTokens: 81920
      }

      let data = $data | conditional-pipe ($tools | is-not-empty) {
        insert "tools" ($tools | convert-mcp-toolslist-to-provider)
      }

      let data = $data | conditional-pipe $search {
        insert "tools" [
          {
            google_search: {}
          }
        ]
      }

      return $data
    }

    call: {|key: string model: string|
      let data = $in

      let url = $"https://generativelanguage.googleapis.com/v1beta/models/($model):streamGenerateContent?alt=sse&key=($key)"

      if false {
        let res = $data | http post -f -e --content-type application/json $url
        error make {msg: $"TBD:\n\n($data | to json | table -e)\n\n($res | to json)"}
      }

      $data | http post --content-type application/json $url
      | lines | each {|line| $line | split row -n 2 "data: " | get 1? }
      | each {|x| $x | from json }
    }

    response_stream_aggregate: {||
      # Start building the proper response incrementally
      collect {|events|
        # Initialize the basic structure
        mut response = {
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
            id: (random uuid)  # Add random UUID for normalization
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
      let parts = $event | get candidates.0.content.parts?
      if $parts == null { return }
      $parts.0 | transpose type content | first | if $in.type == "functionCall" {
        {
          type: "tool_use"
          name: $in.content.name
          content: $in.content.args
        }
      } else { $in }
    }
  }
}
