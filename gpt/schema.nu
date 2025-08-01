# Schema generation layer - creates clean normalized turns and context windows
# This ensures consistent format between CLI commands and test fixtures

# Create and store a complete turn with metadata
export def add-turn [
  meta?: record = {} # {continues?, respond?, servers?, search?, bookmark?, provider_ptr?, json?, cache?}
] {
  let content = $in
  let json = $meta.json? | default false
  let cache = $meta.cache? | default false

  # Generate normalized content blocks
  let content_blocks = if $json {
    $content | from json
  } else if ($content | describe) == "list<string>" {
    $content | each { {type: "text" text: $in} }
  } else {
    [
      {type: "text" text: $content}
    ]
  }

  # Create normalized turn
  let normalized_turn = {
    role: "user"
    content: $content_blocks
  } | if $cache {
    insert cache $cache
  } else { $in }

  # Build continues list
  let continues = $meta.continues? | default [] | append [] | each { ctx headish-to-id $in }
  let continues = $continues | conditional-pipe ($meta.respond? | default false) { append (.head gpt.turn).id }

  # Determine head
  let head = $meta.bookmark? | default (
    if ($continues | is-not-empty) { (.get ($continues | last)).meta?.head? }
  )

  # Build metadata
  let full_meta = (
    {
      role: $normalized_turn.role
      content_type: "application/json"
      # options should be renamed to "inherited"
      options : (
        {}
        | conditional-pipe ($meta.provider_ptr? | is-not-empty) { insert provider_ptr $meta.provider_ptr? }
        | conditional-pipe ($meta.servers? | is-not-empty) { insert servers $meta.servers? }
        | conditional-pipe ($meta.search? | default false) { insert search $meta.search? }
      )
    }
    | conditional-pipe ($head | is-not-empty) { insert head $head }
    | conditional-pipe ($normalized_turn.cache? == true) { insert cache true }
    | if $continues != null { insert continues $continues } else { }
  )

  # Store the clean normalized content
  $normalized_turn.content | to json | .append gpt.turn --meta $full_meta
}

# Helper to conditionally apply transformations
def conditional-pipe [
  condition: bool
  action: closure
] {
  if $condition { do $action } else { $in }
}
