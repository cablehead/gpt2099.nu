def thecall [] {
  {|model: string, tools?: list|
    let data = {
      model: $model
      max_tokens: 8192
      stream: true
      # TODO: anthropic only supports a single system message as a top level attribute
      messages: ($in | update role {|x| if $x.role == "system" { "user" } else { $x.role } })
      tools: ($tools | default [])
    }

    return (
      http post
      --content-type application/json
      -H {
        "x-api-key": $env.ANTHROPIC_API_KEY
        "anthropic-version": "2023-06-01"
        "anthropic-beta": "computer-use-2024-10-22"
      }
      https://api.anthropic.com/v1/messages
      $data
    )

    try {

      return (
        http post
        --content-type application/json
        -H {
          "x-api-key": $env.ANTHROPIC_API_KEY
          "anthropic-version": "2023-06-01"
          "anthropic-beta": "computer-use-2024-10-22"
        }
        https://api.anthropic.com/v1/messages
        $data
      )
    } catch {|err|
      print ($err.rendered)
      print (
        http post
        --content-type application/json
        -f -e
        -H {
          "x-api-key": $env.ANTHROPIC_API_KEY
          "anthropic-version": "2023-06-01"
          "anthropic-beta": "computer-use-2024-10-22"
        }
        https://api.anthropic.com/v1/messages
        $data | table -e
      )
      error make {msg: "TBD"}
    }

    (
      http post
      --content-type application/json
      -H {
        "x-api-key": $env.ANTHROPIC_API_KEY
        "anthropic-version": "2023-06-01"
      }
      https://api.anthropic.com/v1/messages
      $data
      | lines
      | each {|line| $line | split row -n 2 "data: " | get 1? }
      | each {|x| $x | from json }
      | where type == "content_block_delta"
      | each {|x| $x | get delta.text }
    )
  }
}

def conditional-pipe [
  condition: bool
  action: closure
] {
  if $condition { do $action } else { $in }
}

def id-to-messages [id: string] {
  let frame = .get $id
  let meta = $frame | get meta? | default {}
  let role = $meta | default "user" role | get role
  let content = .cas $frame.hash | conditional-pipe (($meta | get mime_type?) == "application/json") { from json }
  let message = {
    id: $id
    role: $role
    content: $content
  }

  let next_id = $frame | get meta?.continues?

  match ($next_id | describe -d | get type) {
    "string" => (id-to-messages $next_id | append $message)
    "list" => ($next_id | each {|id| id-to-messages $id } | flatten | append $message)
    "nothing" => [$message]
    _ => ( error make {msg: "TBD"})
  }
}

const computer_tools = [
  {type: "text_editor_20241022" name: "str_replace_editor"}
  {type: "bash_20241022" name: "bash"}
]

def .call [id: string] {
  (
    id-to-messages $id
    | reject id
    | do (thecall) "claude-3-5-sonnet-20241022" $computer_tools
    | lines
    | each {|line| $line | split row -n 2 "data: " | get 1? }
    | each {|x| $x | from json }
  )
}

{
  process: {|frame|
    .call $frame.meta.id
  }
}
