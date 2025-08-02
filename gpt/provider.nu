use ./providers

export def enable [
  provider?: string # Provider name to enable (if not specified, will prompt to select from available providers)
] {
  let secret = $in
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

  # Check if API key is provided via pipeline input
  let key = if ($secret | is-empty) {
    input -s "Enter API key: "
  } else {
    $secret
  }

  print -n $"querying ($provider) to test key..."

  let p = providers all | get $provider
  print $"(do $p.models $key | length) models found"

  {name: $provider key: $key} | to json -r | .append gpt.provider

  # show the current summary of our setup
  main
}

# Get a record of currently enabled providers with their API keys
export def get-enabled [] {
  .cat -T "gpt.provider"
  | each { .cas | from json }
  | group-by name
  | values
  | each { last }
  | where key? != null
  | transpose -rd
}

# Show the status of all providers and current pointer configurations
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

export def ptr [
  name?: string # Name of the provider pointer to retrieve or create
  --set # Create a new provider pointer with the given name
] {
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

export def set-ptr [
  name: string # Name for the new provider pointer
  provider?: string # Provider to use (if not specified, will prompt to select)
  model?: string # Model to use (if not specified, will prompt to select from available models)
] {
  let enabled = get-enabled

  let provider = if $provider != null {
    # Validate that the provider is enabled
    if $provider not-in ($enabled | columns) {
      error make {
        msg: $"Provider '($provider)' is not enabled. Available providers: ($enabled | columns | str join ', ')"
        label: {
          text: "this provider"
          span: (metadata $provider).span
        }
      }
    }
    print $"Using specified provider: ($provider)"
    $provider
  } else {
    let selected = $enabled | columns | input list "Select provider"
    print $"Selected provider: ($selected)"
    $selected
  }

  let key = $enabled | get $provider
  let p = providers all | get $provider

  let model = if $model != null {
    # If both provider and model are specified, validate the model
    if $provider != null {
      let available_models = do $p.models $key | get id
      if $model not-in $available_models {
        error make {
          msg: $"Model '($model)' not found for provider '($provider)'. Available models: ($available_models | str join ', ')"
          label: {
            text: "this model"
            span: (metadata $model).span
          }
        }
      }
    }
    print $"Using specified model: ($model)"
    $model
  } else {
    let selected = do $p.models $key | get id | input list --fuzzy "Select model"
    print $"Selected model: ($selected)"
    $selected
  }

  ptr | upsert $name {
    provider: $provider
    model: $model
  } | .append gpt.provider.ptrs --meta $in
}

export def models [
  provider: string # Provider name to list models for
] {
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
