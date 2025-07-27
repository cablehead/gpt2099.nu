use std assert

# Provider models for smoke testing
const models = {
  anthropic: "claude-3-5-haiku-20241022"
  gemini: "gemini-2.5-flash"
}

# Asset mapping for dynamic fixture population
const assets = {
  "pdf-document": {file: "tests/fixtures/assets/doc.pdf" media_type: "application/pdf"}
  "image-document": {file: "tests/fixtures/assets/img.png" media_type: "image/png"}
}

# Load fixture with dynamic asset population
def load-fixture [case_path: string filename: string] {
  let case_name = ($case_path | path basename)
  let fixture_file = $case_path | path join $filename
  let base_fixture_file = $case_path | path join $"base-($filename)"

  # Use base fixture if available and case needs dynamic assets
  if ($case_name in $assets) and ($base_fixture_file | path exists) {
    let base_fixture = open $base_fixture_file
    let asset_info = $assets | get $case_name

    # Load asset data and update fixture
    let asset_data = open $asset_info.file --raw | encode base64
    $base_fixture | update-data-fields $asset_data
  } else if ($fixture_file | path exists) {
    open $fixture_file
  } else {
    error make {msg: $"Fixture not found: ($fixture_file)"}
  }
}

# Recursively update empty "data" fields with asset data
def update-data-fields [asset_data: string] {
  $in | if ($in | describe -d | get type) == "record" {
    $in | items {|key value|
      if $key == "data" and $value == "" {
        {$key: $asset_data}
      } else {
        {$key: ($value | update-data-fields $asset_data)}
      }
    } | into record
  } else if ($in | describe -d | get type) == "list" {
    $in | each {|item| $item | update-data-fields $asset_data }
  } else {
    $in
  }
}

# Test runner for prepare-request fixtures
export def run-all [
  provider: string # Provider name (anthropic, gemini, etc.)
  --call: string # API key to use for actual API calls (smoke test)
] {
  let fixtures_path = "tests/fixtures/prepare-request"
  let test_cases = (ls $fixtures_path | where type == dir | get name | path basename)

  if ($call | is-not-empty) {
    let model = $models | get $provider
    print $"Running ($test_cases | length) prepare-request test cases for ($provider) with API calls..."
    print "⚠️  This will make real API calls and consume tokens!"
    print $"Using ($model)"

    for case in $test_cases {
      test-case $provider $case --call $call
    }
  } else {
    print $"Running ($test_cases | length) prepare-request test cases for ($provider)..."

    for case in $test_cases {
      test-case $provider $case
    }
  }

  print $"\n🎉 All ($provider) prepare-request tests passed!"
}

def test-case [
  provider: string
  case_name: string
  --call: string # API key if making real calls
] {
  let case_path = ["tests" "fixtures" "prepare-request" $case_name] | path join

  # Load input and expected output, with dynamic asset loading
  let input = load-fixture $case_path "input.json"
  let expected = load-fixture $case_path $"expected-($provider).json"

  # Get provider implementation
  use ../../gpt/providers
  let provider_impl = providers all | get $provider
  let actual = do $provider_impl.prepare-request $input []

  if $call != null {
    # Smoke test - just verify API call works and returns events
    print $"🔄 Testing ($case_name) with API call..."

    try {
      let model = $models | get $provider

      # Simple smoke test: show events as they stream in
      let events = $actual | do $provider_impl.call $call $model | each {|event|
        print ($event | to json -r)
        $event
      } | collect

      if ($events | length) == 0 {
        error make {msg: "No response events received"}
      } else {
        print $"✓ ($case_name) - API call successful"
      }
    } catch {|e|
      print $"✗ ($case_name) API call failed: ($e.msg)"
      print $"Request payload: ($actual | to json)"
      error make {msg: $"API test failed: ($case_name)"}
    }
  } else {
    # Standard fixture comparison
    try {
      assert equal $actual $expected
      print $"✓ ($case_name)"
    } catch {|e|
      print $"✗ ($case_name): ($e.msg)"
      print $"Expected: ($expected | to json)"
      print $"Actual: ($actual | to json)"
      error make {msg: $"Test failed: ($case_name)"}
    }
  }
}

# Helper to eliminate duplication in optional call flag handling
def with-optional-call [case_name: string provider: string call?: string] {
  if ($call | is-not-empty) {
    test-case $provider $case_name --call $call
  } else {
    test-case $provider $case_name
  }
}

# Individual test functions - all identical one-liners
export def test-text-document [provider: string --call: string] { with-optional-call "text-document" $provider $call }
export def test-json-document [provider: string --call: string] { with-optional-call "json-document" $provider $call }
export def test-pdf-document [provider: string --call: string] { with-optional-call "pdf-document" $provider $call }
export def test-image-document [provider: string --call: string] { with-optional-call "image-document" $provider $call }
export def test-mixed-content [provider: string --call: string] { with-optional-call "mixed-content" $provider $call }
