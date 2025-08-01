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
