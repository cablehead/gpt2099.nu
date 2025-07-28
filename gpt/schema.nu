# Schema generation layer - creates clean normalized turns and context windows
# This ensures consistent format between CLI commands and test fixtures

# Generate a normalized user turn from content and options
export def user-turn [
  content: any
  options?: record = {} # {json?: bool, cache?: bool, separator?: string}
] {
  let json = $options.json? | default false
  let cache = $options.cache? | default false
  let separator = $options.separator? | default "\n\n---\n\n"

  let processed_content = if ($content | describe) == "list<string>" {
    $content | str join $separator
  } else {
    $content
  }

  let content_blocks = if $json {
    $processed_content | from json
  } else {
    [
      {type: "text" text: $processed_content}
    ]
  }

  {
    role: "user"
    content: $content_blocks
  } | if $cache {
    insert cache $cache
  } else { $in }
}

# Helper to conditionally apply transformations
def conditional-pipe [
  condition: bool
  action: closure
] {
  if $condition { do $action } else { $in }
}
