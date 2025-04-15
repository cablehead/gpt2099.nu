# Inception Labs Provider
#
# This provider integrates with Inception Labs' Mercury API, a diffusion-based large language model
# optimized for code generation and agentic workflows. The API is fully OpenAI-compatible,
# supporting streaming, tool calling, and structured chat completions via the /v1/chat/completions endpoint.
# Currently supports a single model: `mercury-coder-small`.
#
# Docs: https://platform.inceptionlabs.ai/docs

export def provider [] {
  {
    models: {|key: string|
      [
        {
          id: "mercury-coder-small"
          name: "Mercury Coder Small"
          description: "Optimized for code generation with diffusion-based LLMs"
        }
      ]
    }

    call: {|key: string model: string tools?: list|
      let messages = $in
      let data = {
        model: $model
        messages: $messages
        stream: true
        tools: ($tools | default [])
      }

      let headers = {
        "Authorization": $"Bearer ($key)"
        "Content-Type": "application/json"
      }

      (
        http post
        --content-type application/json
        -H $headers
        https://api.inceptionlabs.ai/v1/chat/completions
        $data
        | lines
        | each {|line| $line | split row -n 2 "data: " | get 1? }
        | take until { $in == "[DONE]" }
        | each {|x| $x | from json }
      )
    }

    response_stream_aggregate: {||
      collect {|events|
        mut response = {
          role: "assistant"
          content: ""
        }
        for event in $events {
          if ($event.choices? | is-not-empty) {
            let delta = $event.choices.0.delta
            if ($delta.content?) {
              $response.content += $delta.content
            }
          }
        }
        $response
      }
    }

    response_stream_streamer: {|event|
      if ($event.choices? | is-not-empty) {
        let delta = $event.choices.0.delta
        if ($delta.content?) {
          return {content: $delta.content}
        }
      }
    }

    response_to_mcp_toolscall: {||
      let tool_use = $in | where type == "tool_use"
      if ($tool_use | is-empty) { return }

      $tool_use | first | {
        "jsonrpc": "2.0"
        "id": $in.id
        "method": "tools/call"
        "params": {
          "name": $in.name
          "arguments": ($in.input | default {})
        }
      }
    }

    mcp_toolscall_response_to_provider: {||
      let res = $in
      [
        {
          "type": "tool_result"
          "tool_use_id": $res.id
          "content": $res.result.content
        }
      ]
    }
  }
}
