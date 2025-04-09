export use ./thread.nu
export use ./call.nu
export use ./mcp.nu
export use ./providers

export def main [] {
  let req = .append gpt.call
  .cat --last-id $req.id -f
  | generate {|frame, cont = true|
    print $frame
    if $frame.topic == "gpt.response" { return {out: $frame} }
    {next: true}
  }
}

export def init [] {
  const base = (path self) | path dirname
  cat ($base | path join "providers/anthropic.nu") | .append gpt.provider.anthropic
  cat ($base | path join "providers/command.nu") | .append gpt
  # todo: gpt.config
  null
}
