export def ".mcp register" [name: string command: string] {
  $command + " | lines" | .append $"($name).spawn" --meta {duplex: true}
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

export def ".mcp call" [name: string] {
  let command = $in
  let frame = $command | to json -r | $in + "\n" | .append $"($name).send" --meta {id: $command.id}

  let res = (
    .cat -f --last-id $frame.id
    | where topic == $"($name).recv"
    | skip until {|x| let res = $x | from json; $res.id == $command.id }
    | first | .cas $in.hash | from json
  )

  $res
}

export def ".mcp tools call" [name: string provider: record] {
  do $provider.provider_to_toolscall_mcp
  | .mcp call $name
  | do $provider.mcp_toolscall_response_to_provider
}

export def providers [] {
  {
    anthropic : {
      mcp_toolslist_to_provider : {||
        rename -c {inputSchema: input_schema}
      }

      provider_to_toolscall_mcp : {||
        let tool_use = $in
        {"jsonrpc": "2.0" "id": $tool_use.id "method": "tools/call" "params": {"name": $tool_use.name "arguments": $tool_use.input}}
      }

      mcp_toolscall_response_to_provider : {||
        let res = $in
        {
          "type": "tool_result"
          "tool_use_id": $res.id
          "content": $res.result.content
        }
      }
    }
  }
}
