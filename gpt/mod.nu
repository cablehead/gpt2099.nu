export use ./context.nu
export use ./mcp.nu
export use ./providers

# Schema: gpt.turn.meta
# Each `gpt.turn` frame stores metadata under `meta`, which controls role, format, options, and flow.
#
# {
#   role: "user" | "assistant" | "system"       # Optional; defaults to "user"
#   content_type: string                        # MIME type of this turn's content (default: "text/plain")
#   continues: string | list<string>            # Parent turn(s) for context linking
#   options: {
#     servers: list<string>                     # Available MCP tool namespaces
#     search: bool                              # Enable LLM-side search
#     tool_mode: "auto" | "manual" | "disabled" # Tool execution strategy
#   }
#   cache: bool                                 # If true, marks content for ephemeral caching (not inherited)
# }

export def main [
  --continues (-c): any # Previous message IDs to continue a conversation
  --respond (-r) # Continue from the last response
  --servers: list<string> # MCP servers to use
  --search # enable LLM-side search (gemini only)
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

  let continues = if $respond { $continues | append (.head gpt.turn).id } else { $continues }

  let meta = (
    {
      role: user
      options : {
        servers: $servers
        search: $search
      }
    }
    | if $continues != null { insert continues $continues } else { }
    | if $json { insert content_type "application/json" } else { }
  )

  let turn = $content | .append gpt.turn --meta $meta

  process-turn $turn

  let config = .head gpt.config | .cas $in.hash | from json

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

export def process-turn [turn: record] {
  let role = $turn.meta | default "user" role | get role
  if $role == "assistant" {
    return "end-of-turn"
  }

  let ctx = context $turn.id

  let config = .head gpt.config | .cas $in.hash | from json

  let res = generate-response $config $ctx

  let content = $res | get message.content
  let meta = (
    $res
    | reject message.content
    | insert continues $turn.id
    | insert role "assistant"
    | insert content_type "application/json"
  )

  # save the assistance response
  let turn = $content | to json | .append gpt.turn --meta $meta
  process-turn $turn
}

export def generate-response [config: record ctx: record] {

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
    $messages
    | do $p.prepare-request {options: tools: $tools search: $search}
    | do $p.call $config.key $config.model
    | tee { each { to json | .append gpt.recv --meta {turn_id: $turn.id} } }
    | tee { preview-stream $p.response_stream_streamer }
    | do $p.response_stream_aggregate
  )
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

# Configure a different model for the current provider
export def configure-model [] {
  # Get current configuration
  let config = .head gpt.config | .cas $in.hash | from json
  print $"Current provider: ($config.name)"
  print $"Current model: ($config.model)"

  # Get provider module
  let p = (providers) | get $config.name

  # Fetch available models
  let models = do $p.models $config.key

  # Let user select a new model
  let model = $models | get id | input list --fuzzy "Select model"
  print $"Selected model: ($model)"

  # Save updated configuration
  {
    name: $config.name
    key: $config.key
    model: $model
  } | to json -r | .append gpt.config
  ignore
}

export def init [
  --refresh (-r) # Skip configuration if set
] {
  const base = (path self) | path dirname
  # cat ($base | path join "providers/anthropic/mod.nu") | .append gpt.provider.anthropic
  # cat ($base | path join "providers/gemini/mod.nu") | .append gpt.provider.gemini
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
