# Provider API Specification

This document outlines the interface required for implementing a provider in the cross.stream LLM
framework. Each provider must export a record with the following closures to ensure compatibility
with the command handler.

## Core Provider Interface

### `models`

Retrieves available models from the provider.

**Input:**

- `key: string` - API key for provider authentication

**Output:**

- A list of available model records, each containing at least:
  - `id: string` - The model identifier
  - `created: datetime` - When the model was created/updated

### `prepare-request`

Formats messages and tools into the provider-specific request structure.

**Input:**

- Context window in normalized format (see
  [Schema Reference](./schemas.md#normalized-context-window-input-schema))
- `tools?: list` - Optional list of tool definitions with the structure:
  ```
  [
    {
      name: string,
      description: string,
      inputSchema: {
        type: "object",
        properties: record,
        required: list<string>
      }
    }
  ]
  ```

**Output:**

- Provider-specific request data structure ready for API call

### `call`

Makes an API call to the provider to generate a response.

**Input:**

- `key: string` - API key for provider authentication
- `model: string` - Model identifier to use
- Prepared request data from `prepare-request`

**Output:**

- Raw response events in the provider's native format

### `response_stream_aggregate`

Aggregates streaming response events into a final response.

**Input:**

- Stream of provider-specific events

**Output:**

- Complete response record with normalized structure:
  ```
  {
    role: "assistant",
    mime_type: "application/json",
    message: {
      id: string,
      content: [
        {type: "text", text: string} |
        {type: "tool_use", name: string, input: record}
      ],
      model: string,
      stop_reason: "end_turn" | "tool_use" | string,
      usage?: {
        input_tokens: int,
        output_tokens: int
      }
    }
  }
  ```

### `response_stream_streamer`

Transforms provider events into a normalized streaming format for real-time display.

**Input:**

- Single provider-specific event

**Output:**

- Normalized event format (or null for events that should be ignored):
  ```
  {
    type: string,      # Content type identifier ("text" or "tool_use")
    name?: string,     # Tool name (for tool_use blocks only)
    content?: string   # Content to append to current block
  }
  ```

## Implementation Flow

1. `prepare-request` formats messages and tools into provider-specific format
2. `call` sends the prepared request to the provider API
3. `response_stream_streamer` transforms individual events for display
4. `response_stream_aggregate` collects all events into final response

Providers should handle any provider-specific formatting, authentication requirements, and event
normalization within these closures.

## Message Format Reference

Providers must handle the normalized message format defined in the
[Schema Reference](./schemas.md#content-block-types). Each provider implementation must properly
transform these standardized formats to and from the provider's specific API requirements.

Refer to the schema documentation for complete details on:

- Text blocks
- Document blocks (PDFs, images, text files)
- Tool use blocks
- Tool result blocks
- Cache control options

## Integration Checklist

This guide follows a test-driven approach, implementing features incrementally.

### 1. Create Provider Skeleton

Create `gpt/providers/{name}/mod.nu` with basic structure:

```nushell
export def provider [] {
  {
    models: {|key: string|
      # TODO: Implement model listing
      []
    }

    prepare-request: {|ctx: record tools?: list<record>|
      # TODO: Transform context to provider format
      {}
    }

    call: {|key: string model: string|
      # TODO: Make API call and stream events
      []
    }

    response_stream_streamer: {|event|
      # TODO: Transform event for display
      null
    }

    response_stream_aggregate: {||
      # TODO: Collect events into final response
      {}
    }
  }
}
```

### 2. Wire Up Provider Early

Complete integration steps now so you can test as you develop:

**Export in `gpt/providers/mod.nu`:**

```nushell
use ./newprovider

export def all [] {
  {
    anthropic: (anthropic provider)
    gemini: (gemini provider)
    newprovider: (newprovider provider)
  }
}
```

**Load in `gpt/mod.nu` init:**

```nushell
cat ($base | path join "providers/newprovider/mod.nu") | .append gpt.provider.newprovider.nu
```

**Register in `gpt/xs/command-call.nu` (two places):**

```nushell
# Add VFS use at top of run closure:
use xs/gpt/provider/newprovider

# Add to provider match:
let p = match $ptr.provider {
  "newprovider" => (newprovider provider)
  ...
}
```

### 3. Implement prepare-request Incrementally

Work through test cases one at a time, implementing each feature:

**a) Basic text (system-message):**

```bash
# Create expected output
echo '{...}' > tests/fixtures/providers/prepare-request/system-message/expected-newprovider.json

# Implement text handling in prepare-request

# Verify
nu tests/providers/prepare-request.nu newprovider system-message
```

**b) Tools (tool-use):**

```bash
# Add fixture
echo '{...}' > tests/fixtures/providers/prepare-request/tool-use/expected-newprovider.json

# Implement tool transformation

# Verify
nu tests/providers/prepare-request.nu newprovider tool-use
```

**c) Documents (document-image, document-pdf):**

```bash
# Add fixtures for each supported type
echo '{...}' > tests/fixtures/providers/prepare-request/document-image/expected-newprovider.json
echo '{...}' > tests/fixtures/providers/prepare-request/document-pdf/expected-newprovider.json

# Or mark as unsupported
echo 'Provider does not support images' > tests/fixtures/providers/prepare-request/document-image/expected-newprovider.err

# Implement document handling

# Verify each
nu tests/providers/prepare-request.nu newprovider document-image
nu tests/providers/prepare-request.nu newprovider document-pdf
```

**d) Advanced features (cache-control, tool-conversation):**

```bash
# Continue pattern for remaining cases
nu tests/providers/prepare-request.nu newprovider cache-control
nu tests/providers/prepare-request.nu newprovider tool-conversation
```

**Verify all prepare-request tests:**

```bash
nu tests/providers/prepare-request.nu newprovider
```

### 4. Implement Streaming Methods

**a) Capture real responses:**

```bash
export NEWPROVIDER_API_KEY="..."

# Capture for each supported case
nu tests/providers/prepare-request.nu newprovider system-message --call $env.NEWPROVIDER_API_KEY --capture
nu tests/providers/prepare-request.nu newprovider tool-use --call $env.NEWPROVIDER_API_KEY --capture
```

**b) Implement response_stream_streamer:** Study captured events and transform for display (returns
type/name/content or null)

**c) Implement response_stream_aggregate:** Collect all events into final normalized message
structure

**d) Generate expected outputs:**

```bash
nu tests/utils/generate-expected-outputs.nu newprovider system-message
nu tests/utils/generate-expected-outputs.nu newprovider tool-use
```

**e) Verify streaming:**

```bash
nu tests/providers/response-stream.nu newprovider
```

### 5. Add Integration Tests

Add provider to `tests/integration/integration.nu`:

```nushell
"call.newprovider.basics": {||
  gpt init
  sleep 50ms

  cat .env/newprovider | gpt provider enable newprovider
  gpt provider set-ptr milli newprovider model-name
  sleep 50ms

  let turn = "2+2=? reply with only the number" | gpt schema add-turn {provider_ptr: "milli"}
  let response = gpt call $turn.id

  let res = .cas $response.hash | from json
  assert equal $res.0.text "4"
}

"call.newprovider.tool_use": {||
  # Similar to anthropic/gemini/openai tool_use tests
}
```

**Verify:**

```bash
nu tests/integration/integration.nu call.newprovider
```

### 6. Update Documentation

Add to `docs/how-to/configure-providers.md`:

```markdown
| Feature            | Anthropic | Gemini | OpenAI | NewProvider |
| ------------------ | --------- | ------ | ------ | ----------- |
| Text conversations | yes       | yes    | yes    | yes         |
| PDF analysis       | yes       | yes    | yes    | yes/no      |
```

### 7. Final Verification

```bash
nu tests/run.nu providers
nu tests/run.nu integration
```

All tests should pass before submitting PR.
