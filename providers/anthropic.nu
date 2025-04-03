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
    "tool_use" => ($content_block | update input {|x| $x.partial_json | str join | from json } | reject partial_json?)
    _ => { error make {msg: $"TBD: ($content_block)"} }
  }
}

export def convert-mcp-toolslist-to-provider [] {
  rename -c {inputSchema: input_schema}
}
export def main [] {
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

    call: {|key: string model: string tools?: list|
      # anthropic only supports a single system message as a top level attribute
      let messages = $in
      let system_messages = $messages | where role == "system"
      let messages = $messages | where role != "system"

      let data = {
        model: $model
        max_tokens: 8192
        stream: true
        messages: $messages
        tools: ($tools | default [] | convert-mcp-toolslist-to-provider)
      } | conditional-pipe ($system_messages | is-not-empty) {
        insert "system" ($system_messages | get content | flatten)
      }

      let headers = {
        "x-api-key": $key
        "anthropic-version": "2023-06-01"
      }

      if false {
        print $"data: ($data | to json)"
        print $"headers: ($headers | to json)"
        return (
          http post --full --allow-errors
          --content-type application/json
          -H $headers
          https://api.anthropic.com/v1/messages
          $data
        )
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

    response_stream_streamer: {|streamer: closure|
      generate {|event cont = true|
        match $event.type {
          "content_block_start" => { return {next: true out: $event} }
          "content_block_delta" => { return {next: true out: $event} }
        }

        return {next: true}
      }
    }
  }
}
