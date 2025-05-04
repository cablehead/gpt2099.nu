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

  let continues = if $respond { $continues | append (.head gpt.response).id } else { $continues }

  let meta = (
    {}
    | if $continues != null { insert continues $continues } else { }
    | if $servers != null { insert servers $servers } else { }
    | if $json { insert mime_type "application/json" } else { }
  )
  let req = $content | .append gpt.call --meta $meta

  let frame = .cat --last-id $req.id -f | stream-response $p $req.id
  process-response $p $servers $frame
}

export def process-response [p: record servers frame: record] {
  $frame | .cas $in.hash | from json | do $p.response_to_mcp_toolscall | if ($in | is-not-empty) {
    if (["yes" "no"] | input list "Execute?") != "yes" { return {} }
    let res = $in | mcp call kagi
    $res | do $p.mcp_toolscall_response_to_provider | to json -r | main -c $frame.id --json --servers $servers
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
  null
}

export def init [
  --refresh (-r) # Skip configuration if set
] {
  const base = (path self) | path dirname
  cat ($base | path join "providers/anthropic.nu") | .append gpt.provider.anthropic
  cat ($base | path join "providers/gemini.nu") | .append gpt.provider.gemini
  cat ($base | path join "providers/command.nu") | .append gpt.define
  if not $refresh {
    configure
  }
  null
}

# Streams and displays provider responses in real-time
# Expects provider's response_stream_streamer to return records conforming to normalized schema:
# 1. Content Block Type Indicator: {type: string, name?: string}
# 2. Content Addition: {content: string}
#
# The function processes these events and displays them to the user:
# - Type indicators start a new line and display the content type
# - Tool use blocks show the tool name in parentheses
# - Content additions are displayed without additional formatting
export def stream-response [provider: record call_id: string] {
  generate {|frame _continue = true|
    if $frame.meta?.frame_id? != $call_id { return {next: true} }
    # Get the provider's streamer or use default if not defined
    let streamer = $provider.response_stream_streamer? | default {|chunk|  {content: ($chunk | to json)}}
    match $frame {
      {topic: "gpt.recv"} => {
        .cas $frame.hash | from json | each {|chunk|
          # Transform provider-specific event to normalized format
          let event = do $streamer $chunk
          if $event == null { return {next: true} } # Skip ignored events

          # Handle type indicator events (new content blocks)
          if "type" in $event {
            print -n "\n"
            print -n $event.type

            if "name" in $event {
              print -n $"\(($event.name)\)"
            }
            print ":"
          }
          # Handle content addition events
          if "content" in $event {
            print -n $event.content
          }

          {next: true}
        }
      }

      {topic: "gpt.response"} => {
        print "\n"
        return {out: $frame}
      }

      _ => {next: true}
    }
  } | first
}
