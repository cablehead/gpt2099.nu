#!/usr/bin/env nu

# Generate expected output fixtures from captured streaming events

use ../../gpt/providers

def main [
  provider: string
  test_case: string
] {
  let p = providers all | get $provider
  let base_path = ["tests" "fixtures" "providers" "response-stream" $provider $test_case] | path join
  let events_file = $base_path | path join "events.jsonl"

  if not ($events_file | path exists) {
    error make {msg: $"Events file not found: ($events_file)"}
  }

  # Load events
  let events = open $events_file | lines | each {|line| $line | from json }

  # Generate expected-aggregate.json
  let aggregate = $events | do $p.response_stream_aggregate
  $aggregate | to json -i 2 | save -f ($base_path | path join "expected-aggregate.json")
  print $"Generated ($base_path)/expected-aggregate.json"

  # Generate expected-streamer.jsonl
  let streamer_output = $events | each {|event|
    do $p.response_stream_streamer $event
  } | where $it != null | each { to json -r } | str join "\n"

  $streamer_output | save -f ($base_path | path join "expected-streamer.jsonl")
  print $"Generated ($base_path)/expected-streamer.jsonl"
}
