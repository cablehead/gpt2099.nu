# Run all tests in the gpt2099 test suite

export def main [] {
  print "🧪 Running gpt2099 test suite...\n"

  # Run schema layer tests
  print "📋 Schema Layer Tests:"
  use schema/test-schema-generation.nu
  test-schema-generation
  print ""

  # Run provider transformation tests
  print "🔄 Provider Transformation Tests:"
  use providers/test-prepare-request.nu
  test-prepare-request

  print "\n🎉 All tests completed successfully!"
}
