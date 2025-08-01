# Run all tests in the gpt2099 test suite

export def main [] {
  print "🧪 Running gpt2099 test suite...\n"

  # Load required environment for end-to-end tests
  use xs.nu *
  overlay use -pr /root/session/gpt2099.nu/gpt

  # Run unit tests
  print "Unit Tests:"
  use unit/util.nu
  util
  use unit/mcp-response-processing.nu
  mcp-response-processing
  print ""

  # Run schema layer tests
  print "Schema Layer Tests:"
  use schema/test-schema-generation.nu
  test-schema-generation
  print ""

  # Run provider transformation tests
  print "Provider Transformation Tests:"
  use providers/test-prepare-request.nu
  test-prepare-request
  print ""

  # Run end-to-end tests
  print "End-to-End Tests:"
  use end-to-end/test-end-to-end.nu
  test-end-to-end

  print "\n🎉 All tests completed successfully!"
}
