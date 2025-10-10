# Recursively strip unsupported JSON schema fields for Cerebras
# Removes: $schema, format, minimum, nullable at all nesting levels
def clean-schema-recursive [] {
  let input = $in
  let input_type = ($input | describe -d | get type)

  if $input_type == "record" {
    # Strip unsupported fields from this record level
    let cleaned = $input | reject --optional '$schema' format minimum nullable

    # Recursively clean all nested values
    $cleaned | items {|key val|
      {$key: ($val | clean-schema-recursive)}
    } | into record
  } else if $input_type == "list" {
    # Recursively clean all items in the list
    $input | each {|item| $item | clean-schema-recursive}
  } else {
    # Primitive value - return as-is
    $input
  }
}

export def convert-mcp-toolslist-to-provider [] {
  $in | each {|tool|
    # Recursively clean the entire inputSchema
    let clean_schema = $tool.inputSchema | clean-schema-recursive

    {
      type: "function"
      function: {
        name: $tool.name
        description: $tool.description
        parameters: $clean_schema
      }
    }
  }
}

export def provider [] {
  {
    models: {|key: string|
      (http get --allow-errors -H {"Authorization": $"Bearer ($key)"} "https://api.cerebras.ai/v1/models")
      | metadata access {|meta|
        if $meta.http_response.status != 200 {
          error make {
            msg: $"Error fetching models: ($meta.http_response | to json) ($in)"
          }
        } else { }
      }
      | get data
      | select id created
      | update created { $in * 1_000_000_000 | into datetime }
      | sort-by -r created
    }

    prepare-request: {|ctx: record tools?: list<record>|
      # Cerebras doesn't support built-in search
      if ($ctx.options?.search? | default false) {
        error make {msg: "Cerebras does not support built-in search capabilities"}
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
          [
            {
              role: "assistant"
              content: ($m.content | where type == "text" | get text? | default [] | str join "")
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
            # Build content array with text and file parts
            let content_parts = (
              []
              | append (
                $m.content | where type == "text" | each {|t|
                  {type: "text" text: $t.text}
                }
              )
              | append (
                $m.content | where type == "document" | each {|d|
                  # Cerebras supports images via image_url and PDFs via file type (OpenAI-compatible)
                  # Other document types are not supported
                  if ($d.source.media_type | str starts-with "image/") {
                    # Images use image_url format
                    {
                      type: "image_url"
                      image_url: {
                        url: $"data:($d.source.media_type);base64,($d.source.data)"
                      }
                    }
                  } else if $d.source.media_type == "application/pdf" {
                    # PDFs use file format
                    {
                      type: "file"
                      file: {
                        filename: "document.pdf"
                        file_data: $"data:($d.source.media_type);base64,($d.source.data)"
                      }
                    }
                  } else {
                    # Unsupported document types - throw error
                    error make {msg: $"Cerebras does not support document type: ($d.source.media_type)"}
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
      let url = "https://api.cerebras.ai/v1/chat/completions"
      (
        $in
        | insert model $model
        | http post --allow-errors --content-type application/json -H {"Authorization": $"Bearer ($key)"} $url
        | metadata access {|meta|

          if $meta.http_response.status != 200 {
            error make {
              msg: $"Error calling cerebras: ($meta.http_response | to json) ($in)"
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
      let delta = $event.choices?.0?.delta?
      if $delta == null {
        return null
      }

      # Handle text content
      if ($delta.content? | is-not-empty) {
        return {type: "text" content: $delta.content}
      }

      # Handle tool calls (Cerebras uses OpenAI-compatible tool_calls array)
      if ($delta.tool_calls? | is-not-empty) {
        let tool_call = $delta.tool_calls.0

        # First chunk includes function name and id
        if ($tool_call.function?.name? | is-not-empty) {
          return {
            type: "tool_use"
            name: $tool_call.function.name
            id: $tool_call.id
          }
        }

        # Subsequent chunks are just arguments
        if ($tool_call.function?.arguments? | is-not-empty) {
          return {content: $tool_call.function.arguments}
        }
      }

      null
    }

    response_stream_aggregate: {||
      collect {|events|
        mut model = null
        mut text_content = ""
        mut tool_calls_map = {}
        mut finish_reason = null

        # Process all events to accumulate content
        for event in $events {
          # Extract model from first event (or any event)
          if $model == null and ($event.model? | is-not-empty) {
            $model = $event.model
          }

          let delta = $event.choices?.0?.delta?
          if $delta == null { continue }

          # Accumulate text content
          if ($delta.content? | is-not-empty) {
            $text_content = $text_content + $delta.content
          }

          # Accumulate tool calls by index
          if ($delta.tool_calls? | is-not-empty) {
            for tool_call_delta in $delta.tool_calls {
              let idx_str = ($tool_call_delta.index | into string)

              # Check if this index already exists
              let exists = ($idx_str in ($tool_calls_map | columns))

              if not $exists {
                # Initialize new tool call
                $tool_calls_map = $tool_calls_map | insert $idx_str {
                  id: ($tool_call_delta.id? | default "")
                  type: ($tool_call_delta.type? | default "function")
                  function: {
                    name: ($tool_call_delta.function?.name? | default "")
                    arguments: ($tool_call_delta.function?.arguments? | default "")
                  }
                }
              } else {
                # Accumulate arguments for existing tool call
                let existing = $tool_calls_map | get $idx_str
                $tool_calls_map = $tool_calls_map | update $idx_str {
                  id: (if ($tool_call_delta.id? | is-not-empty) { $tool_call_delta.id } else { $existing.id })
                  type: (if ($tool_call_delta.type? | is-not-empty) { $tool_call_delta.type } else { $existing.type })
                  function: {
                    name: (if ($tool_call_delta.function?.name? | is-not-empty) { $tool_call_delta.function.name } else { $existing.function.name })
                    arguments: ($existing.function.arguments + ($tool_call_delta.function?.arguments? | default ""))
                  }
                }
              }
            }
          }

          # Capture finish reason from choices
          let reason = $event.choices?.0?.finish_reason?
          if ($reason | is-not-empty) {
            $finish_reason = $reason
          }
        }

        # Build content array
        mut content = []
        if ($text_content | is-not-empty) {
          $content = $content | append {type: "text" text: $text_content}
        }

        # Convert tool calls map to content array
        let tool_calls = $tool_calls_map | values
        if ($tool_calls | is-not-empty) {
          for tool_call in $tool_calls {
            $content = $content | append {
              type: "tool_use"
              id: (random uuid)
              name: $tool_call.function.name
              input: ($tool_call.function.arguments | from json)
            }
          }
        }

        # Determine stop reason
        let stop_reason = if ($tool_calls | is-not-empty) {
          "tool_use"
        } else if $finish_reason == "stop" {
          "end_turn"
        } else {
          "end_turn"
        }

        {
          message: {
            type: "message"
            role: "assistant"
            model: $model
            content: $content
            stop_reason: $stop_reason
            usage: {
              input_tokens: 0
              cache_creation_input_tokens: 0
              cache_read_input_tokens: 0
              output_tokens: 0
            }
          }
        }
      }
    }
  }
}
