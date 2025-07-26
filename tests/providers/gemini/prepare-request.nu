use std assert
use ../../../gpt/providers/gemini *

const model = "gemini-1.5-flash"

# Asset mapping for dynamic fixture population
const assets = {
  "pdf-document": {file: "tests/fixtures/assets/doc.pdf", media_type: "application/pdf"}
  "image-document": {file: "tests/fixtures/assets/img.png", media_type: "image/png"}
}

# Load fixture with dynamic asset population
def load-fixture [case_path: string, filename: string] {
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
    $in | items {|key, value|
      if $key == "data" and $value == "" {
        {$key: $asset_data}
      } else {
        {$key: ($value | update-data-fields $asset_data)}
      }
    } | into record
  } else if ($in | describe -d | get type) == "list" {
    $in | each {|item| $item | update-data-fields $asset_data}
  } else {
    $in
  }
}

# Test runner for prepare-request fixtures
export def run-all [
  --call: string # API key to use for actual API calls
] {
  let fixtures_path = "tests/fixtures/prepare-request"
  let test_cases = (ls $fixtures_path | where type == dir | get name | path basename)
  
  if ($call | is-not-empty) {
    print $"Running ($test_cases | length) prepare-request test cases for Gemini with API calls..."
    print "⚠️  This will make real API calls and consume tokens!"
    print $"Using ($model)"
    
    for case in $test_cases {
      test-case $case --call $call
    }
  } else {
    print $"Running ($test_cases | length) prepare-request test cases for Gemini..."
    
    for case in $test_cases {
      test-case $case
    }
  }
  
  print "\n🎉 All Gemini prepare-request tests passed!"
}

def test-case [
  case_name: string 
  --call: string # API key if making real calls
] {
  let case_path = ["tests" "fixtures" "prepare-request" $case_name] | path join
  
  # Load input and expected output, with dynamic asset loading
  let input = load-fixture $case_path "input.json"
  let expected = load-fixture $case_path "expected-gemini.json"
  
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
      
      # Look for expected event types in Gemini response
      let has_candidates = $events | any {|e| $e.candidates? != null}
      let has_content = $events | any {|e| 
        ($e.candidates? != null) and ($e.candidates | any {|c| $c.content? != null})
      }
      
      if not $has_candidates {
        print $"Warning: No candidates found in ($case_name)"
      }
      
      print $"✓ ($case_name) - API call successful, received ($events | length) events ($has_candidates and $has_content)"
      
      # Optionally show first few events for manual inspection
      if $env.GPT_TEST_VERBOSE? == "true" {
        print $"First event: ($events | first | to json)"
        if $has_content {
          let content_event = $events | where {|e| 
            ($e.candidates? != null) and ($e.candidates | any {|c| $c.content? != null})
          } | first
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