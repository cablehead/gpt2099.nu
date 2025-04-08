use ./providers

export def main [ --servers: list<string> --streamer: closure] {
  let thread = $in
  let config = .head gpt.provider | .cas $in.hash | from json
  let p = (providers) | get $config.name

  let $tools = $servers | if ($in | is-not-empty) {
    each { .head $"mcp.($in).tools" | .cas $in.hash | from json } | flatten
  }

  $thread | providers call $p $config.key $config.model {
    tools: $tools
    streamer: $streamer
  }
}

export def response [] {
  let res = $in
  let config = .head gpt.provider | .cas $in.hash | from json
  let p = (providers) | get $config.name
  $res | do $p.response_to_mcp_toolscall
}

export def response-streamer [] {
  generate {|event state = 0|
    mut state = $state

    if "type" in $event {
      if $state > 0 {
        print "\n"
      }

      $state = $state + 1

      print -n $event.type

      if "name" in $event {
        print -n $"\(($event.name)\)"
      }
      print ":"
    }

    if "content" in $event {
      print -n $event.content
    }

    return {next: $state}
  }
}
