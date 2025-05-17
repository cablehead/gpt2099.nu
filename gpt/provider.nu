use ./providers

export def get-enabled [] {
  .cat
  | where topic == "gpt.provider"
  | each { .cas | from json }
  | group-by name
  | values
  | each { last }
  | transpose -rd
}

export def main [] {
  let available = providers
  let enabled = get-enabled

  return {
    providers: (
      $available | columns | each {|name|
        {
          name: $name
          enabled: ($name in $enabled)
        }
      }
    )
    ptrs: (ptr)
  }
}

export def ptr [name?: string --set] {
  if $set {
    if $name == null {
      error make {
        msg: "name is required"
        label: {
          text: "the name right here"
          span: (metadata $name).span
        }
      }
    }
    return (set-ptr $name)
  }

  let ptrs = .head gpt.provider.ptrs | default {} | get meta? | default {}

  if $name == null {
    return $ptrs
  }

  let ptr = $ptrs | get $name
  $ptr | insert key (get-enabled | get $ptr.provider)
}

export def set-ptr [name: string] {
  let enabled = get-enabled
  let provider = $enabled | columns | input list "Select provider"
  print $"Selected provider: ($provider)"
  let key = $enabled | get $provider

  let p = providers | get $provider

  let model = do $p.models $key | get id | input list --fuzzy "Select model"
  print $"Selected model: ($model)"

  ptr | upsert $name {
    provider: $provider
    model: $model
  } | .append gpt.provider.ptrs --meta $in
}
