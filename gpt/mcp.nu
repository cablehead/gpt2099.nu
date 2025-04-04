export def "register" [name: string command: string] {
  $command + " | lines" | .append $"mcp.($name).spawn" --meta {duplex: true}
}

# https://spec.modelcontextprotocol.io/specification/2025-03-26/basic/lifecycle/#initialization
export def "initialize" [name] {
  let command = {
    jsonrpc: "2.0"
    "id": (scru128)
    method: initialize
    params: {
      protocolVersion: "2025-03-26"
      clientInfo: {
        name: "gpt.nu"
        version: "0.4"
      }
      capabilities: {}
    }
  }
  let res = $command | call $name
  {"jsonrpc": "2.0" "method": "notifications/initialized"} | to json -r | $in + "\n" | .append $"mcp.($name).send"
  $res
}

export def "tools call" [name: string method: string arguments: record] {
  let command = {
    jsonrpc: "2.0"
    id: (scru128)
    method: tools/call
    params: {
      name: $method
      arguments: $arguments
    }
  }
  let res = $command | call $name
  $res
}

export def "tools list" [name] {
  let command = {
    "jsonrpc": "2.0"
    "id": (scru128)
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
    | skip until {|x| let res = $x | from json; $res.id == $command.id }
    | first | .cas $in.hash | from json
  )
  $res
}
