# Generate XML context for a list of files in the current Git repository
export def gr [
  ...names: string # list of file names to include
  --with-content: closure # closure to fetch file content, default detects binary files
  --instructions: string
]: any -> string {
  let input = $in
  let names = $names | default [] | append $input

  # Fallback to content reader that handles binary files
  let with_content = if ($with_content == null) {
    { 
      # Read file as raw bytes, convert to string, check for null bytes to detect binary files
      try {
        let content = (open --raw $in | into string)
        if ($content | str contains "\u{0}") {
          "[binary file]"
        } else {
          $content
        }
      } catch {
        "[binary file]"
      }
    }
  } else {
    $with_content
  }

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
