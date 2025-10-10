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
      (http get --allow-errors -H {"Authorization": $"Bearer ($key)"} "https://api.cohere.com/v1/models")
      | metadata access {|meta|
        if $meta.http_response.status != 200 {
          error make {
            msg: $"Error fetching models: ($meta.http_response | to json) ($in)"
          }
        } else { }
      }
      | get models
      | where {|model| "chat" in $model.endpoints}
      | rename -c {name: id}
    }

    prepare-request: {|ctx: record tools?: list<record>|
      # Cohere doesn't support built-in search
      if ($ctx.options?.search? | default false) {
        error make {msg: "Cohere does not support built-in search capabilities"}
      }

      # Check for unsupported documents first
      for msg in $ctx.messages {
        let has_documents = ($msg.content | where type == "document" | is-not-empty)
        if $has_documents {
          let doc = $msg.content | where type == "document" | first
          error make {msg: $"Cohere does not support document type: ($doc.source.media_type)"}
        }
      }

      # Transform messages
      let messages = $ctx.messages | each {|m|
        {
          role: $m.role
          content: ($m.content | where type == "text" | get text | str join "")
        }
      }

      let payload = {
        stream: true
        messages: $messages
        tools: (if ($tools | is-not-empty) { $tools | convert-mcp-toolslist-to-provider } else { [] })
      }

      $payload
    }

    call: {|key: string model: string|
      let url = "https://api.cohere.com/v2/chat"
      (
        $in
        | insert model $model
        | http post --allow-errors --content-type application/json -H {"Authorization": $"Bearer ($key)"} $url
        | metadata access {|meta|
          if $meta.http_response.status != 200 {
            error make {
              msg: $"Error calling cohere: ($meta.http_response | to json) ($in)"
            }
          } else { }
        }
        | lines
        | each {|line| $line | split row -n 2 "data: " | get 1? }
        | where $it != null and $it != "[DONE]"
        | each {|x| $x | from json }
      )
    }

    response_stream_streamer: {|event|
      # Handle different Cohere event types
      let event_type = $event.type?

      if $event_type == null {
        return null
      }

      match $event_type {
        "content-delta" => {
          # Text content being streamed (skip thinking content from reasoning models)
          let text = $event.delta?.message?.content?.text?
          if ($text | is-not-empty) {
            return {type: "text" content: $text}
          }
          null
        }
        "tool-call-start" => {
          # Tool call beginning
          let tool_call = $event.delta?.message?.tool_calls?
          if ($tool_call | is-not-empty) {
            return {
              type: "tool_use"
              name: $tool_call.function.name
              id: $tool_call.id
            }
          }
          null
        }
        "tool-call-delta" => {
          # Tool call arguments being streamed
          let params = $event.delta?.message?.tool_calls?.function?.parameters?
          if ($params | is-not-empty) {
            return {content: $params}
          }
          null
        }
        _ => null
      }
    }

    response_stream_aggregate: {||
      collect {|events|
        mut text_content = ""
        mut tool_calls = []
        mut finish_reason = "end_turn"
        mut usage = {
          input_tokens: 0
          cache_creation_input_tokens: 0
          cache_read_input_tokens: 0
          output_tokens: 0
        }

        # Process all events
        for event in $events {
          let event_type = $event.type?

          if $event_type == "content-delta" {
            # Accumulate text content
            let text = $event.delta?.message?.content?.text?
            if ($text | is-not-empty) {
              $text_content = $text_content + $text
            }
          } else if $event_type == "tool-call-delta" {
            # Accumulate tool calls
            let tool_call = $event.delta?.message?.tool_calls?
            if ($tool_call | is-not-empty) {
              $tool_calls = $tool_calls | append $tool_call
            }
          } else if $event_type == "message-end" {
            # Extract finish reason and usage
            $finish_reason = $event.delta?.finish_reason? | default "end_turn"
            let billed = $event.delta?.usage?.billed_units?
            if ($billed | is-not-empty) {
              $usage = {
                input_tokens: ($billed.input_tokens? | default 0)
                cache_creation_input_tokens: 0
                cache_read_input_tokens: 0
                output_tokens: ($billed.output_tokens? | default 0)
              }
            }
          }
        }

        # Build content array
        mut content = []
        if ($text_content | is-not-empty) {
          $content = $content | append {type: "text" text: $text_content}
        }

        # Add tool calls to content
        if ($tool_calls | is-not-empty) {
          for tool_call in $tool_calls {
            $content = $content | append {
              type: "tool_use"
              id: (random uuid)
              name: $tool_call.function.name
              input: ($tool_call.function.parameters | from json)
            }
          }
        }

        # Determine stop reason
        let stop_reason = if ($tool_calls | is-not-empty) {
          "tool_use"
        } else {
          "end_turn"
        }

        {
          message: {
            type: "message"
            role: "assistant"
            model: "cohere"
            content: $content
            stop_reason: $stop_reason
            usage: $usage
          }
        }
      }
    }
  }
}
