export use ./thread.nu
export use ./mcp.nu
export use ./providers

export def main [
  --continues (-c): any # Previous message IDs to continue a conversation
  --respond (-r) # Continue from the last response
  --servers: list<string> # MCP servers to use
  --json (-j) # Treat input as JSON formatted content
  --separator (-s): string = "\n\n---\n\n" # Separator used when joining lists of strings
] {
  let content = if $in == null {
    input "Enter prompt: "
  } else if ($in | describe) == "list<string>" {
    $in | str join $separator
  } else {
    $in
  }

  let config = .head gpt.config | .cas $in.hash | from json
  let p = (providers) | get $config.name

  let continues = if $respond { $continues | append (.head gpt.turn).id } else { $continues }

  let meta = (
    {}
    | if $continues != null { insert continues $continues } else { }
    | if $servers != null { insert servers $servers } else { }
    | if $json { insert mime_type "application/json" } else { }
  )

  let turn = $content | .append gpt.turn --meta $meta

  let messages = thread $turn.id | reject id

  let $tools = $servers | if ($in | is-not-empty) {
    each {|server|
      .head $"mcp.($server).tools" | .cas $in.hash | from json | update name {
        # prepend server name to tool name so we can determine which server to use
        $"($server)___($in)"
      }
    } | flatten
  }

  let res = (
    $messages
    | do $p.prepare-request $tools
    | do $p.call $config.key $config.model
    | tee { preview-stream $p.response_stream_streamer }
    | do $p.response_stream_aggregate
  )

  let content = $res | get message.content
  let meta = $res | reject message.content | insert continues $turn.id

  # save the assistance response
  let turn = $content | to json | .append gpt.turn --meta $meta

  let tool_use = $content | where type == "tool_use"
  if ($tool_use | is-empty) { return }
  let tool_use = $tool_use | first

  print ($tool_use | table -e)
  if (["yes" "no"] | input list "Execute?") != "yes" { return {} }

  # parse out the server name from the tool name
  let namespace = ($tool_use.name | split row "___")

  let mcp_toolscall = $tool_use | {
    "jsonrpc": "2.0"
    "id": $turn.id
    "method": "tools/call"
    "params": {"name": $namespace.1 "arguments": ($in.input | default {})}
  }

  let res = $mcp_toolscall | mcp call $namespace.0

  let tool_result = [
    (
      {
        type: "tool_result"
        name: $tool_use.name
        content: $res.result.content
      } | conditional-pipe ($tool_use.id? != null) {
        insert "tool_use_id" $tool_use.id
      }
    )
  ]

  print ($tool_result | table -e)
  # continue the interaction
  $tool_result | to json | main -c $turn.id --json --servers $servers
}

export def preview-stream [streamer] {
  generate {|chunk block = ""|
    # Transform provider-specific event to normalized format
    let event = do $streamer $chunk
    if $event == null { return {next: true} } # Skip ignored events

    let next_block = $event.type? | default $block

    # Handle type indicator events (new content blocks)
    if $next_block != $block {
      if $block != "" {
        print "\n"
      }
      if $next_block != "text" {
        print -n $next_block
        if "name" in $event {
          print -n $"\(($event.name)\)"
        }
        print ":"
      }
    }

    # Handle content addition events
    if "content" in $event {
      print -n $event.content
    }

    {next: $next_block} # Continue with the next block
  }
}

export def configure [] {
  let name = providers | columns | input list "Select provider"
  print $"Selected provider: ($name)"
  let p = providers | get $name

  let key = input -s "Enter API key: "

  let model = do $p.models $key | get id | input list --fuzzy "Select model"
  print $"Selected model: ($model)"

  {
    name: $name
    key: $key
    model: $model
  } | to json -r | .append gpt.config
  ignore
}

export def init [
  --refresh (-r) # Skip configuration if set
] {
  const base = (path self) | path dirname
  cat ($base | path join "providers/anthropic/mod.nu") | .append gpt.provider.anthropic
  cat ($base | path join "providers/gemini/mod.nu") | .append gpt.provider.gemini
  # cat ($base | path join "xs/command.nu") | .append gpt.define
  if not $refresh {
    configure
  }
  ignore
}

def conditional-pipe [
  condition: bool
  action: closure
] {
  if $condition { do $action } else { $in }
}
