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

export def document-turn [] {
  # Test markdown document
  let result = schema document-turn "tests/fixtures/assets/doc.md"

  # Verify structure
  assert equal $result.role "user"
  assert equal ($result.content | length) 1
  assert equal $result.content.0.type "document"
  assert equal $result.content.0.source.type "base64"
  assert equal $result.content.0.source.media_type "text/markdown"

  # Verify metadata is separate
  assert ($result._metadata.document_name | is-not-empty)
  assert equal $result._metadata.type "document"
  assert equal $result._metadata.content_type "text/markdown"

  print "✓ document-turn basic"

  # Test with cache and custom name
  let result = schema document-turn "tests/fixtures/assets/doc.md" {name: "Custom Doc" cache: true}
  assert equal $result.cache true
  assert equal $result._metadata.document_name "Custom Doc"

  print "✓ document-turn with options"
}

# Test that schema output produces the correct structure for prepare-request
export def schema-prepare-request-compatibility [] {
  # Generate schema output
  let schema_turn = schema document-turn "tests/fixtures/assets/doc.md" {cache: true}
  let schema_message = $schema_turn | reject _metadata

  # Verify it has the structure that prepare-request expects
  assert equal $schema_message.role "user"
  assert equal $schema_message.cache true
  assert equal ($schema_message.content | length) 1

  let content_block = $schema_message.content.0
  assert equal $content_block.type "document"
  assert equal $content_block.source.type "base64"
  assert equal $content_block.source.media_type "text/markdown"
  assert ($content_block.source.data | is-not-empty)

  # Verify the data decodes correctly
  let decoded = $content_block.source.data | decode base64 | decode utf-8
  assert ($decoded | str contains "README")

  print "✓ schema output compatible with prepare-request"

  # Test that this format works with actual provider prepare-request
  use ../../gpt/providers
  let anthropic_provider = providers all | get anthropic
  let context_window = {
    messages: [$schema_message]
    options: {}
  }

  # This should not error
  let prepared = do $anthropic_provider.prepare-request $context_window []
  assert ($prepared | is-not-empty)

  print "✓ schema output works with anthropic prepare-request"
}

export def main [] {
  print "Testing schema generation layer..."
  user-turn
  document-turn
  schema-prepare-request-compatibility
  print "\n🎉 All schema generation tests passed!"
}
