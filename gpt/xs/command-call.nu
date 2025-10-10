# append to gpt.define
{
  modules: {
    "anthropic": (.head gpt.mod.provider.anthropic | .cas $in.hash)
    "gemini": (.head gpt.mod.provider.gemini | .cas $in.hash)
    "openai": (.head gpt.mod.provider.openai | .cas $in.hash)
    "ctx": (.head gpt.mod.ctx | .cas $in.hash)
  }

  run: {|frame|
    let continues = $frame.meta?.continues?
    if $continues == null {
      error make {
        msg: "continues is required"
        label: {
          text: "the options right here"
          span: (metadata $frame).span
        }
      }
    }

    let window = (ctx resolve $continues)

    let provider_ptr = $window.options.provider_ptr?
    if $provider_ptr == null {
      error make {
        msg: "provider_ptr is required"
        label: {
          text: "the options right here"
          span: (metadata $window).span
        }
      }
    }

    let servers = $window.options?.servers?
    let $tools = $servers | if ($in | is-not-empty) {
      each {|server|
        .head $"mcp.($server).tools" | .cas $in.hash | from json | update name {
          # prepend server name to tool name so we can determine which server to use
          $"($server)___($in)"
        }
      } | flatten
    } else { [] }

    let ptrs = .head gpt.provider.ptrs | default {} | get meta? | default {}
    let ptr = $ptrs | get $provider_ptr
    let ptr = $ptr | insert key (
      .cat -T "gpt.provider" | each { .cas $in.hash | from json } | where name == $ptr.provider | last | get key
    )

    # Get the provider module based on the resolved provider name
    let p = match $ptr.provider {
      "anthropic" => (anthropic provider)
      "gemini" => (gemini provider)
      "openai" => (openai provider)
      _ => {
        error make {msg: $"Unsupported provider: ($ptr.provider)"}
      }
    }

    let prepared = do $p.prepare-request $window $tools

    let res = $prepared | do $p.call $ptr.key $ptr.model | tee {
      each {|chunk|
        let event = do $p.response_stream_streamer $chunk
        if $event == null { return }
        $event | to json | .append gpt.recv
      }
    } | do $p.response_stream_aggregate

    let content = $res | get message.content
    let meta = (
      $res
      | reject message.content
      | insert continues $continues
      | insert role "assistant"
      | insert content_type "application/json"
      # TODO: revive bookmarks
      # | conditional-pipe ($res.meta?.head? | is-not-empty) { insert head $res.meta?.head? }
    )
    let turn = $content | to json | .append gpt.turn --meta $meta
  }
}
