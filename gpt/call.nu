use ./providers

export def main [] {
  let thread = $in
  let config = .head gpt.provider | .cas $in.hash | from json
  let p = (providers) | get $config.name
  $thread | providers call $p $config.key $config.model
}
