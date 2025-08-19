# MCP Monitor for GPT2099

# Watches for mcp.*.running and mcp.*.recv events to manage async MCP initialization

# Initialize pending calls tracking
$env.mcp_pending = {}

{
  modules: {
    "mcp-rpc": (.head gpt.mod.mcp-rpc | .cas $in.hash)
  }
  run: {|frame|

     let topic_parts = $frame.topic | split row "."
    if ($topic_parts | length) < 2 { return }

    let server_name = $topic_parts.1

    match $topic_parts {
      # Handle server startup - begin initialization
      [mcp,$server,running] => {
        let init_request = mcp-rpc initialize
        let init_id = $init_request | from json | get id

        # Store pending initialization
        $env.mcp_pending = (
          $env.mcp_pending | insert $init_id {
            server: $server_name
            method: "initialize"
            next_action: "send_initialized"
          }
        )

        # Send initialization request
        $init_request | .append $"mcp.($server_name).send"
      }

      # Handle server responses
      [mcp,$server,recv] => {
        let content = .cas $frame.hash
        
        # Try to parse as JSON, skip if not valid JSON
        let response = try { $content | from json } catch { return }
        let response_id = try { $response.id } catch { return }

        if $response_id == null { return }

        let pending = $env.mcp_pending | get -i $response_id
        if $pending == null { return }

        match $pending.method {
          "initialize" => {
            if "error" in $response {
              $"MCP initialization failed for ($pending.server): ($response.error.message)" | .append $"mcp.($pending.server).error"
            } else {
              # Send initialized notification
              mcp-rpc initialized | .append $"mcp.($pending.server).send"

              # Queue tools/list request
              let tools_request = mcp-rpc tool-list
              let tools_id = $tools_request | from json | get id

              # Store pending tools request
              $env.mcp_pending = (
                $env.mcp_pending | insert $tools_id {
                  server: $pending.server
                  method: "tools/list"
                  next_action: "store_tools"
                }
              )

              # Send tools/list request
              $tools_request | .append $"mcp.($pending.server).send"
            }
          }

          "tools/list" => {
            if "error" in $response {
              $"MCP tools/list failed for ($pending.server): ($response.error.message)" | .append $"mcp.($pending.server).error"
            } else {
              # Store tools list
              $response.result.tools | to json | .append $"mcp.($pending.server).tools"

              # Emit initialized event
              null | .append $"mcp.($pending.server).initialized"
            }
          }
        }

        # Remove completed request from pending
        $env.mcp_pending = ($env.mcp_pending | reject $response_id)
      }

      _ => { }
    }
  }
}
