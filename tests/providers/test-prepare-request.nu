use std assert

# Provider models for smoke testing
const models = {
  anthropic: "claude-3-5-haiku-20241022"
  gemini: "gemini-2.5-flash"
}

# Asset mapping for dynamic fixture population
const assets = {
  "document-pdf": {file: "tests/fixtures/assets/doc.pdf" media_type: "application/pdf"}
  "document-image": {file: "tests/fixtures/assets/img.png" media_type: "image/png"}
}

# Mock MCP tools for testing
const mock_tools = [
  {
    name: "filesystem___read_file"
    description: "Read the complete contents of a file from the file system."
    inputSchema: {
      "$schema": "http://json-schema.org/draft-07/schema#"
      additionalProperties: false
      properties: {
        path: {type: "string"}
      }
      required: ["path"]
      type: "object"
    }
  }
]

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

# Test case that expects an error
def test-error-case [
  provider: string
  case_name: string
  input: record
  expected_error: string
] {
  # Get provider implementation
  use ../../gpt/providers
  let provider_impl = providers all | get $provider

  # Provide mock tools if the input specifies servers
  let tools = if ($input.options?.servers? | is-not-empty) {
    $mock_tools
  } else {
    []
  }

  try {
    let actual = do $provider_impl.prepare-request $input $tools
    print $"✗ ($case_name): Expected error but got successful result"
    print $"Result: ($actual | to json)"
    error make {msg: $"Test failed: ($case_name) - expected error but succeeded"}
  } catch {|e|
    if ($e.msg | str contains $expected_error) {
      print $"✓ ($case_name)"
    } else {
      print $"✗ ($case_name): Wrong error message"
      print $"Expected: ($expected_error)"
      print $"Actual: ($e.msg)"
      error make {msg: $"Test failed: ($case_name) - wrong error message"}
    }
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

# Test runner for prepare-request fixtures (internal)
def run-all [
  provider: string # Provider name (anthropic, gemini, etc.)
  api_key?: string # API key for actual calls (optional)
] {
  let fixtures_path = "tests/fixtures/prepare-request"
  let test_cases = (ls $fixtures_path | where type == dir | get name | path basename)

  if ($api_key | is-not-empty) {
    let model = $models | get $provider
    print $"Running ($test_cases | length) prepare-request test cases for ($provider) with API calls..."
    print "⚠️  This will make real API calls and consume tokens!"
    print $"Using ($model)"
  } else {
    print $"Running ($test_cases | length) prepare-request test cases for ($provider)..."
  }

  for case in $test_cases {
    test-case $provider $case $api_key
  }

  print $"\n🎉 All ($provider) prepare-request tests passed!"
}

def test-case [
  provider: string
  case_name: string
  api_key?: string # API key if making real calls
] {
  let case_path = ["tests" "fixtures" "prepare-request" $case_name] | path join

  # Check if expected fixture exists for this provider (.json or .err)
  let expected_json_file = [$case_path $"expected-($provider).json"] | path join
  let expected_err_file = [$case_path $"expected-($provider).err"] | path join

  let has_json = ($expected_json_file | path exists)
  let has_err = ($expected_err_file | path exists)

  if not ($has_json or $has_err) {
    print $"⚠️  Skipping ($provider)/($case_name) - no expected fixture"
    return
  }

  # Skip API calls for .err cases (they indicate unsupported features)
  if $has_err and ($api_key | is-not-empty) {
    print $"⚠️  Skipping ($provider)/($case_name) API call - .err fixture indicates unsupported feature"
    return
  }

  # Load input
  let input = load-fixture $case_path "input.json"

  # For .err cases, we expect an error; for .json cases, we compare output
  if $has_err {
    let expected_error = open $expected_err_file | str trim
    test-error-case $provider $case_name $input $expected_error
    return
  }

  let expected = load-fixture $case_path $"expected-($provider).json"

  # Get provider implementation
  use ../../gpt/providers
  let provider_impl = providers all | get $provider

  # Provide mock tools if the input specifies servers
  let tools = if ($input.options?.servers? | is-not-empty) {
    $mock_tools
  } else {
    []
  }

  let actual = do $provider_impl.prepare-request $input $tools

  if ($api_key | is-not-empty) {
    # Smoke test - just verify API call works and returns events
    print $"🔄 Testing ($case_name) with API call..."

    try {
      let model = $models | get $provider

      # Simple smoke test: show events as they stream in
      let events = $actual | do $provider_impl.call $api_key $model | each {|event|
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

export def main [
  provider?: string # Provider name (anthropic, gemini, etc.) - runs all providers if omitted
  test_case?: string # Test case name (text-document, json-document, etc.) - runs all if omitted
  --call: any # API key (string) or closure that returns key for provider
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

  for prov in $providers_to_test {
    # Resolve API key for this provider
    let api_key = if ($call | is-not-empty) {
      match ($call | describe -d | get type) {
        "string" => $call
        "closure" => (do $call $prov)
        _ => ( error make {msg: "--call must be a string or closure"})
      }
    } else { null }

    if ($test_case | is-not-empty) {
      # Run single test case for this provider
      test-case $prov $test_case $api_key
    } else {
      # Run all test cases for this provider
      run-all $prov $api_key
    }
  }
}
