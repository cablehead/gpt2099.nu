# Command Reference

Terse reference for all gpt2099 commands. See the [how-to guides](./how-to/) for detailed
workflows.

## `gpt`

Send a request to the selected provider.

```
gpt [OPTIONS]
```

**Options:**

- `--continues (-c) <headish>` – Continue from a previous turn
- `--respond (-r)` – Continue from the last turn automatically
- `--servers <list>` – MCP servers to use
- `--search` – Enable provider search capabilities
- `--bookmark (-b) <name>` – Bookmark this turn for later reference
- `--provider-ptr (-p) <alias>` – Pointer to the provider/model
- `--json (-j)` – Treat input as JSON
- `--cache` – Enable caching for this conversation turn

**Example:**

```nushell
"Hello world" | gpt -p milli
```

See: [How to manage conversations](./how-to/manage-conversations.md)

## `gpt context`

Inspect conversation threads.

**Commands:**

```nushell
gpt context list [HEADISH]    # Raw per-turn view
gpt context resolve [HEADISH] # Resolved context with merged options
```

**Example:**

```nushell
gpt context list my-bookmark
```

See: [How to manage conversations](./how-to/manage-conversations.md)

## `gpt provider`

Manage provider configuration.

**Commands:**

```nushell
gpt provider enable [PROVIDER]    # Store an API key
gpt provider ptr [NAME] [--set]   # Manage model pointers
gpt provider models <PROVIDER>    # List available models
```

**Examples:**

```nushell
gpt provider enable
gpt provider ptr milli --set
gpt provider models anthropic
```

See: [How to configure providers](./how-to/configure-providers.md)

## `gpt document`

Register documents for use in conversations.

```
gpt document <PATH> [OPTIONS]
```

**Options:**

- `--name (-n) <string>` – Custom name for the document
- `--cache` – Enable caching for this document
- `--bookmark (-b) <string>` – Bookmark this document registration

**Example:**

```nushell
gpt document ~/report.pdf --name "Q4 Report" --cache --bookmark "quarterly"
```

See: [How to work with documents](./how-to/work-with-documents.md)

## `gpt prep`

Helpers for building context.

**Commands:**

```nushell
gpt prep gr [FILES...] [OPTIONS]  # Generate XML describing repository files
```

**Options:**

- `--with-content <closure>` – Custom content fetcher closure
- `--instructions <string>` – Add instructions to the context

**Example:**

```nushell
git ls-files ./src | lines | gpt prep gr
```

See: [How to generate code context](./how-to/generate-code-context.md)

## `gpt mcp`

Interact with Model Context Protocol servers.

**Commands:**

```nushell
gpt mcp register <NAME> <COMMAND>    # Spawn a server as generator
gpt mcp tool list <NAME>             # List available tools
gpt mcp tool call <NAME> <METHOD> <ARGS>  # Invoke a tool directly
gpt mcp list                         # List active servers
```

**Example:**

```nushell
gpt mcp register filesystem "npx -y @modelcontextprotocol/server-filesystem /workspace"
gpt mcp tool list filesystem
```

See: [How to use MCP servers](./how-to/use-mcp-servers.md)
