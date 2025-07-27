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
    "citations_delta" => $current_block # ignore for now
    _ => ( error make {msg: $"TBD: ($event)"})
  }
}

def content-block-finish [content_block] {
  match $content_block.type {
    "text" => ($content_block | update text { str join })
    "tool_use" => ($content_block | update input {|x| $x.partial_json | str join | from json | default {} } | reject partial_json?)
    "server_tool_use" => ($content_block | update input {|x| $x.partial_json | str join | from json | default {} } | reject partial_json?)
    "content_block_delta" => $content_block # ignore for now
    "web_search_tool_result" => $content_block # ignore for now
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

    prepare-request: {|ctx: record tools?: list<record>|
      # anthropic only supports a single system message as a top level attribute
      let messages = $ctx.messages
      let system_messages = $messages | where role == "system"
      let messages = $messages | where role != "system"

      # Apply cache control limits at message level FIRST (max 4 breakpoints)
      # Use reverse approach: reverse -> keep first 4 cache messages -> reverse back
      let cache_count = $messages | where {|msg| $msg.cache? == true } | length

      let messages = if $cache_count > 4 {
        $messages
        | reverse
        | generate {|msg state = {cache_kept: 0}|
          if ($msg.cache? == true) and ($state.cache_kept < 4) {
            {out: $msg next: {cache_kept: ($state.cache_kept + 1)}}
          } else {
            {out: ($msg | reject -i cache) next: $state}
          }
        }
        | reverse
      } else {
        $messages
      }

      # THEN process content and apply cache to content blocks
      let messages = $messages | each {|msg|
        let has_cache = ($msg.cache? == true)
        let content = $msg.content | enumerate | each {|item|
          let part = $item.item
          let is_last = ($item.index == (($msg.content | length) - 1))

          let converted_part = match $part.type {
            "tool_result" => ($part | reject -i name)
            "document" => {
              # Convert based on media type
              let media_type = $part.source.media_type
              if ($media_type | str starts-with "text/") or ($media_type == "application/json") {
                # Decode base64 and convert to text block
                let decoded_content = $part.source.data | decode base64 | decode utf-8
                {
                  type: "text"
                  text: $decoded_content
                }
              } else if ($media_type | str starts-with "image/") {
                # Convert images to use type: "image" as per Anthropic API
                {
                  type: "image"
                  source: $part.source
                }
              } else {
                # Keep other binary documents as-is (PDFs, etc.)
                $part
              }
            }
            _ => $part
          }

          # Add cache_control to the last content block if message has cache
          if $has_cache and $is_last {
            $converted_part | insert cache_control {type: "ephemeral"}
          } else {
            $converted_part
          }
        }

        $msg | update content $content | reject -i cache
      }

      let data = {
        max_tokens: 8192
        stream: true
        messages: $messages
        tools: ($tools | default [] | convert-mcp-toolslist-to-provider)
      } | conditional-pipe ($ctx.options?.search? | default false) {
        update tools {
          $in | append {
            type: "web_search_20250305"
            name: "web_search"
          }
        }
      } | conditional-pipe ($system_messages | is-not-empty) {
        insert "system" ($system_messages | get content | flatten | get text | str join "\n\n----\n\n")
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
        mut response = {}
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
          return (
            $event.content_block | match $in.type {
              "text" => {type: $in.type content: $in.text}
              "tool_use" => {type: $in.type name: $in.name}
              "server_tool_use" => {type: $in.type name: $in.name}
              "web_search_tool_result" => {type: $in.type content: ($in.content | reject encrypted_content | to csv)}
              _ => ( error make {msg: $"TBD: ($event | to json)"})
            }
          )
        }

        # For content_block_delta events, return content additions
        "content_block_delta" => {
          match $event.delta.type {
            # Text deltas become content additions
            "text_delta" => { return {content: $event.delta.text} }

            # JSON deltas for tool use become content additions
            "input_json_delta" => { return {content: $event.delta.partial_json} }

            # with the web_search_20250305 tool we get back citations_delta:
            # need to work out what to do with this
            "citations_delta" => { return {} }

            # Handle unexpected delta types
            _ => ( error make {msg: $"TBD: ($event)"})
          }
        }

        "message_start" => { return }
        "message_delta" => { return }
        "message_stop" => { return }
        "ping" => { return }
        "content_block_stop" => { return }

        _ => ( error make {msg: $"TBD: ($event)"})
      }
    }
  }
}
