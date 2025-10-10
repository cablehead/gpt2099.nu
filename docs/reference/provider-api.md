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

To integrate a new provider into the system:

### 1. Create Provider Module

Create `gpt/providers/{name}/mod.nu` implementing all 5 required methods:

```nushell
export def provider [] {
  {
    models: {|key: string| ... }
    prepare-request: {|ctx: record tools?: list<record>| ... }
    call: {|key: string model: string| ... }
    response_stream_streamer: {|event| ... }
    response_stream_aggregate: {|| ... }
  }
}
```

### 2. Export Provider

Add to `gpt/providers/mod.nu`:

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

### 3. Load Module on Init

Add to `gpt/mod.nu` in the `init` function:

```nushell
cat ($base | path join "providers/newprovider/mod.nu") | .append gpt.mod.provider.newprovider
```

### 4. Register in Command Handler

Update `gpt/xs/command-call.nu` in two places:

**modules dict:**
```nushell
modules: {
  "anthropic": (.head gpt.mod.provider.anthropic | .cas $in.hash)
  "gemini": (.head gpt.mod.provider.gemini | .cas $in.hash)
  "newprovider": (.head gpt.mod.provider.newprovider | .cas $in.hash)
  "ctx": (.head gpt.mod.ctx | .cas $in.hash)
}
```

**match statement:**
```nushell
let p = match $ptr.provider {
  "anthropic" => (anthropic provider)
  "gemini" => (gemini provider)
  "newprovider" => (newprovider provider)
  _ => {
    error make {msg: $"Unsupported provider: ($ptr.provider)"}
  }
}
```

### 5. Create Test Fixtures

For each test case in `tests/fixtures/providers/prepare-request/`, create expected output:

```bash
# For supported features
echo '{...}' > tests/fixtures/providers/prepare-request/{case}/expected-newprovider.json

# For unsupported features
echo 'Error message' > tests/fixtures/providers/prepare-request/{case}/expected-newprovider.err
```

Run tests to verify transformations:

```bash
nu tests/providers/prepare-request.nu newprovider
```

### 6. Capture Streaming Fixtures

Capture real API responses and generate expected outputs:

```bash
# Get API key
export NEWPROVIDER_API_KEY="..."

# Capture all test cases
for case in cache-control document-image document-pdf system-message tool-conversation tool-use tool-with-outputschema; do
  nu tests/providers/prepare-request.nu newprovider $case --call $env.NEWPROVIDER_API_KEY --capture
  nu tests/utils/generate-expected-outputs.nu newprovider $case
done

# Verify streaming tests pass
nu tests/providers/response-stream.nu newprovider
```

### 7. Update Documentation

Add provider to capability table in `docs/how-to/configure-providers.md`:

```markdown
| Feature                 | Anthropic | Gemini | NewProvider |
| ----------------------- | --------- | ------ | ----------- |
| Text conversations      | yes       | yes    | yes         |
| PDF analysis            | yes       | yes    | yes/no      |
| ...                     | ...       | ...    | ...         |
```

### Verification

Run complete test suite:

```bash
nu tests/run.nu providers
```

All tests should pass before integration is complete
