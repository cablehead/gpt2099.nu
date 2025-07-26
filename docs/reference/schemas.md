# Schema Reference

This document defines the data structures used throughout gpt2099.nu.

## Conversation Turn Schema (`gpt.turn`)

Each turn in a thread is stored as a `gpt.turn` frame, with these top-level attributes in its `meta` record:

### Required Fields

**`role`**
: Speaker for this turn
: Values: `"user"`, `"assistant"`, `"system"`
: Default: `"user"`

### Optional Fields

**`inherited` (currently named `"options"`)**
: Attributes auto-inherited down the thread (deep-merged at each turn)
: Type: `record`
: Contains:
  - `servers: list<string>` - List of MCP server names to use
  - `search: bool` - Enable LLM-side search
  - `tool_mode: string` - Provider-specific tool mode  
  - `provider_ptr: string` (required) - The provider ptr to use for this turn (`"nano"`, `"milli"`, `"mega"`)

**`head`**
: Thread bookmark name
: Type: `string`
: Must be explicitly carried forward if continuity is needed

**`continues`**
: Links to previous turn(s) for context
: Type: `string | list<string>`
: Values: Turn ID(s) or bookmark name(s)

**`cache`**
: Ephemeral cache flag for this turn
: Type: `bool`
: Default: `false`

### Document-Specific Fields

**`content_type`**
: MIME type for content
: Type: `string`
: Examples: `"application/json"`, `"text/markdown"`, `"application/pdf"`

**`type`**
: Content type indicator
: Type: `string`
: Values: `"document"` for uploaded files

**`document_name`**
: Display name for documents
: Type: `string`
: Default: filename

**`original_path`**
: Full path to the original document file
: Type: `string`

**`file_size`**
: Size of the document in bytes
: Type: `int`

**`cache_control`**
: Caching directive
: Type: `string`
: Values: `"ephemeral"` for documents

## Thread Record Schema

Internal representation used by the context system:

```nushell
{
  id: string                            # Unique turn ID (SCRU128)
  role: "user" | "assistant" | "system" # Speaker role, default "user"
  content: list<record>                 # Content blocks
  options: record                       # Delta options for this turn
  cache: bool                          # Ephemeral cache flag for this turn
}
```

### Content Block Types

**Text Block:**
```nushell
{
  type: "text"
  text: string
  cache_control?: {type: "ephemeral"}  # Optional caching
}
```

**Tool Use Block:**
```nushell
{
  type: "tool_use"
  id?: string        # Tool use identifier
  name: string       # Tool name
  input: record      # Tool arguments
}
```

**Tool Result Block:**
```nushell
{
  type: "tool_result"
  name: string              # Tool name
  content: list<record>     # Result content
  tool_use_id?: string     # Reference to tool use
  is_error?: bool          # Error flag
}
```

**Document Block:**
```nushell
{
  type: "document"
  source: {
    type: "base64"
    media_type: string     # MIME type
    data: string          # Base64-encoded content
  }
  cache_control?: {type: "ephemeral"}
}
```

## Context Window Schema

Full resolved context returned by `gpt context resolve`:

```nushell
{
  messages: list<record>    # Chronological list of thread records
  options: record          # Merged options across all turns
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
A reference to a conversation turn, can be:
- **Turn ID**: Direct SCRU128 identifier
- **Bookmark**: Named reference (e.g., `"research-session"`)

### Bookmarks
- Human-readable thread names
- Must be unique within the conversation history
- Automatically inherited by subsequent turns in the thread

## Provider-Specific Schemas

### Request Format
See [Provider API Specification](./provider-api.md) for details on provider-specific request and response formats.

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

> **Note:** The field currently named `"options"` in stored frames will be renamed to `"inherited"` to better reflect its behavior of being automatically propagated down conversation threads.