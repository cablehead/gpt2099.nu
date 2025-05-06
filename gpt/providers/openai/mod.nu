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
      | get models
      | each {|m| { id: $m.id, created: $m.created }}
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
          model: ""
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
        { type: "text", content: $delta.content }
      } elif $delta.function_call.name? != null {
        { type: "tool_use", name: $delta.function_call.name }
      } elif $delta.function_call.arguments? != null {
        { content: $delta.function_call.arguments }
      } else {
        null
      }
    }

    response_stream_aggregate: {||
      collect {|events|
        mut response = {
          role: "assistant"
          mime_type: "application/json"
          message: { type: "message" role: "assistant" content: [] }
        }
        mut text_accum = ""
        mut saw_call = false
        mut func_name = ""
        mut arg_chunks = []

        for ev in $events {
          match $ev.type {
            "text" => { text_accum = $"($text_accum)($ev.content)" }
            "tool_use" => { saw_call = true; func_name = $ev.name }
            _ => (if $ev.content? { arg_chunks = $arg_chunks | append $ev.content })
          }
        }

        if $text_accum != "" {
          $response.message.content = ($response.message.content | append { type: "text", text: $text_accum })
        }

        if $saw_call {
          let args = ($arg_chunks | str join "" | from json)
          $response.message.content = ($response.message.content | append { type: "tool_use", name: $func_name, input: $args })
          $response.message.stop_reason = "tool_use"
        }

        $response
      }
    }
  }
}