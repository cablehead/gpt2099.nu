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
      # Start from scratch with something we know works for Gemini's unique response format
      $in | do {
        mut text_content = ""
        mut has_tool_use = false
        mut tool_use_name = ""
        mut tool_use_input = {}
        mut model = ""
        mut input_tokens = 0
        mut output_tokens = 0
        
        # Process each event
        for event in $in {
          # Extract model information (in the 3rd position)
          if $model == "" and ($event | get 2?) != null {
            $model = $event | get 2
          }
          
          # Get the candidate (in the 2nd position)
          if ($event | get 1?) != null {
            let candidate = $event | get 1
            
            # Check for text content
            if ($candidate | get 0? | where $it == "content" | length) > 0 {
              if ($candidate | get 1? | get 0? | get parts? | length) > 0 {
                let parts = $candidate | get 1 | get 0 | get parts
                
                # Extract text
                if ($parts | get 0? | get 0?) == "text" {
                  $text_content = $text_content + ($parts | get 0 | get 1)
                }
                
                # Extract function call
                if ($parts | get 0? | get 0?) == "functionCall" {
                  $has_tool_use = true
                  $tool_use_name = ($parts | get 0 | get 1 | get 0 | get name)
                  $tool_use_input = ($parts | get 0 | get 1 | get 0 | get args)
                }
              }
            }
            
            # Check for usage information
            if ($event | get 2? | get promptTokenCount?) != null {
              $input_tokens = $event | get 2 | get promptTokenCount
              $output_tokens = $event | get 2 | get candidatesTokenCount | default 0
            }
          }
        }
        
        # Construct the response
        mut response = {
          role: "assistant"
          mime_type: "application/json"
          message: {
            type: "message"
            role: "assistant"
            model: $model
            content: []
            usage: {
              input_tokens: $input_tokens
              cache_creation_input_tokens: 0
              cache_read_input_tokens: 0
              output_tokens: $output_tokens
            }
          }
        }
        
        # Add text content if any
        if $text_content != "" {
          $response.message.content = $response.message.content | append {
            type: "text"
            text: $text_content
          }
        }
        
        # Add tool use if any
        if $has_tool_use {
          $response.message.content = $response.message.content | append {
            type: "tool_use"
            name: $tool_use_name
            input: $tool_use_input
          }
          
          # Set stop reason for tool use
          $response.message.stop_reason = "tool_use"
        }
        
        $response
      }
    }

    response_stream_streamer: {|event|
      $event
    }
  }
}
