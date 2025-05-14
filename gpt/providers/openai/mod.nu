def conditional-pipe [
  condition: bool
  action: closure
] {
  if $condition { do $action } else { $in }
}

export def convert-mcp-toolslist-to-provider [] {
  $in | each {|tool|
    {
      name: $tool.name
      description: $tool.description
      parameters: $tool.inputSchema
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

    prepare-request: {|tools?: list|
      let messages = $in | each {|m|
        {
          role: $m.role
          content: ($m.content | where type == "text" | get text | str join "")
        }
      }

      let payload = (
        {
          messages: $messages
          stream: true
        }
        | conditional-pipe ($tools | is-not-empty) {
          insert functions ($tools | convert-mcp-toolslist-to-provider)
        }
      )

      $payload
    }

    call: {|key: string, model: string|
      let url = "https://api.openai.com/v1/chat/completions"
      (
        $in
        | insert model $model
        | http post --content-type application/json -H {"Authorization": $"Bearer ($key)"} $url
        | lines
        | each {|line| $line | split row -n 2 "data: " | get 1? }
        | each {|x| x | from json }
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
