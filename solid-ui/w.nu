# .cat --last-id 03d9k9amhjib8kkq1z2r8q7bj |

.cat -f | where topic == "llm.recv" | each {
  .cas | from json | match $in.type {
    "content_block_start" => $"**($in.content_block.type)**: "
    "content_block_delta" => {
      match $in.delta.type {
        "text_delta" => $in.delta.text
        "input_json_delta" => $in.delta.partial_json
        _ => { error make {msg: $"TBD: ($in)"} }
      }
    }
    "content_block_stop" => ("\n\n")
  }
} | str join | each { print -n $in }
