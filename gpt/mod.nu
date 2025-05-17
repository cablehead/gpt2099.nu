# gpt module
#
# use gpt
#
# This module provides commands for interacting with Language Model (LLM) APIs.
# It manages conversation threads, supports different providers, and handles tool use.
#
# A key concept is the 'headish', which is a reference (specifically, the ID) to a
# particular turn within a conversation thread. This allows commands like `gpt main`
# to continue a conversation from a specific point by specifying the `headish`
# using the `--continues` flag. The conversation context is built by tracing
# backward from the specified 'headish' through the `continues` links.

export use ./context.nu
export use ./mcp.nu
export use ./providers

export def main [
  --continues (-c): any # Previous `headish` to continue a conversation, can be a list of `headish`
  --respond (-r) # Continue from the last turn
  --servers: list<string> # MCP servers to use
  --search # enable LLM-side search (currently anthropic + gemini only)
  --bookmark (-b): string # bookmark this turn: this will become the thread's head name
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
  let continues = $continues | append [] | each { context headish-to-id $in }
  let continues = $continues | conditional-pipe $respond { append (.head gpt.turn).id }

  let head = $bookmark | default (
    if ($continues | is-not-empty) { (.get ($continues | last)).meta?.head? }
  )

  let meta = (
    {
      role: user
      options : (
        {}
        | conditional-pipe ($servers | is-not-empty) { insert servers $servers }
        | conditional-pipe $search { insert search $search }
      )
    }
    | conditional-pipe ($head | is-not-empty) { insert head $head }
    | if $continues != null { insert continues $continues } else { }
    | if $json { insert content_type "application/json" } else { }
  )

  let turn = $content | .append gpt.turn --meta $meta

  process-turn $turn
}

export def process-turn-response [turn: record] {
  let content = .cas $turn.hash | from json
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

  let meta = {
    role: "user"
    content_type: "application/json"
    continues: $turn.id
  } | conditional-pipe ($turn.meta?.head? | is-not-empty) { insert head $turn.meta?.head? }

  let turn = $tool_result | to json | .append gpt.turn --meta $meta
  process-turn $turn
}

export def process-turn [turn: record] {
  let role = $turn.meta | default "user" role | get role
  if $role == "assistant" {
    return (process-turn-response $turn)
  }

  let ctx = context pull $turn.id

  let config = .head gpt.config | .cas $in.hash | from json

  let res = generate-response $config $ctx $turn.id

  let content = $res | get message.content
  let meta = (
    $res
    | reject message.content
    | insert continues $turn.id
    | insert role "assistant"
    | insert content_type "application/json"
    | conditional-pipe ($turn.meta?.head? | is-not-empty) { insert head $turn.meta?.head? }
  )

  # save the assistance response
  let turn = $content | to json | .append gpt.turn --meta $meta
  $content | process-turn-response $turn
}

export def generate-response [config: record ctx: record id: string] {
  let servers = $ctx.options?.servers?
  let $tools = $servers | if ($in | is-not-empty) {
    each {|server|
      .head $"mcp.($server).tools" | .cas $in.hash | from json | update name {
        # prepend server name to tool name so we can determine which server to use
        $"($server)___($in)"
      }
    } | flatten
  }

  let p = (providers) | get $config.name
  let res = (
    do $p.prepare-request $ctx $tools
    | do $p.call $config.key $config.model
    | tee { each { to json | .append gpt.recv --meta {turn_id: $id} } }
    | tee { preview-stream $p.response_stream_streamer }
    | do $p.response_stream_aggregate
  )
  $res
}

export def preview-stream [streamer] {
  generate {|chunk block = ""|
    # Transform provider-specific event to normalized format
    let event = do $streamer $chunk

    if $event == null { return {next: $block} } # Skip ignored events

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

export def init [
  --refresh (-r) # Skip configuration if set
] {
  const base = (path self) | path dirname
  # cat ($base | path join "providers/anthropic/mod.nu") | .append gpt.provider.anthropic
  # cat ($base | path join "providers/gemini/mod.nu") | .append gpt.provider.gemini
  # cat ($base | path join "xs/command.nu") | .append gpt.define
  if not $refresh {
  }
  ignore
}

def conditional-pipe [
  condition: bool
  action: closure
] {
  if $condition { do $action } else { $in }
}
