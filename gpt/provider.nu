use ./providers

export def enable [provider?: string] {
  let avail = providers all | columns

  let provider = if $provider != null {
    if $provider not-in $avail {
      error make {
        msg: $"unknown provider: ($provider)"
        label: {
          text: "the provider right here"
          span: (metadata $provider).span
        }
      }
    }
    $provider
  } else {
    let enabled = get-enabled | columns

    let togo = $avail | without $enabled

    if ($togo | is-empty) {
      return "all providers are enabled"
    }

    if ($togo | length) == 1 { $togo | first } else {
      $togo | input list "Select provider to enable" --fuzzy
    }
  }

  print $"Configuring: ($provider)"
  let key = input -s "Enter API key: "

  print -n $"\nquerying ($provider) to test key..."

  let p = providers all | get $provider
  print $"(do $p.models $key | length) models found"

  {name: $provider key: $key} | to json -r | .append gpt.provider

  # show the current summary of our setup
  main
}

export def get-enabled [] {
  .cat
  | where topic == "gpt.provider"
  | each { .cas | from json }
  | group-by name
  | values
  | each { last }
  | where key? != null
  | transpose -rd
}

export def main [] {
  let available = providers all
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

  let p = providers all | get $provider

  let model = do $p.models $key | get id | input list --fuzzy "Select model"
  print $"Selected model: ($model)"

  ptr | upsert $name {
    provider: $provider
    model: $model
  } | .append gpt.provider.ptrs --meta $in
}

export def models [provider: string] {
  let enabled = get-enabled
  let key = $enabled | get $provider
  let p = providers all | get $provider
  do $p.models $key
}

# Takes a list as pipeline input, and returns a new list containing elements
# that are present in the input list but not in the argument list.
#
# Example:
# > let all_items = ["apple", "banana", "cherry", "date"]
# > let owned_items = ["banana", "date", "grape"]
# > $all_items | without $owned_items
# ["apple", "cherry"]
def "without" [
  exclude: list
]: list -> list {
  where {|item| $item not-in $exclude }
}
