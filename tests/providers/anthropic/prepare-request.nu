use std assert
use ../../../gpt/providers/anthropic *

# Test runner for prepare-request fixtures
export def run-all [] {
  let fixtures_path = "tests/fixtures/prepare-request"
  
  # Get all test case directories
  let test_cases = (ls $fixtures_path | where type == dir | get name | path basename)
  
  print $"Running ($test_cases | length) prepare-request test cases for Anthropic..."
  
  for case in $test_cases {
    test-case $case
  }
  
  print "\n🎉 All Anthropic prepare-request tests passed!"
}

def test-case [case_name: string] {
  let case_path = ["tests" "fixtures" "prepare-request" $case_name] | path join
  
  # Load input and expected output
  let input = open ($case_path | path join "input.json")
  let expected = open ($case_path | path join "expected-anthropic.json")
  
  # Run the provider's prepare-request function
  let provider_impl = provider
  let actual = do $provider_impl.prepare-request $input []
  
  # Compare results
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

# Individual test functions for backward compatibility
export def test-text-document [] {
  test-case "text-document"
}

export def test-json-document [] {
  test-case "json-document"
}

export def test-pdf-document [] {
  test-case "pdf-document"
}

export def test-image-document [] {
  test-case "image-document"
}

export def test-mixed-content [] {
  test-case "mixed-content"
}