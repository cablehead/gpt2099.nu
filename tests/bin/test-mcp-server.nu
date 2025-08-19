#!/usr/bin/env -S nu --stdin

# Simple MCP test server that implements basic JSON-RPC protocol
# Handles initialize, tools/list, and tools/call methods

def main [] {
  lines | each {|line|
    if ($line | is-empty) { return }

    let request = try {
      $line | from json
    } catch {
      return
    }

    let response = match $request.method {
      "initialize" => {
        {
          jsonrpc: "2.0"
          id: $request.id
          result: {
            protocolVersion: "2025-06-18"
            capabilities: {
              tools: {}
            }
            serverInfo: {
              name: "test-mcp-server"
              version: "1.0.0"
            }
          }
        }
      }

      "tools/list" => {
        {
          jsonrpc: "2.0"
          id: $request.id
          result: {
            tools: [
              {
                name: "greeting"
                description: "Generate a greeting message"
                inputSchema: {
                  type: "object"
                  properties: {
                    name: {
                      type: "string"
                      description: "Name of the person to greet"
                    }
                  }
                  required: ["name"]
                }
              }
            ]
          }
        }
      }

      "tools/call" => {
        let tool_name = $request.params.name
        let args = $request.params.arguments

        match $tool_name {
          "greeting" => {
            let name = $args.name? | default "World"
            {
              jsonrpc: "2.0"
              id: $request.id
              result: {
                content: [
                  {
                    type: "text"
                    text: $"Hello, ($name)!"
                  }
                ]
              }
            }
          }
          _ => {
            {
              jsonrpc: "2.0"
              id: $request.id
              error: {
                code: -32601
                message: $"Unknown tool: ($tool_name)"
              }
            }
          }
        }
      }

      _ => {
        {
          jsonrpc: "2.0"
          id: $request.id
          error: {
            code: -32601
            message: $"Method not found: ($request.method)"
          }
        }
      }
    }

    $response | to json -r | print $in
  } | ignore
}
