export def ".mcp register" [name command] {
  $command | .append $"($name).spawn" --meta {duplex: true}
}

export def ".mcp tools list" [name] {
  let command = {
    "jsonrpc": "2.0"
    "id": (scru128)
    "method": "tools/list"
    "params": {}
  }

  let frame = $command | to json -r | $in + "\n" | .append $"($name).send" --meta {id: $command.id}

  let res = (
    .cat -f --last-id $frame.id
    | where topic == $"($name).recv"
    | skip until {|x| let res = $x | from json; $res.id == $command.id }
    | first | .cas $in.hash | from json
  )

  if "error" in $res {
    return $res.error
  }

  $res.result | get tools
}
