export def response_streamer [] {
  generate {|event state = 0|
    mut state = $state

    if "type" in $event {
      if $state > 0 {
        print "\n"
      }

      $state = $state + 1

      print -n $event.type

      if "name" in $event {
        print -n $"\(($event.name)\)"
      }
      print ":"
    }

    if "content" in $event {
      print -n $event.content
    }

    return {next: $state}
  }
}

use ./anthropic.nu

export def main [] {
  {
    anthropic : (anthropic provider)
  }
}
