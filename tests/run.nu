# Run all tests in the gpt2099 test suite

export def main [] {
  # Set standardized log format
  $env.NU_LOG_FORMAT = '- %MSG%'

  # Load required environment for end-to-end tests
  use xs.nu *
  overlay use -pr /root/session/gpt2099.nu/gpt

  # Run all test suites
  use unit/util.nu
  util
  use unit/mcp-response-processing.nu
  mcp-response-processing
  use schema/test-schema-generation.nu
  test-schema-generation
  use providers/test-prepare-request.nu
  test-prepare-request
  use end-to-end/test-end-to-end.nu
  test-end-to-end
}
