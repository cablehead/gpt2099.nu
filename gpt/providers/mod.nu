use ./anthropic.nu

export def main [] {
  {
    anthropic : (anthropic provider)
  }
}

export def call [
  provider: record
  key: string
  model: string
  options: record
] {
  let thread = $in
  let streamer = $options | get -i streamer
  let tools = $options | get -i tools
  $thread | do $provider.call $key $model $tools | if $streamer != null {
    tee { do $provider.response_stream_streamer | do $streamer }
  } else { } | do $provider.response_stream_aggregate
}
