use std assert

# Import the provider function directly since we're testing in isolation
use ./mod.nu *

# Test fixtures for prepare-request
def create-test-context [content_blocks] {
  {
    messages: [
      {
        role: "user"
        content: $content_blocks
      }
    ]
    options: {}
  }
}

def create-document-block [media_type: string content: string] {
  {
    type: "document"
    source: {
      type: "base64"
      media_type: $media_type
      data: ($content | encode base64)
    }
    cache_control: {type: "ephemeral"}
  }
}

def create-text-block [content: string] {
  {
    type: "text"
    text: $content
    cache_control: {type: "ephemeral"}
  }
}

export def test-markdown-conversion [] {
  let content = "# Hello World\n\nThis is a test."
  let doc_block = create-document-block "text/markdown" $content
  let context = create-test-context [$doc_block]
  
  let result = do (provider).prepare-request $context []
  let transformed = $result.messages.0.content.0
  
  assert equal $transformed.type "text"
  assert equal $transformed.text $content
  assert equal $transformed.cache_control {type: "ephemeral"}
  
  print "✓ Markdown document converted to text"
}

export def test-json-conversion [] {
  let content = '{"test": "data"}'
  let doc_block = create-document-block "application/json" $content
  let context = create-test-context [$doc_block]
  
  let result = do (provider).prepare-request $context []
  let transformed = $result.messages.0.content.0
  
  assert equal $transformed.type "text"
  assert equal $transformed.text $content
  assert equal $transformed.cache_control {type: "ephemeral"}
  
  print "✓ JSON document converted to text"
}

export def test-pdf-stays-document [] {
  let pdf_data = "fake-pdf-binary-data"
  let doc_block = create-document-block "application/pdf" $pdf_data
  let context = create-test-context [$doc_block]
  
  let result = do (provider).prepare-request $context []
  let transformed = $result.messages.0.content.0
  
  assert equal $transformed.type "document"
  assert equal $transformed.source.media_type "application/pdf"
  assert equal $transformed.source.data ($pdf_data | encode base64)
  assert equal $transformed.cache_control {type: "ephemeral"}
  
  print "✓ PDF document stays as document"
}

export def test-image-stays-document [] {
  let image_data = "fake-png-binary-data"
  let doc_block = create-document-block "image/png" $image_data
  let context = create-test-context [$doc_block]
  
  let result = do (provider).prepare-request $context []
  let transformed = $result.messages.0.content.0
  
  assert equal $transformed.type "document"
  assert equal $transformed.source.media_type "image/png"
  
  print "✓ PNG image stays as document"
}

export def test-mixed-content [] {
  let text_content = "# README\n\nThis is documentation."
  let pdf_data = "fake-pdf-data"
  
  let blocks = [
    (create-text-block "Regular text message")
    (create-document-block "text/markdown" $text_content)
    (create-document-block "application/pdf" $pdf_data)
  ]
  
  let context = create-test-context $blocks
  let result = do (provider).prepare-request $context []
  let content = $result.messages.0.content
  
  # First block should stay as text
  assert equal $content.0.type "text"
  assert equal $content.0.text "Regular text message"
  
  # Second block should be converted from document to text
  assert equal $content.1.type "text" 
  assert equal $content.1.text $text_content
  
  # Third block should stay as document
  assert equal $content.2.type "document"
  assert equal $content.2.source.media_type "application/pdf"
  
  print "✓ Mixed content handled correctly"
}

export def run-all [] {
  test-markdown-conversion
  test-json-conversion
  test-pdf-stays-document
  test-image-stays-document
  test-mixed-content
  
  print "\n🎉 All tests passed!"
}