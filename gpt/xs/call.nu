# GPT command definition for cross.stream
# This will be appended to gpt.define

{
  modules: {
    "anthropic": (.head gpt.mod.provider.anthropic | .cas $in.hash)
    "ctx": (.head gpt.mod.ctx | .cas $in.hash)
  }

  run: {|frame|
    let response = $frame

    let continues = $frame.meta?.continues?
    if ($continues | is-empty) { return }
    
    let thread = (ctx resolve $continues)
    
    let provider_data = .head gpt.provider | .cas $in.hash | from json
    let key = $provider_data.key
    
    let p = anthropic provider
    let prepared = do $p.prepare-request $thread []
    let response = $prepared | do $p.call $key "claude-3-5-haiku-20241022"
    
    $response
  }
}
