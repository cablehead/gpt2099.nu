{
  modules: {
    anthropic: (.head gpt.provider.anthropic | .cas $in.hash)
    gemini: (.head gpt.provider.gemini | .cas $in.hash)
  }

  run: {|frame|
    let config = .head gpt.config | .cas $in.hash | from json
    let providers = {
      anthropic: (anthropic provider)
      gemini: (gemini provider)
    }
    let p = $providers | get $config.name
    let req = .cas $frame.hash | from json
    $req | do $p.call $config.key $config.model
  }
}
