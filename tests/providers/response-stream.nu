use std assert

# Provider models (not used for playback, but kept for reference)
const models = {
  anthropic: "claude-3-5-haiku-20241022"
  gemini: "gemini-2.5-flash"
  openai: "gpt-4.1-mini"
}

# Test a single case for response_stream_aggregate
def test-aggregate [
  provider: string
  case_name: string
] {
  use ../utils/output.nu *
  start $"response-stream-aggregate.($provider).($case_name)"

  let case_path = ["tests" "fixtures" "providers" "response-stream" $provider $case_name] | path join
  let events_file = $case_path | path join "events.jsonl"

  if not ($events_file | path exists) {
    skip "no events fixture"
    return
  }

  # Load events from JSONL (one JSON object per line)
  let events = open $events_file | lines | each {|line| $line | from json }

  # Get provider implementation
  use ../../gpt/providers
  let provider_impl = providers all | get $provider

  try {
    # Run response_stream_aggregate on the events
    let result = $events | do $provider_impl.response_stream_aggregate

    # For now, just validate it doesn't error and returns something
    if ($result | is-empty) {
      error make {msg: "response_stream_aggregate returned empty result"}
    }

    # Compare against expected-aggregate.json if it exists
    let expected_file = $case_path | path join "expected-aggregate.json"
    if ($expected_file | path exists) {
      let expected = open $expected_file

      # Normalize: Replace random UUIDs in tool_use content with fixed UUID for comparison
      # This is needed for Gemini which generates random UUIDs (Anthropic provides them)
      let normalized_result = $result | update message.content {
        $in | each {|item|
          if $item.type == "tool_use" and ($item.id? | describe) == "string" {
            $item | update id "00000000-0000-0000-0000-000000000000"
          } else {
            $item
          }
        }
      }

      let normalized_expected = $expected | update message.content {
        $in | each {|item|
          if $item.type == "tool_use" and ($item.id? | describe) == "string" {
            $item | update id "00000000-0000-0000-0000-000000000000"
          } else {
            $item
          }
        }
      }

      assert equal $normalized_result $normalized_expected
    }

    ok
  } catch {|e|
    error make {msg: $"Aggregate test failed: ($case_name) - ($e.msg)"}
  }
}

# Test a single case for response_stream_streamer
def test-streamer [
  provider: string
  case_name: string
] {
  use ../utils/output.nu *
  start $"response-stream-streamer.($provider).($case_name)"

  let case_path = ["tests" "fixtures" "providers" "response-stream" $provider $case_name] | path join
  let events_file = $case_path | path join "events.jsonl"

  if not ($events_file | path exists) {
    skip "no events fixture"
    return
  }

  # Load events from JSONL
  let events = open $events_file | lines | each {|line| $line | from json }

  # Get provider implementation
  use ../../gpt/providers
  let provider_impl = providers all | get $provider

  try {
    # Run response_stream_streamer on each event
    let results = $events | each {|event|
      do $provider_impl.response_stream_streamer $event
    } | where $it != null

    # Compare against expected-streamer.jsonl if it exists
    let expected_file = $case_path | path join "expected-streamer.jsonl"
    if ($expected_file | path exists) {
      let expected = open $expected_file | lines | each {|line| $line | from json }
      assert equal $results $expected
    }

    ok
  } catch {|e|
    error make {msg: $"Streamer test failed: ($case_name) - ($e.msg)"}
  }
}

# Run all tests for a provider
def run-all [
  provider: string
  test_type: string # "aggregate" or "streamer" or "both"
] {
  let fixtures_path = ["tests" "fixtures" "providers" "response-stream" $provider] | path join

  if not ($fixtures_path | path exists) {
    print $"No fixtures found for provider: ($provider)"
    return
  }

  let test_cases = (ls $fixtures_path | where type == dir | get name | path basename)

  for case in $test_cases {
    if $test_type == "aggregate" or $test_type == "both" {
      test-aggregate $provider $case
    }
    if $test_type == "streamer" or $test_type == "both" {
      test-streamer $provider $case
    }
  }
}

export def main [
  provider?: string # Provider name (anthropic, gemini, openai) - runs all providers if omitted
  test_case?: string # Test case name - runs all if omitted
  --aggregate # Only test response_stream_aggregate
  --streamer # Only test response_stream_streamer
] {
  # Get available providers
  use ../../gpt/providers
  let available_providers = providers all | columns

  let providers_to_test = if ($provider | is-not-empty) {
    if $provider not-in $available_providers {
      error make {msg: $"Unknown provider: ($provider). Available: ($available_providers | str join ', ')"}
    }
    [$provider]
  } else {
    $available_providers
  }

  # Determine which test type to run
  let test_type = if $aggregate and $streamer {
    "both"
  } else if $aggregate {
    "aggregate"
  } else if $streamer {
    "streamer"
  } else {
    "both"  # Default to both
  }

  for prov in $providers_to_test {
    if ($test_case | is-not-empty) {
      # Run single test case for this provider
      if $test_type == "aggregate" or $test_type == "both" {
        test-aggregate $prov $test_case
      }
      if $test_type == "streamer" or $test_type == "both" {
        test-streamer $prov $test_case
      }
    } else {
      # Run all test cases for this provider
      run-all $prov $test_type
    }
  }
}
