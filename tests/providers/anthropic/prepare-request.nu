use std assert
use ../../../gpt/providers/anthropic *

const model = "claude-3-5-haiku-20241022"

# Test runner for prepare-request fixtures
export def run-all [
  --call: string # API key to use for actual API calls
] {
  let fixtures_path = "tests/fixtures/prepare-request"
  let test_cases = (ls $fixtures_path | where type == dir | get name | path basename)
  
  if ($call | is-not-empty) {
    print $"Running ($test_cases | length) prepare-request test cases for Anthropic with API calls..."
    print "⚠️  This will make real API calls and consume tokens!"
    print $"Using ($model)"
    
    for case in $test_cases {
      test-case $case --call $call
    }
  } else {
    print $"Running ($test_cases | length) prepare-request test cases for Anthropic..."
    
    for case in $test_cases {
      test-case $case
    }
  }
  
  print "\n🎉 All Anthropic prepare-request tests passed!"
}

def test-case [
  case_name: string 
  --call: string # API key if making real calls
] {
  let case_path = ["tests" "fixtures" "prepare-request" $case_name] | path join
  
  # Load input and expected output
  let input = open ($case_path | path join "input.json")
  let expected = open ($case_path | path join "expected-anthropic.json")
  
  # Run the provider's prepare-request function
  let provider_impl = provider
  let actual = do $provider_impl.prepare-request $input []
  
  if $call != null {
    # Test the full pipeline
    print $"🔄 Testing ($case_name) with API call..."
    
    try {
      let response = $actual | do $provider_impl.call $call $model
      
      # Collect more events to better validate the response
      let events = $response | take 10 | collect
      if ($events | is-empty) {
        error make {msg: "No response events received"}
      }
      
      # Look for expected event types
      let has_message_start = $events | any {|e| $e.type? == "message_start"}
      let has_content = $events | any {|e| $e.type? == "content_block_start" or $e.type? == "content_block_delta"}
      
      if not $has_message_start {
        print $"Warning: No message_start event found in ($case_name)"
      }
      
      print $"✓ ($case_name) - API call successful, received ($events | length) events ($has_message_start and $has_content)"
      
      # Optionally show first few events for manual inspection
      if $env.GPT_TEST_VERBOSE? == "true" {
        print $"First event: ($events | first | to json)"
        if $has_content {
          let content_event = $events | where {|e| $e.type? == "content_block_start" or $e.type? == "content_block_delta"} | first
          print $"Content event: ($content_event | to json)"
        }
      }
      
    } catch { |e|
      print $"✗ ($case_name) API call failed: ($e.msg)"
      print $"Request payload: ($actual | to json)"
      error make {msg: $"API test failed: ($case_name)"}
    }
  } else {
    # Standard fixture comparison
    try {
      assert equal $actual $expected
      print $"✓ ($case_name)"
    } catch { |e|
      print $"✗ ($case_name): ($e.msg)"
      print $"Expected: ($expected | to json)"
      print $"Actual: ($actual | to json)"
      error make {msg: $"Test failed: ($case_name)"}
    }
  }
}

# Individual test functions for backward compatibility
export def test-text-document [
  --call: string # API key to use for actual API calls
] {
  if ($call | is-not-empty) {
    test-case "text-document" --call $call
  } else {
    test-case "text-document"
  }
}

export def test-json-document [
  --call: string # API key to use for actual API calls
] {
  if ($call | is-not-empty) {
    test-case "json-document" --call $call
  } else {
    test-case "json-document"
  }
}

export def test-pdf-document [
  --call: string # API key to use for actual API calls
] {
  if ($call | is-not-empty) {
    test-case "pdf-document" --call $call
  } else {
    test-case "pdf-document"
  }
}

export def test-image-document [
  --call: string # API key to use for actual API calls
] {
  if ($call | is-not-empty) {
    test-case "image-document" --call $call
  } else {
    test-case "image-document"
  }
}

export def test-mixed-content [
  --call: string # API key to use for actual API calls
] {
  if ($call | is-not-empty) {
    test-case "mixed-content" --call $call
  } else {
    test-case "mixed-content"
  }
}
