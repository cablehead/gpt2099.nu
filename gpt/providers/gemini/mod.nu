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
      collect {|events|
        # Define the standard response shape
        mut response = {
          role: "assistant"
          mime_type: "application/json"
          message: {
            type: "message"
            role: "assistant"
            content: []
          }
        }

        # Track text content during processing
        mut current_text = ""
        
        # Process each event
        for event in $events {
          if ($event | describe) == "list<list>" {
            # Extract model information from the first event if available
            if ($response.message.model? | is-empty) and ($event | get 2? | is-not-empty) {
              $response.message.model = ($event | get 2)
            }
            
            # Get candidate information
            let candidate = ($event | get 1?)
            if $candidate == null { continue }
            
            # Process content (text)
            if ($candidate | get 0? | where $it == "content" | length) > 0 {
              let content = ($candidate | get 1 | get 0?)
              if $content != null {
                # Extract text content if present
                if ($content | get parts? | describe) == "list<list>" {
                  let parts = ($content | get parts)
                  if ($parts | get 0? | get 0?) == "text" {
                    $current_text = $current_text + ($parts | get 0 | get 1)
                  }
                  
                  # Check for function call in the same content block
                  if ($parts | length) > 0 and ($parts | where $it.0? == "functionCall" | length) > 0 {
                    let function_part = ($parts | where $it.0? == "functionCall" | first)
                    let function_call = ($function_part | get 1 | get 0?)
                    
                    # Add text content if we have any accumulated
                    if ($current_text | is-not-empty) {
                      $response.message.content = ($response.message.content | append {
                        type: "text"
                        text: $current_text
                      })
                      $current_text = ""
                    }
                    
                    # Add tool use
                    $response.message.content = ($response.message.content | append {
                      type: "tool_use"
                      name: $function_call.name
                      input: $function_call.args
                    })
                  }
                }
              }
            }
            
            # Check for finish reason
            if ($candidate | get 0? | where $it == "finishReason" | length) > 0 {
              # Set stop reason if function call was the last thing
              if ($response.message.content | last? | get type?) == "tool_use" {
                $response.message.stop_reason = "tool_use"
              }
              
              # Process usage data if available
              if ($event | get 2? | is-not-empty) {
                let usage_data = ($event | get 2)
                $response.message.usage = {
                  input_tokens: ($usage_data | get promptTokenCount | default 0)
                  cache_creation_input_tokens: 0
                  cache_read_input_tokens: 0
                  output_tokens: ($usage_data | get candidatesTokenCount | default 0)
                }
              }
            }
          }
        }

        # If we have any remaining text, add it
        if ($current_text | is-not-empty) {
          $response.message.content = ($response.message.content | append {
            type: "text"
            text: $current_text
          })
        }

        return $response
      }
    }

    response_stream_streamer: {|event|
      $event
    }
  }
}
