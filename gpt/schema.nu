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

# Generate a normalized document turn from file path and options
export def document-turn [
  path: string
  options?: record = {} # {name?: string, cache?: bool}
] {
  let name = $options.name?
  let cache = $options.cache? | default false

  # Validate file exists
  if not ($path | path exists) {
    error make {
      msg: $"File does not exist: ($path)"
      label: {
        text: "this path"
        span: (metadata $path).span
      }
    }
  }

  # Detect content type from file extension
  let content_type = match ($path | path parse | get extension | str downcase) {
    "pdf" => "application/pdf"
    "txt" => "text/plain"
    "md" => "text/markdown"
    "json" => "application/json"
    "csv" => "text/csv"
    "jpg"|"jpeg" => "image/jpeg"
    "png" => "image/png"
    "webp" => "image/webp"
    "gif" => "image/gif"
    "docx" => "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
    "xlsx" => "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
    _ => {
      let detected = (file --mime-type $path | split row ":" | get 1 | str trim)
      print $"Warning: Unknown extension, detected MIME type: ($detected)"
      $detected
    }
  }

  # Check file size (rough limit)
  let file_size = ($path | path expand | ls $in | get size | first)
  if $file_size > 100MB {
    error make {
      msg: $"File too large: ($file_size). Consider splitting or compressing."
    }
  }

  let document_name = $name | default ($path | path basename)
  let content = open $path --raw | encode base64

  let content_blocks = [
    {
      type: "document"
      source: {
        type: "base64"
        media_type: $content_type
        data: $content
      }
    }
  ]

  {
    role: "user"
    content: $content_blocks
    # Store metadata for internal use (not part of normalized schema)
    _metadata: {
      document_name: $document_name
      original_path: ($path | path expand)
      file_size: $file_size
      type: "document"
      content_type: $content_type
    }
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
