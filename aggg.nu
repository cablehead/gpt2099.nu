def aggg [] {
  generate {|event, state ={ message: null current_block: null blocks: [] }|
    let data = ($event.data | from json)

    mut state = $state

    print ($data | ept)

    $state = match $event.name {
      "message_start" => {
        $state.message = $data.message
        return { next: $state }
      }

      "ping" => { return { next: $state }}

      "content_block_start" => {
        $state.current_block = $data.content_block | insert content []
        return { next: $state }
      }

      "content_block_delta" => {
        match $data.delta.type {
          "text_delta" => {
            $state.current_block.content = $state.current_block.content | append $data.delta.text
          }

          "input_json_delta" => {
            $state.current_block.content = $state.current_block.content | append $data.delta.partial_json
          }

          _ => { error make { msg: $"TBD: ($data)" }}
        }

        return { next: $state }
      }

      "content_block_stop" => {
        $state.blocks = $state.blocks | append ($state.current_block | update content {str join})
        $state.current_block = null
        return { next: $state }
      }

      "message_delta" => {
        # print ($data | ept)
        # TBD
        return { next: $state }
      }

      "message_stop" => {
        return { out: ($state | reject current_block) }
      }

      _ => { error make { msg: $"TBD: ($data)" }}
    }

    error make { msg: $"TBD: ($data)" }
  }
}
