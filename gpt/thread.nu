def frame-to-message [frame: record] {
  let meta = $frame | get meta? | default {}
  let role = $meta | default "user" role | get role

  let content = if ($frame | get hash? | is-not-empty) { .cas $frame.hash }
  if ($content | is-empty) { return }

  let content = (
    if ($meta.type? == "document" and $meta.content_type? != null) {
      [
        {
          "type": "document"
          "cache_control": {"type": "ephemeral"}
          "source": {
            "type": "base64"
            "media_type": $meta.content_type
            "data": ($content | encode base64)
          }
        }
      ]
    } else if (($meta | get mime_type?) == "application/json") {
      $content | from json
    } else {
      [
        (
          {type: "text" text: $content}
          | if ($frame.meta?.cache? | default false) {
            insert cache_control {type: "ephemeral"}
          } else { }
        )
      ]
    }
  )

  {
    id: $frame.id
    role: $role
    content: $content
  }
}

def id-to-messages [ids] {
  mut messages = []
  mut stack = [] | append $ids

  while not ($stack | is-empty) {
    let current_id = $stack | first
    let frame = .get $current_id
    $messages = ($messages | prepend (frame-to-message $frame))

    $stack = ($stack | skip 1)

    let next_id = $frame | get meta?.continues?
    match ($next_id | describe -d | get type) {
      "string" => { $stack = ($stack | append $next_id) }
      "list" => { $stack = ($stack | append $next_id) }
      "nothing" => { }
      _ => ( error make {msg: "TBD"})
    }
  }

  $messages
}

export def main [ids?] {
  let ids = if ($ids | is-empty) { (.head gpt.turn).id } else { $ids }
  id-to-messages $ids
}
