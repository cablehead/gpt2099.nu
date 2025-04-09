export use ./thread.nu
export use ./mcp.nu
export use ./providers

export def main [
  --continues (-c): any # Previous message IDs to continue a conversation
  --respond (-r) # Continue from the last response
  --servers: list<string> # MCP servers to use
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
  )
  let req = $content | .append gpt.call --meta $meta

  .cat --last-id $req.id -f | stream-response $p $req.id
}

export def init [] {
  const base = (path self) | path dirname
  cat ($base | path join "providers/anthropic.nu") | .append gpt.provider.anthropic
  cat ($base | path join "providers/command.nu") | .append gpt.define
  # todo: gpt.config
  null
}

def stream-response [provider: record call_id: string] {
  generate {|frame cont = false|
    if $frame.meta?.frame_id? != $call_id { return {next: true} }
    match $frame {
      {topic: "gpt.recv"} => {
        .cas $frame.hash | from json | each {|chunk|
          let event = do $provider.response_stream_streamer $chunk
          if $event == null { return {next: true} }

          if "type" in $event {
            print -n "\n"

            print -n $event.type

            if "name" in $event {
              print -n $"\(($event.name)\)"
            }
            print ":"
          }
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
