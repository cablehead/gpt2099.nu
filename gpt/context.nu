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
      "list" => { $stack = ($stack | append $next) }
      "nothing" => { }
      _ => ( error make {msg: "Invalid continues value"})
    }
  }

  $turns
}

# Raw per-turn view
export def list [ids?] {
  let ids = if ($ids | is-empty) { (.head gpt.turn).id } else { $ids }
  id-to-turns $ids
}

# Fully resolved context window
export def pull [ids?] {
  let turns = list $ids
  let options = $turns | get options? | compact --empty | if ($in | is-not-empty) { last } else { null }
  {
    messages: $turns
    options: $options
  }
}

# Generate XML context for a list of files in the current Git repository
#
# Takes file paths on stdin and, for each:
# - Tags it as `<file name="…">…</file>`
# - Retrieves content via the optional `get_content` closure (defaults to `cat`)
# Wraps all file entries in a `<context>` element with:
# - type="git-repo"
# - path = current working directory
# - origin = output of `git remote get-url origin`
export def prep-git-repo [
  # Optional closure to fetch file content. Defaults to `cat $in`
  get_content?: closure
] {
  let names = $in

  # Fallback to `cat` if no closure provided
  let get_content = $get_content | default { cat $in }

  $names | each {
    # For each file name in the list, emit a <file> element
    {
      tag: file
      attributes: {name: $in}
      content: [($in | do $get_content)]
    }
  }
  | {
    # Wrap all <file> elements in a <context> element
    tag: context
    attributes: {
      type: "git-repo" # Context type
      path: (pwd) # Repo path
      origin: (git remote get-url origin) # Origin URL
    }
    content: $in
  }
  # Serialize to XML without extra indentation
  | to xml --indent 0
}
