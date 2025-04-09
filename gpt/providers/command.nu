{
  modules: {
    anthropic: (.head gpt.provider.anthropic | .cas $in.hash)
  }

  run: {|frame|
    let config = .head gpt.config | .cas $in.hash | from json
    let p = anthropic provider

    [{role: "user" content: "hola"}] | do $p.call $config.key $config.model | tee {
      do $p.response_stream_aggregate | do {
        let res = $in

        $res | get message.content | to json -r | .append gpt.response --meta (
          $res | reject message.content | insert continues $frame.id
        )
      } | do $p.response_stream_streamer
    }
  }
}
