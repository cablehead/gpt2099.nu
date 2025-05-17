use ./providers/gemini
use ./providers/anthropic
use ./providers/openai

export def get-implementations [] {
  {
    anthropic : (anthropic provider)
    gemini : (gemini provider)
    openai : (openai provider)
  }
}

export def get-providers [] {
  .cat
  | where topic == "gpt.provider"
  | each { .cas | from json }
  | group-by name
  | values
  | each { last }
  | transpose -rd
}

export def main [] {
  let available = get-implementations
  let enabled = get-providers

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
  $ptr | insert key (get-providers | get $ptr.provider)
}

export def set-ptr [name: string] {
  let providers = get-providers
  let provider = $providers | columns | input list "Select provider"
  print $"Selected provider: ($provider)"
  let key = $providers | get $provider

  let p = (get-implementations) | get $provider

  let model = do $p.models $key | get id | input list --fuzzy "Select model"
  print $"Selected model: ($model)"

  ptr | upsert $name {
    provider: $provider
    model: $model
  } | .append gpt.provider.ptrs --meta $in
}
