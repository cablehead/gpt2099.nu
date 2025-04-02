export-env {
  # Coerce the provider to a record if it's a string.
  $env.GPT_PROVIDER = match ($env.GPT_PROVIDER? | describe -d | get type) {
    "string" => ($env.GPT_PROVIDER | from json)
    _ => ($env.GPT_PROVIDER?)
  }
}

export def providers [] {
  {
    anthropic : {
      models: {||
        (
          http get
          -H {
            "x-api-key": $env.ANTHROPIC_API_KEY
            "anthropic-version": "2023-06-01"
          }
          https://api.anthropic.com/v1/models
          | get data
          | select id created_at
          | rename -c {created_at: "created"}
          | update created { into datetime }
          | sort-by -r created
        )
      }

      call: {|model: string, tools?: list|
        # anthropic only supports a single system message as a top level attribute
        let messages = $in
        let system_messages = $messages | where role == "system"
        let messages = $messages | where role != "system"

        let data = {
          model: $model
          max_tokens: 8192
          stream: true
          messages: $messages
          tools: ($tools | default [])
        } | conditional-pipe ($system_messages | is-not-empty) {
          insert "system" ($system_messages | get content | flatten)
        }

        let headers = {
          "x-api-key": $env.ANTHROPIC_API_KEY
          "anthropic-version": "2023-06-01"
        }

        if false {
          print $"data: ($data | to json)"
          print $"headers: ($headers | to json)"
          return (
            http post --full --allow-errors
            --content-type application/json
            -H $headers
            https://api.anthropic.com/v1/messages
            $data
          )
        }

        (
          http post
          --content-type application/json
          -H $headers
          https://api.anthropic.com/v1/messages
          $data
        )
      }
    }
  }
}

def conditional-pipe [
  condition: bool
  action: closure
] {
  if $condition { do $action } else { $in }
}

export def call [ --streamer: closure] {
  let content = $in

  let config = $env.GPT_PROVIDER
  let caller = providers | get $config.name | get call

  (
    $content
    | do $caller $config.model
    | conditional-pipe ($streamer | is-not-empty) {|| tee { each { do $streamer } } }
    | str join
  )
}

export def --env ensure-api-key [name: string] {
  let key_name = $"($name | str upcase)_API_KEY"
  if not ($key_name in $env) {
    let key = input -s $"\nRequired API key: $env.($key_name) = \"...\"\n\nIf you like, I can set it for you. Paste key: "
    set-env $key_name $key
    print "key set 👍\n"
  }
}

export def --env select-provider [] {
  print "Select a provider:"
  let name = providers | columns | input list
  print $"Selected provider: ($name)"

  let provider = providers | get $name
  ensure-api-key $name

  print -n "Select model:"
  let model = do $provider.models | get id | input list --fuzzy
  print $"Selected model: ($model)"
  $env.GPT_PROVIDER = {name: $name model: $model}
}

export def --env ensure-provider [] {
  if $env.GPT_PROVIDER? == null { select-provider }
  ensure-api-key $env.GPT_PROVIDER.name
}

export def --env models [] {
  ensure-provider
  let provider = providers | get $env.GPT_PROVIDER.name
  do $provider.models
}
