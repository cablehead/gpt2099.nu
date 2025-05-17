# Generate XML context for a list of files in the current Git repository
export def git-repo [
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
