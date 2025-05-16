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
      "list" => { $stack = ($stack | append $next) }
      "nothing" => { }
      _ => ( error make {msg: "Invalid continues value"})
    }
  }

  $turns
}

# Raw per-turn view
export def list [headish?] {
  let ids = $headish | default [] | each { headish-to-id $in }
  let ids = if ($ids | is-empty) { (.head gpt.turn).id } else { $ids }
  id-to-turns $ids
}

# Fully resolved context window
export def pull [headish?] {
  let turns = list $headish
  let options = $turns | get options? | compact --empty | if ($in | is-not-empty) {
    reduce {|it, acc| $acc | merge deep $it }
  } else { null }
  {
    messages: $turns
    options: $options
  }
}

# Generate XML context for a list of files in the current Git repository
export def prep-git-repo [
  ...names: string # list of file names to include
  --with-content: closure # closure to fetch file content, default `{ cat $in }`
  --instructions: string
]: any -> string {
  let input = $in
  let names = $names | default [] | append $input

  # Fallback to `cat` if no closure provided
  let with_content = $with_content | default { cat $in }

  $names | each {
    # For each file name in the list, emit a <file> element
    {
      tag: file
      attributes: {name: $in}
      content: [($in | do $with_content)]
    }
  }
  | {
    # Wrap all <file> elements in a <context> element
    tag: context
    attributes: (
      {
        type: "git-repo"
        path: (pwd)
        origin: (git remote get-url origin)
        caveats: "XML special characters have been escaped. Be sure to unescape them before processing"
      } | if ($instructions | is-not-empty) {
        insert instructions $instructions
      } else { }
    )

    content: $in
  }
  # Serialize to XML
  | to xml --indent 0 --partial-escape
}
