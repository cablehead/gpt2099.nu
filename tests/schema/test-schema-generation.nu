use std assert
use ../../gpt/schema.nu

# Test that schema generation produces the expected normalized format
# This validates that our test fixtures match real-world usage

export def user-turn [] {
  use ../output.nu *

  # Test basic text turn
  start "schema.user-turn.basic-text"
  let result = schema user-turn "Hello world"
  let expected = {
    role: "user"
    content: [
      {type: "text" text: "Hello world"}
    ]
  }
  assert equal $result $expected
  ok

  # Test with cache
  start "schema.user-turn.with-cache"
  let result = schema user-turn "Cached content" {cache: true}
  let expected = {
    role: "user"
    content: [
      {type: "text" text: "Cached content"}
    ]
    cache: true
  }
  assert equal $result $expected
  ok
}

export def main [] {
  user-turn
}
