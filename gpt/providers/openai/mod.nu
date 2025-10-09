def conditional-pipe [
  condition: bool
  action: closure
] {
  if $condition { do $action } else { $in }
}

export def convert-mcp-toolslist-to-provider [] {
  $in | each {|tool|
    {
      type: "function"
      function: {
        name: $tool.name
        description: $tool.description
        parameters: $tool.inputSchema
      }
    }
  }
}

export def provider [] {
  {
    models: {|key: string|
      (http get -H {"Authorization": $"Bearer ($key)"} "https://api.openai.com/v1/models")
      | get data
      | select id created
      | update created { $in * 1_000_000_000 | into datetime }
      | sort-by -r created
    }

    prepare-request: {|ctx: record tools?: list<record>|
      # OpenAI doesn't support built-in search
      if ($ctx.options?.search? | default false) {
        error make {msg: "OpenAI does not support built-in search capabilities"}
      }

      let messages = $ctx.messages | each {|m|
        # Check if this is an assistant message with tool_use
        let tool_uses = $m.content | where type == "tool_use"

        # Check if this is a user message with tool_result
        let tool_results = $m.content | where type == "tool_result"

        if ($tool_uses | is-not-empty) {
          # Assistant message with tool calls - ensure it's always a list
          let tool_calls_array = $tool_uses | each {|tu|
            {
              id: $tu.id
              type: "function"
              function: {
                name: $tu.name
                arguments: ($tu.input | to json -r)
              }
            }
          } | collect
          [{
            role: "assistant"
            content: ($m.content | where type == "text" | get text? | default [] | str join "")
            tool_calls: $tool_calls_array
          }]
        } else if ($tool_results | is-not-empty) {
          # Tool result messages become role: "tool"
          $tool_results | each {|tr|
            {
              role: "tool"
              tool_call_id: $tr.tool_use_id
              content: ($tr.content | get text | str join "")
            }
          }
        } else {
          # Regular message - may contain text and/or documents
          let has_documents = ($m.content | where type == "document" | is-not-empty)
          let has_text = ($m.content | where type == "text" | is-not-empty)

          if $has_documents {
            # Build content array with text and image_url parts
            let content_parts = (
              []
              | append ($m.content | where type == "text" | each {|t|
                {type: "text" text: $t.text}
              })
              | append ($m.content | where type == "document" | each {|d|
                {
                  type: "image_url"
                  image_url: {
                    url: $"data:($d.source.media_type);base64,($d.source.data)"
                  }
                }
              })
            )
            [{
              role: $m.role
              content: $content_parts
            }]
          } else {
            # Text-only message
            [{
              role: $m.role
              content: ($m.content | where type == "text" | get text | str join "")
            }]
          }
        }
      } | flatten

      let payload = (
        {
          stream: true
          messages: $messages
          tools: (if ($tools | is-not-empty) { $tools | convert-mcp-toolslist-to-provider } else { [] })
        }
      )

      $payload
    }

    call: {|key: string model: string|
      let url = "https://api.openai.com/v1/chat/completions"
      (
        $in
        | insert model $model
        | http post --content-type application/json -H {"Authorization": $"Bearer ($key)"} $url
        | lines
        | each {|line| $line | split row -n 2 "data: " | get 1? }
        | where $it != null and $it != "[DONE]"
        | each {|x| $x | from json }
      )
    }

    response_stream_streamer: {|event|
      let delta = $event.choices.0.delta
      if $delta.content? != null {
        {type: "text" content: $delta.content}
      } else {
        if $delta.function_call.name? != null {
          {type: "tool_use" name: $delta.function_call.name}
        } else {
          if $delta.function_call.arguments? != null {
            {content: $delta.function_call.arguments}
          } else {
            null
          }
        }
      }
    }

    response_stream_aggregate: {||
      collect {|events|
        let text_parts = (
          $events
          | where type == "text"
          | get content
        )

        let tool_use_event = (
          $events
          | where {|ev| $ev.type == "tool_use" }
          | first
        )

        let arg_chunks = (
          $events
          | where {|ev| $ev.type != "text" and $ev.type != "tool_use" and $ev.content? }
          | get content
        )

        let message_content = (
          []
          | if ($text_parts | is-not-empty) {
            append {type: "text" text: ($text_parts | str join "")}
          }
          | if ($tool_use_event | is-not-empty) {
            append {
              type: "tool_use"
              name: $tool_use_event.name
              input: ($arg_chunks | str join "" | from json)
            }
          }
        )

        {
          message: {
            type: "message"
            role: "assistant"
            content: $message_content
            stop_reason: (if ($tool_use_event | is-not-empty) { "tool_use" } else { "end_turn" })
          }
        }
      }
    }
  }
}
