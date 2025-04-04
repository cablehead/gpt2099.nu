export def ".mcp register" [name: string command: string] {
  $command + " | lines" | .append $"mcp.($name).spawn" --meta {duplex: true}
}

export def ".mcp tools list" [name] {
  let command = {
    "jsonrpc": "2.0"
    "id": (scru128)
    "method": "tools/list"
    "params": {}
  }

  let res = $command | .mcp call $name

  if "error" in $res {
    return $res.error
  }

  $res.result | get tools
}

export def ".mcp call" [name: string] {
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
