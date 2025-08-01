use std assert
use ../../gpt/schema.nu

# Test that schema generation produces the expected normalized format
# This validates that our test fixtures match real-world usage

export def user-turn [] {
  use std/log

  # Test basic text turn
  log info "schema.user-turn.basic-text"
  let result = schema user-turn "Hello world"
  let expected = {
    role: "user"
    content: [
      {type: "text" text: "Hello world"}
    ]
  }
  assert equal $result $expected
  log info "ok"

  # Test with cache
  log info "schema.user-turn.with-cache"
  let result = schema user-turn "Cached content" {cache: true}
  let expected = {
    role: "user"
    content: [
      {type: "text" text: "Cached content"}
    ]
    cache: true
  }
  assert equal $result $expected
  log info "ok"
}

export def main [] {
  $env.NU_LOG_FORMAT = '- %MSG%'
  user-turn
}
