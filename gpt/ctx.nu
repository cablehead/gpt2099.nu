# Context window management
#
# See docs/reference/schemas.md for complete schema documentation.
# This module implements the thread record and context resolution logic.

use util.nu is-scru128

export def headish-to-id [headish: string] {
  if (is-scru128 $headish) {
    return $headish
  }

  .cat | where topic == "gpt.turn" and meta?.head? == $headish | if ($in | is-not-empty) {
    last | get id
  } else {
    error make {msg: $"Headish '($headish)' isn't an SCRU128 or valid bookmark"}
  }
}

# Convert a stored frame into a normalized “turn” with delta options and cache flag
def frame-to-turn [frame: record] {
  let meta = $frame | get meta? | default {}
  let role = $meta | default "user" role | get role
  let cache = $meta | get cache? | default false
  let options_delta = $meta | get options? | default {}

  let content_raw = if ($frame | get hash? | is-not-empty) { .cas $frame.hash }
  if ($content_raw | is-empty) { return }

  # Content is now stored as clean JSON (normalized format)
  let content = if ($meta | get type?) == "document" {
    # For documents, reconstruct the normalized format with base64 encoding
    [
      {
        type: "document"
        source: {
          type: "base64"
          media_type: ($meta | get content_type)
          data: ($content_raw | encode base64)
        }
      }
    ]
  } else if (($meta | get content_type?) == "application/json") {
    $content_raw | from json
  } else {
    # Legacy fallback for old text-based storage
    [
      {type: "text" text: $content_raw}
    ]
  }

  {
    role: $role
    content: $content
  } | if $cache {
    insert cache $cache
  } else { $in }
}

# Follow the continues chain to produce a list of turns in chronological order
def id-to-turns [ids] {
  mut turns = []
  mut stack = [] | append $ids

  while not ($stack | is-empty) {
    let current_id = $stack | first
    let frame = .get $current_id
    $turns = ($turns | prepend (frame-to-turn $frame))
    $stack = ($stack | skip 1)

    let next = $frame | get meta?.continues?
    match ($next | describe -d | get type) {
      "string" => { $stack = ($stack | append $next) }
      "list" => { $stack = ($stack | append $next) }
      "nothing" => { }
      _ => ( error make {msg: "Invalid continues value"})
    }
  }

  $turns
}

# Follow the continues chain to collect frames (for options extraction)
def id-to-frames [ids] {
  mut frames = []
  mut stack = [] | append $ids

  while not ($stack | is-empty) {
    let current_id = $stack | first
    let frame = .get $current_id
    $frames = ($frames | prepend $frame)
    $stack = ($stack | skip 1)

    let next = $frame | get meta?.continues?
    match ($next | describe -d | get type) {
      "string" => { $stack = ($stack | append $next) }
      "list" => { $stack = ($stack | append $next) }
      "nothing" => { }
      _ => ( error make {msg: "Invalid continues value"})
    }
  }

  $frames
}

# Raw per-turn view
export def list [headish?] {
  let ids = $headish | default [] | each { headish-to-id $in }
  let ids = if ($ids | is-empty) { (.head gpt.turn).id } else { $ids }
  id-to-turns $ids
}

# Fully resolved context window
export def resolve [headish?] {
  let ids = $headish | default [] | each { headish-to-id $in }
  let ids = if ($ids | is-empty) { (.head gpt.turn).id } else { $ids }

  let turns = id-to-turns $ids
  let frames = id-to-frames $ids

  let options = $frames | each { $in | get meta? | default {} | get options? | default {} } | if ($in | is-not-empty) {
    reduce {|it acc| $acc | merge deep $it }
  } else { null }

  {
    messages: $turns
    options: $options
  }
}
