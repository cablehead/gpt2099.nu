# Run all tests in the gpt2099 test suite

export def main [suite?: string] {
  # Load required environment for integration tests
  use xs.nu *
  use output.nu *
  use ../gpt

  let all_suites = ["unit" "providers" "integration"]
  let suites_to_run = if $suite == null {
    $all_suites
  } else if $suite in $all_suites {
    [$suite]
  } else {
    error make {msg: $"Unknown test suite: ($suite). Available: ($all_suites | str join ', ')"}
  }

  for test_suite in $suites_to_run {
    start $"($test_suite) tests"
    try {
      match $test_suite {
        "unit" => {
          use unit/util.nu
          util
          use unit/mcp-response-processing.nu
          mcp-response-processing
        }
        "providers" => {
          use providers/test-prepare-request.nu
          test-prepare-request
        }
        "integration" => {
          use integration/test-integration.nu
          test-integration
        }
      }
      ok
    } catch {|err|
      failed $err.msg
    }
    print "" # Add spacing between suites when running multiple
  }
}
