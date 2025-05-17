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

export def goose [name?: string subcommand?: string] {
  if $name == null {

    let available = get-implementations
    let enabled = get-providers

    return (
      $available | columns | each {|name|
        {
          name: $name
          enabled: ($name in $enabled)
        }
      }
    )
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

export def ptr [name: string] {
  let res = .head gpt.provider.ptrs | .cas | from json | get $name
  $res | insert key (get-providers | get $res.provider)
}
