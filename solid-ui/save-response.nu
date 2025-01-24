def finish-content-block [content_block] {
  match $content_block.type {
    "text" => ($content_block | update text { str join })
    "tool_use" => ($content_block | update input {|x| $x.partial_json | str join | from json } | reject partial_json?)
    _ => { error make {msg: $"TBD: ($content_block)"} }
  }
}

def aggregate-response [] {
  (
    reduce
    --fold {
      role: "assistant"
      mime_type: "application/json"
    }
    {|it acc|
      match $it.topic {
        "llm.call" => ($acc | insert continues $it.meta.id)

        "llm.recv" => {
          let data = .cas $it.hash | from json
          match $data.type {
            "message_start" => ($acc | insert message $data.message)

            "content_block_start" => ($acc | upsert current_block $data.content_block)

            "content_block_delta" => {
              match $data.delta.type {
                "text_delta" => ($acc | update current_block.text { $in | append $data.delta.text })
                "input_json_delta" => ($acc | upsert current_block.partial_json { $in | default [] | append $data.delta.partial_json })
                _ => { error make {msg: $"TBD: ($data)"} }
              }
            }

            "content_block_stop" => ($acc | update message.content { $in | append (finish-content-block $acc.current_block) })

            "message_delta" => ($acc | merge deep {message: ($data.delta | insert usage $data.usage)})

            "message_stop" => ($acc | reject current_block)

            _ => $acc
          }
        }
        _ => $acc
      }
    }
  )
}

{
  process: {|frame|
    if $frame.topic != "llm.complete" { return }

    let meta = .cat | where {|it|
      ($it.id == $frame.meta.frame_id) or (
        $it.topic =~ "llm." and $it.meta?.frame_id? == $frame.meta.frame_id
      )
    } | aggregate-response

    $meta.message.content | to json -r | .append message --meta ($meta | reject message.content)
  }
}
