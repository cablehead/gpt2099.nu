use std assert
use ../../gpt/schema.nu

# Test that schema generation produces the expected normalized format
# This validates that our test fixtures match real-world usage

export def add-turn [] {
  use ../output.nu *

  # Test basic text turn - note: add-turn creates and stores the turn, 
  # so we test the normalized content structure from the stored turn
  start "schema.add-turn.basic-text"
  let turn = "Hello world" | schema add-turn {}
  let stored_content = .cas $turn.hash | from json
  let expected = [
    {type: "text" text: "Hello world"}
  ]
  assert equal $stored_content $expected
  ok

  # Test with cache
  start "schema.add-turn.with-cache"
  let turn = "Cached content" | schema add-turn {cache: true}
  assert equal $turn.meta?.cache? true
  let stored_content = .cas $turn.hash | from json
  let expected = [
    {type: "text" text: "Cached content"}
  ]
  assert equal $stored_content $expected
  ok
}

export def main [] {
  add-turn
}
