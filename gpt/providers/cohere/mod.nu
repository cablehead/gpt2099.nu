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

      # Transform messages
      let messages = $ctx.messages | each {|m|
        # Check if this is an assistant message with tool_use
        let tool_uses = $m.content | where type == "tool_use"

        # Check if this is a user message with tool_result
        let tool_results = $m.content | where type == "tool_result"

        if ($tool_uses | is-not-empty) {
          # Assistant message with tool calls
          let tool_calls_array = $tool_uses | each {|tu|
            {
              id: $tu.id
              type: "function"
              function: {
                name: $tu.name
                arguments: ($tu.input | to json -r)
              }
            }
          }
          let text_content = ($m.content | where type == "text" | get text? | default [] | str join "")
          [
            {
              role: "assistant"
              content: (if ($text_content | is-empty) { null } else { $text_content })
              tool_calls: $tool_calls_array
            }
          ]
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
            # Build content array with text and document parts
            let content_parts = (
              []
              | append (
                $m.content | where type == "text" | each {|t|
                  {type: "text" text: $t.text}
                }
              )
              | append (
                $m.content | where type == "document" | each {|d|
                  let media_type = $d.source.media_type
                  if ($media_type | str starts-with "image/") {
                    # Images use image_url format (similar to OpenAI)
                    {
                      type: "image_url"
                      image_url: {
                        url: $"data:($media_type);base64,($d.source.data)"
                      }
                    }
                  } else {
                    # Unsupported document types
                    error make {msg: $"Cohere does not support document type: ($media_type)"}
                  }
                }
              )
            )
            [
              {
                role: $m.role
                content: $content_parts
              }
            ]
          } else {
            # Text-only message
            [
              {
                role: $m.role
                content: ($m.content | where type == "text" | get text | str join "")
              }
            ]
          }
        }
      } | flatten

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
          let args = $event.delta?.message?.tool_calls?.function?.arguments?
          if ($args | is-not-empty) {
            return {content: $args}
          }
          null
        }
        _ => null
      }
    }

    response_stream_aggregate: {||
      collect {|events|
        mut text_content = ""
        mut tool_call_id = null
        mut tool_call_name = null
        mut tool_call_arguments = ""
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
          } else if $event_type == "tool-call-start" {
            # Start of tool call - capture id and name
            let tool_call = $event.delta?.message?.tool_calls?
            if ($tool_call | is-not-empty) {
              $tool_call_id = $tool_call.id
              $tool_call_name = $tool_call.function.name
              $tool_call_arguments = ($tool_call.function?.arguments? | default "")
            }
          } else if $event_type == "tool-call-delta" {
            # Accumulate tool call arguments
            let args = $event.delta?.message?.tool_calls?.function?.arguments?
            if ($args | is-not-empty) {
              $tool_call_arguments = $tool_call_arguments + $args
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

        # Add tool call to content if we have one
        if ($tool_call_name | is-not-empty) {
          $content = $content | append {
            type: "tool_use"
            id: $tool_call_id
            name: $tool_call_name
            input: ($tool_call_arguments | from json)
          }
        }

        # Determine stop reason
        let stop_reason = if ($tool_call_name | is-not-empty) {
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
