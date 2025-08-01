# append to gpt.define
{
  modules: {
    "anthropic": (.head gpt.mod.provider.anthropic | .cas $in.hash)
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

    let provider_data = .head gpt.provider | .cas $in.hash | from json
    let key = $provider_data.key

    let p = anthropic provider
    let prepared = do $p.prepare-request $window $tools

    let res = $prepared | do $p.call $key "claude-3-5-haiku-20241022" | tee {
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
