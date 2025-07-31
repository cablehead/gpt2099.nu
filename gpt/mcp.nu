export def "register" [name: string command: string] {
  $"{
    run: {|| ($command) | lines }
    duplex: true
  }" | .append $"mcp.($name).spawn"
}

# https://modelcontextprotocol.io/specification/2025-06-18/basic/lifecycle
export def "initialize" [name] {
  let command = {
    jsonrpc: "2.0"
    "id": (random uuid)
    method: initialize
    params: {
      protocolVersion: "2025-06-18"
      clientInfo: {
        name: "gpt2099"
        version: "0.5"
      }
      capabilities: {}
    }
  }
  let res = $command | call $name
  {"jsonrpc": "2.0" "method": "notifications/initialized"} | to json -r | $in + "\n" | .append $"mcp.($name).send"
  $res
}

export def "ping" [name: string] {
  let command = {
    jsonrpc: "2.0"
    id: (random uuid)
    method: ping
  }
  let res = $command | call $name
  $res
}

export def "tool call" [name: string method: string arguments: record] {
  let command = {
    jsonrpc: "2.0"
    id: (random uuid)
    method: tools/call
    params: {
      name: $method
      arguments: $arguments
    }
  }
  let res = $command | call $name
  $res
}

export def "tool list" [name] {
  let command = {
    "jsonrpc": "2.0"
    "id": (random uuid)
    "method": "tools/list"
    "params": {}
  }

  let res = $command | call $name

  if "error" in $res {
    return $res.error
  }

  $res.result | get tools
}

export def "call" [name: string] {
  let command = $in
  let frame = $command | to json -r | $in + "\n" | .append $"mcp.($name).send" --meta {id: $command.id}
  let res = (
    .cat -f --last-id $frame.id
    | where topic == $"mcp.($name).recv"
    | each { .cas $in.hash | from json }
    | where { $in.id == $command.id }
    | first
  )
  $res
}

export def "response-to-tool-result" [tool_use: record] {
  let mcp_response = $in
  if "error" in $mcp_response {
    {
      type: "tool_result"
      name: $tool_use.name
      content: [{type: "text" text: $"MCP Error \(($mcp_response.error.code)\): ($mcp_response.error.message)"}]
      is_error: true
    }
  } else {
    {
      type: "tool_result"
      name: $tool_use.name
      content: $mcp_response.result.content
    }
  } | conditional-pipe ($tool_use.id? != null) { insert "tool_use_id" $tool_use.id }
}

export def "list" [] {
  .cat
  | where { $in.topic | str starts-with "mcp." }
  | reduce --fold [] {|row acc|
    let t = $row.topic
    let name = ($t | split row "." | get 1)

    if ($t | str ends-with ".spawn") {
      # add if not already present
      if $name in $acc { return $acc }
      return ($acc | append $name)
    }

    if not (($t | str ends-with ".spawn.error") or ($t | str ends-with ".terminate")) {
      return $acc
    }

    # remove on error or termination
    $acc | where $it != $name
  }
}

def conditional-pipe [
  condition: bool
  action: closure
] {
  if $condition { do $action } else { $in }
}
