use std assert

# Provider models for smoke testing
const models = {
  anthropic: "claude-3-5-haiku-20241022"
  gemini: "gemini-2.5-flash"
  openai: "gpt-4.1-mini"
}

# Asset mapping for dynamic fixture population
const assets = {
  "document-pdf": {file: "tests/fixtures/assets/doc.pdf" media_type: "application/pdf"}
  "document-image": {file: "tests/fixtures/assets/img.png" media_type: "image/png"}
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

  # Load tools dynamically based on servers
  let tools = if ($input.options?.servers? | is-not-empty) {
    $input.options.servers | each {|server|
      let tool_file = $"tests/fixtures/providers/tools/($server).json"
      if ($tool_file | path exists) {
        open $tool_file
      } else {
        error make {msg: $"Tool file not found: ($tool_file)"}
      }
    } | flatten
  } else {
    []
  }

  use ../utils/output.nu *
  start $"prepare-request.($provider).($case_name)"

  try {
    let actual = do $provider_impl.prepare-request $input $tools
    error make {msg: $"Test failed: ($case_name) - expected error but succeeded"}
  } catch {|e|
    if ($e.msg | str contains $expected_error) {
      ok
    } else {
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
  capture?: bool # Capture streaming responses to fixtures
] {
  let fixtures_path = "tests/fixtures/providers/prepare-request"
  let test_cases = (ls $fixtures_path | where type == dir | get name | path basename)

  for case in $test_cases {
    test-case $provider $case $api_key $capture
  }
}

def test-case [
  provider: string
  case_name: string
  api_key?: string # API key if making real calls
  capture?: bool # Capture streaming responses to fixtures
] {
  let case_path = ["tests" "fixtures" "providers" "prepare-request" $case_name] | path join

  # Check if expected fixture exists for this provider (.json or .err)
  let expected_json_file = [$case_path $"expected-($provider).json"] | path join
  let expected_err_file = [$case_path $"expected-($provider).err"] | path join

  let has_json = ($expected_json_file | path exists)
  let has_err = ($expected_err_file | path exists)

  if not ($has_json or $has_err) {
    use ../utils/output.nu *
    start $"prepare-request.($provider).($case_name)"
    skipped "no expected fixture"
    return
  }

  # Skip API calls for .err cases (they indicate unsupported features)
  if $has_err and ($api_key | is-not-empty) {
    use ../utils/output.nu *
    start $"prepare-request.($provider).($case_name).api-call"
    skipped "err fixture indicates unsupported feature"
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

  # Load tools dynamically based on servers
  let tools = if ($input.options?.servers? | is-not-empty) {
    $input.options.servers | each {|server|
      let tool_file = $"tests/fixtures/providers/tools/($server).json"
      if ($tool_file | path exists) {
        open $tool_file
      } else {
        error make {msg: $"Tool file not found: ($tool_file)"}
      }
    } | flatten
  } else {
    []
  }

  let actual = do $provider_impl.prepare-request $input $tools

  if ($api_key | is-not-empty) {
    # Smoke test - just verify API call works and returns events
    use ../utils/output.nu *
    start $"prepare-request.($provider).($case_name).api-call"

    try {
      let model = $models | get $provider

      # Simple smoke test: show events as they stream in
      let events = $actual | do $provider_impl.call $api_key $model | each {|event|
        print ($event | to json -r)
        $event
      } | collect

      # Capture streaming events if --capture flag is set
      if ($capture | default false) {
        let capture_dir = ["tests" "fixtures" "providers" "response-stream" $provider $case_name] | path join
        mkdir $capture_dir
        let capture_file = $capture_dir | path join "events.jsonl"
        $events | each {|event| $event | to json -r } | str join "\n" | save -f $capture_file
        print $"  Captured ($events | length) events to ($capture_file)"
      }

      if ($events | length) == 0 {
        error make {msg: "No response events received"}
      } else {
        ok
      }
    } catch {|e|
      error make {msg: $"API test failed: ($case_name) ($e)"}
    }
  } else {
    # Standard fixture comparison
    use ../utils/output.nu *
    start $"prepare-request.($provider).($case_name)"

    assert equal $actual $expected
    ok
  }
}

export def main [
  provider?: string # Provider name (anthropic, gemini, etc.) - runs all providers if omitted
  test_case?: string # Test case name (text-document, json-document, etc.) - runs all if omitted
  --call: any # API key (string) or closure that returns key for provider
  --capture # Capture streaming responses to fixtures (requires --call)
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
      test-case $prov $test_case $api_key $capture
    } else {
      # Run all test cases for this provider
      run-all $prov $api_key $capture
    }
  }
}
