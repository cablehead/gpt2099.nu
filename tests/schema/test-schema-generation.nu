use std assert
use ../../gpt/schema.nu

# Test that schema generation produces the expected normalized format
# This validates that our test fixtures match real-world usage

export def user-turn [] {
  # Test basic text turn
  let result = schema user-turn "Hello world"
  let expected = {
    role: "user"
    content: [
      {type: "text" text: "Hello world"}
    ]
  }
  assert equal $result $expected
  print "✓ user-turn basic text"

  # Test with cache
  let result = schema user-turn "Cached content" {cache: true}
  let expected = {
    role: "user"
    content: [
      {type: "text" text: "Cached content"}
    ]
    cache: true
  }
  assert equal $result $expected
  print "✓ user-turn with cache"
}

export def main [] {
  print "Testing schema generation layer..."
  user-turn
  print "\n🎉 All schema generation tests passed!"
}
