# MCP JSON-RPC utilities for gpt2099
# Provides consistent JSON-RPC construction with gpt2099 client info

# Internal JSON-RPC helpers
def jsonrpc-request [method: string params?: record] {
  {
    jsonrpc: "2.0"
    id: (random uuid)
    method: $method
    params: ($params | default {})
  } | to json -r | $in + "\n"
}

def jsonrpc-notification [method: string params?: record] {
  {
    jsonrpc: "2.0"
    method: $method
    params: ($params | default {})
  } | to json -r | $in + "\n"
}

# MCP-specific exports
export def initialize [params?: record] {
  let default_params = {
    protocolVersion: "2025-06-18"
    clientInfo: {
      name: "gpt2099"
      version: "0.6" # When updating this, also update the version command in mod.nu
    }
    capabilities: {}
  }
  let merged_params = $default_params | merge ($params | default {})
  jsonrpc-request "initialize" $merged_params
}

export def initialized [] {
  jsonrpc-notification "notifications/initialized"
}

export def "tool-list" [] {
  jsonrpc-request "tools/list" {}
}

export def "tool-call" [name: string arguments?: record] {
  jsonrpc-request "tools/call" {
    name: $name
    arguments: ($arguments | default {})
  }
}

export def ping [] {
  jsonrpc-request "ping"
}
