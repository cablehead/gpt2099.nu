use ./providers/gemini

export def get-implementations [] {
  {
    # anthropic : (anthropic provider)
    gemini : (gemini provider)
    # openai : (openai provider)
  }
}
def get-providers [] {
  .cat
  | where topic == "gpt.provider"
  | each { .cas | from json }
  | group-by name
  | values
  | each { last }
  | transpose -rd
}

export def main [name?: string subcommand?: string] {
  if $name == null {
    return (get-providers)
  }

  let key = get-providers | get -i $name | if ($in | is-empty) {
    error make {
      msg: $"provider: `($name)` is not enabled"
      label: {
        text: "the provider right here"
        span: (metadata $name).span
      }
    }
  } else { }

  let p = (get-implementations) | get $name

  match $subcommand {
    "models" => {
      do $p.models $key
    }

    _ => (
      error make {
        msg: $"subcommand: `($subcommand)` is not supported"
        label: {
          text: "the subcommand right here"
          span: (metadata $subcommand).span
        }
      }
    )
  }
}
