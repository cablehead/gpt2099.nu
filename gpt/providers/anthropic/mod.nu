def conditional-pipe [
  condition: bool
  action: closure
] {
  if $condition { do $action } else { $in }
}

# aggregation
def content-block-delta [current_block event] {
  match $event.delta.type {
    "text_delta" => ($current_block | update text { $in | append $event.delta.text })
    "input_json_delta" => ($current_block | upsert partial_json { $in | default [] | append $event.delta.partial_json })
    _ => ( error make {msg: $"TBD: ($event)"})
  }
}

def content-block-finish [content_block] {
  match $content_block.type {
    "text" => ($content_block | update text { str join })
    "tool_use" => ($content_block | update input {|x| $x.partial_json | str join | from json | default {} } | reject partial_json?)
    _ => { error make {msg: $"TBD: ($content_block)"} }
  }
}

export def convert-mcp-toolslist-to-provider [] {
  $in | each {|tool|
    $tool | rename -c {inputSchema: input_schema} | reject -i annotations
  }
}

export def provider [] {
  {
    models: {|key: string|
      (
        http get
        -H {
          "x-api-key": $key
          "anthropic-version": "2023-06-01"
        }
        https://api.anthropic.com/v1/models
        | get data
        | select id created_at
        | rename -c {created_at: "created"}
        | update created { into datetime }
        | sort-by -r created
      )
    }

    prepare-request: {|tools?: list|
      # anthropic only supports a single system message as a top level attribute
      let messages = $in
      let system_messages = $messages | where role == "system"
      let messages = $messages | where role != "system"

      let messages = $messages | each {|msg|
        update content {|content|
          each {|part|
            match $part.type {
              "tool_result" => ($part | reject -i name)
              _ => $part
            }
          }
        }
      }

      let data = {
        max_tokens: 8192
        stream: true
        messages: $messages
        tools: ($tools | default [] | convert-mcp-toolslist-to-provider)
      } | conditional-pipe ($system_messages | is-not-empty) {
        insert "system" ($system_messages | get content | flatten | str join "\n\n----\n\n")
      }

      return $data
    }

    call: {|key: string model: string|
      let data = $in | insert model $model # Fill in the model from the call parameters

      let headers = {
        "x-api-key": $key
        "anthropic-version": "2023-06-01"
      }

      if false {
        print $"data: ($data | to json)"
        print $"headers: ($headers | to json)"
        print (
          http post --full --allow-errors
          --content-type application/json
          -H $headers
          https://api.anthropic.com/v1/messages
          $data | table -e
        )
        error make {msg: "peace."}
      }

      (
        http post
        --content-type application/json
        -H $headers
        https://api.anthropic.com/v1/messages
        $data
        | lines
        | each {|line| $line | split row -n 2 "data: " | get 1? }
        | each {|x| $x | from json }
      )
    }

    response_stream_aggregate: {||
      collect {|events|
        mut response = {
          role: "assistant"
          mime_type: "application/json"
        }
        for event in $events {
          match $event.type {
            "message_start" => ($response.message = $event.message)
            "content_block_start" => ($response.current_block = $event.content_block)
            "content_block_delta" => ($response.current_block = content-block-delta $response.current_block $event)
            "content_block_stop" => ($response.message.content =  $response.message.content | append (content-block-finish $response.current_block))
            "message_delta" => ($response = ($response | merge deep {message: ($event.delta | insert usage $event.usage)}))
            "message_stop" => ($response = ($response | reject current_block))
            "ping" => (continue)
            _ => (
              error make {msg: $"\n\n($response | table -e)\n\n($event | table -e)"}
            )
          }
        }

        $response
      }
    }

    # Transforms Anthropic's events into normalized stream format
    # Returns either:
    # 1. {type: string, name?: string} for content block start events
    # 2. {content: string} for content additions
    response_stream_streamer: {|event|
      match $event.type {
        # For content_block_start events, return a type indicator
        # This marks the beginning of a new content block (text, tool_use, etc.)
        "content_block_start" => {
          # Extract type and other relevant fields but remove input/text
          return ($event.content_block | reject -i input | reject -i text)
        }

        # For content_block_delta events, return content additions
        "content_block_delta" => {
          match $event.delta.type {
            # Text deltas become content additions
            "text_delta" => { return {content: $event.delta.text} }

            # JSON deltas for tool use become content additions
            "input_json_delta" => { return {content: $event.delta.partial_json} }

            # Handle unexpected delta types
            _ => ( error make {msg: $"TBD: ($event)"})
          }
        }

        # Other event types are implicitly ignored (null is returned)
      }
    }
  }
}
