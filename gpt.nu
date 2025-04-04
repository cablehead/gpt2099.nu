export-env {
  # Coerce the provider to a record if it's a string.
  $env.GPT_PROVIDER = match ($env.GPT_PROVIDER? | describe -d | get type) {
    "string" => ($env.GPT_PROVIDER | from json)
    _ => ($env.GPT_PROVIDER?)
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

  let p = providers | get $config.name

  (
    $content
    | do $p.call $config.model
    | conditional-pipe ($streamer | is-not-empty) {|| tee { each { do $streamer } } }
    | do $p.aggregate_response
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
