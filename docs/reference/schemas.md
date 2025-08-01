# Schema Reference

This document is the authoritative reference for all data structures used throughout gpt2099.

## Core Concepts

### Headish

A key concept in gpt2099 is the **"headish"**, which is a reference (specifically, the ID) to a
particular turn within a conversation thread. This allows commands like `gpt main` to continue a
conversation from a specific point by specifying the `headish` using the `--continues` flag. The
conversation context is built by tracing backward from the specified 'headish' through the
`continues` links.

This mechanism enables:

- **Conversation continuation**: Resume any conversation from any specific turn
- **Branching conversations**: Start multiple conversation branches from the same point
- **Flexible context building**: Control exactly which turns are included in the context window
- **Thread navigation**: Move through conversation history in a structured way

See the [Identifiers](#identifiers) section below for the technical specification of headish
values.

## Normalized Context Window Input Schema

This is the primary schema that provider `prepare-request` functions receive:

```nushell
# Context Window Input
{
  messages: list<message_record>
  options: options_record
}

# Message Record
message_record = {
  role: "user" | "assistant" | "system"
  content: list<content_block>
}

# Options Record
options_record = {
  provider_ptr?: string           # Required for actual calls
  servers?: list<string>          # MCP server names
  search?: bool                   # Enable provider search
  tool_mode?: string              # Provider-specific tool mode
}
```

### Content Block Types

Content blocks are a union of these types:

#### Text Block

```nushell
{
  type: "text"
  text: string
}
```

#### Document Block

```nushell
{
  type: "document"
  source: {
    type: "base64"
    media_type: string              # MIME type
    data: string                    # Base64-encoded content
  }
}
```

#### Tool Use Block

```nushell
{
  type: "tool_use"
  id?: string                       # Tool use identifier
  name: string                      # Tool name
  input: record                     # Tool arguments
}
```

#### Tool Result Block

```nushell
{
  type: "tool_result"
  name: string                      # Tool name that was called
  content: list<record>             # Result content (usually text blocks)
  tool_use_id?: string             # Reference to originating tool_use
  is_error?: bool                  # Whether result represents an error
}
```

**Schema Notes:**

- `options.provider_ptr` is required for actual API calls but optional in stored contexts
- `tool_use.id` auto-generated if missing (Gemini requirement)
- `document_block.source.media_type` determines provider-specific handling

## Conversation Turn Schema (`gpt.turn`)

Each turn in a thread is stored as a `gpt.turn` frame, with these top-level attributes in its
`meta` record:

### Required Fields

**`role`** : Speaker for this turn : Values: `"user"`, `"assistant"`, `"system"` : Default:
`"user"`

### Optional Fields

**`inherited` (currently named `"options"`)** : Attributes auto-inherited down the thread
(deep-merged at each turn) : Type: `record` : Contains:

- `servers: list<string>` - List of MCP server names to use
- `search: bool` - Enable LLM-side search
- `tool_mode: string` - Provider-specific tool mode
- `provider_ptr: string` (required) - The provider ptr to use for this turn (`"nano"`, `"milli"`,
  `"mega"`)

**`head`** : Thread bookmark name : Type: `string` : Must be explicitly carried forward if
continuity is needed

**`continues`** : Links to previous turn(s) for context : Type: `string | list<string>` : Values:
Turn ID(s) or bookmark name(s)

**`cache`** : Cache flag for this turn : Type: `bool` : Default: `false` : Note: Provider-specific
implementation (e.g., Anthropic uses ephemeral caching)

### Document-Specific Fields

**`content_type`** : MIME type for content : Type: `string` : Examples: `"application/json"`,
`"text/markdown"`, `"application/pdf"`

**`type`** : Content type indicator : Type: `string` : Values: `"document"` for uploaded files

**`document_name`** : Display name for documents : Type: `string` : Default: filename

**`original_path`** : Full path to the original document file : Type: `string`

**`file_size`** : Size of the document in bytes : Type: `int`

**`cache`** : Cache flag for this turn : Type: `bool` : Default: `false`

## Thread Record Schema

Internal representation used by the context system (see `gpt/ctx.nu` for implementation):

```nushell
{
  id: string                            # Unique turn ID (SCRU128)
  role: "user" | "assistant" | "system" # Speaker role, default "user"
  content: list<content_block>          # Content blocks (same as normalized schema)
  options: record                       # Delta options for this turn
  cache: bool                          # Ephemeral cache flag for this turn
}
```

**Note**: Content blocks in thread records use the same format as the normalized schema above.

## Resolved Context Window Schema

Full resolved context returned by `gpt context resolve` (matches normalized input schema):

```nushell
{
  messages: list<message_record>    # Chronological list using normalized format
  options: options_record          # Merged options across all turns
}
```

### Options Inheritance

Options are deep-merged down the conversation thread:

1. **Base options** from earliest turn
2. **Delta options** from each subsequent turn
3. **Current turn options** (highest priority)

Example merged options:

```nushell
{
  provider_ptr: "kilo"
  servers: ["filesystem", "web-search"]
  search: true
  tool_mode: "auto"
}
```

## Identifiers

### Turn IDs

- Format: SCRU128 (25-character alphanumeric)
- Example: `"03DXL6W8Q53VJHS6I91Q9R7M3"`
- Globally unique, lexically sortable

### Headish

A reference to a conversation turn (see [Core Concepts](#headish) for detailed explanation). Can
be:

- **Turn ID**: Direct SCRU128 identifier
- **Bookmark**: Named reference (e.g., `"research-session"`)

### Bookmarks

- Human-readable thread names
- Must be unique within the conversation history
- Automatically inherited by subsequent turns in the thread

## Provider-Specific Schemas

### Request Format

See [Provider API Specification](./provider-api.md) for details on provider-specific request and
response formats.

### Response Format

Normalized response structure from providers:

```nushell
{
  message: {
    role: "assistant"
    content: list<record>        # Content blocks
    model: string               # Model identifier
    stop_reason: string         # Completion reason
    usage?: {                   # Token usage stats
      input_tokens: int
      output_tokens: int
      cache_creation_input_tokens?: int
      cache_read_input_tokens?: int
    }
  }
}
```

---

**Note:** The field currently named `"options"` in stored frames will be renamed to `"inherited"`
to better reflect its behavior of being automatically propagated down conversation threads.
