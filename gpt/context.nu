# gpt/context.nu
# Module: Context and Thread Handling
#
# Schemas:
#
# Thread (per-turn) record:
# {
#   id: string                            # Unique turn ID
#   role: "user" | "assistant" | "system"  # Speaker role, default "user"
#   content: list<record>                # Blocks: e.g., {type: "text"|"document", ...}
#   options: record                      # Delta options: {servers?, search?, tool_mode?}
#   cache: bool                          # Ephemeral cache flag for this turn
# }
#
# Context (full) record returned by main:
# {
#   messages: list<record>               # Chronological list of thread records
#   options: record                      # Merged options across all turns
# }

# Convert a stored frame into a normalized “turn” with delta options and cache flag
def frame-to-turn [frame: record] {
  let meta = $frame | get meta? | default {}
  let role = $meta | default "user" role | get role
  let cache = $meta | get cache? | default false
  let options_delta = $meta | get options? | default {}

  let content_raw = if ($frame | get hash? | is-not-empty) { .cas $frame.hash }
  if ($content_raw | is-empty) { return }

  let content = (
    if ($meta.type? == "document" and $meta.content_type? != null) {
      [
        {
          type: "document"
          cache_control: {type: "ephemeral"}
          source: {
            type: "base64"
            media_type: $meta.content_type
            data: ($content_raw | encode base64)
          }
        }
      ]
    } else if (($meta | get content_type?) == "application/json") {
      $content_raw | from json
    } else {
      [
        {type: "text" text: $content_raw}
      ]
    }
  )

  {
    id: $frame.id
    role: $role
    content: $content
    options: $options_delta
    cache: $cache
  }
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
      "list"   => { $stack = ($stack | append $next) }
      "nothing" => { }
      _ => (error make {msg: "Invalid continues value"})
    }
  }

  $turns
}

# Raw per-turn view
export def thread [ids?] {
  let ids = if ($ids | is-empty) { (.head gpt.turn).id } else { $ids }
  id-to-turns $ids
}

# Fully resolved context for LLM: messages + merged options
export def main [ids?] {
  let turns = thread $ids

  # Merge options deltas in order
  let merged_options = (
    $turns
    | each {|t| t.options }
    | reduce {|a b| merge $a $b}
  )

  {
    messages: $turns
    options: $merged_options
  }
}
