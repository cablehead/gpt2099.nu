# Command Reference

This page lists the major commands provided by the `gpt` overlay.

## Quick start

1. Configure a provider:
   ```nushell
   gpt provider enable
   ```
2. Create a model pointer:
   ```nushell
   gpt provider ptr milli --set
   ```
3. Send a prompt:
   ```nushell
   "hello" | gpt -p milli
   ```

## Commands

### `gpt`
Send a request to the selected provider.

```
gpt [OPTIONS]
```

Options:
- `--continues (-c) <headish>` – continue from a previous turn.
- `--respond (-r)` – continue from the last turn automatically.
- `--servers <list>` – MCP servers to use.
- `--search` – enable provider search capabilities.
- `--bookmark (-b) <name>` – bookmark this turn for later reference.
- `--provider-ptr (-p) <alias>` – pointer to the provider/model.
- `--json (-j)` – treat input as JSON.
- `--separator <str>` – join list input with this separator.

### `gpt context`
Inspect conversation threads.

```
gpt context list [HEADISH]
```
Raw per‑turn view.

```
gpt context resolve [HEADISH]
```
Resolved context with merged options.

### `gpt provider`
Manage provider configuration.

```
gpt provider enable [PROVIDER]
```
Store an API key.

```
gpt provider ptr [NAME] [--set]
```
With `--set` choose provider and model for the pointer; without it show the current mapping.

```
gpt provider models <PROVIDER>
```
List available models.

### `gpt prep`
Helpers for building context.

```
gpt prep gr [FILES...]
```
Generate XML describing repository files. Example:
```nushell
git ls-files ./gpt | lines | gpt prep gr | bat -l xml
```

### `gpt mcp`
Interact with [Model Context Protocol](https://modelcontextprotocol.io/introduction) servers.

MCP servers are typically simple CLI tools that read from `stdin` and write to
`stdout`. The `cross.stream`
[generator](https://cablehead.github.io/xs/reference/generators/) pattern wraps
these tools so each line of output is packaged into event frames while frames
ending in `.send` are routed back as input. `gpt mcp` leverages this pattern to
provide a hands‑on way to experiment with and understand MCP servers.

**Features**

- Spawn an MCP server as a cross.stream generator.
- List available tools on the server.

```
gpt mcp register <NAME> <COMMAND>
```
Spawn a server as a cross.stream generator.

```
gpt mcp tool list <NAME>
```
List available tools.

```text
──#──┬───────────name────────────┬─────────────────────────────────────
 0   │ read_file                 │ Read the contents of a file
 1   │ read_multiple_files       │ Read multiple files at once
 ...
```

```
gpt mcp tool call <NAME> <METHOD> <ARGS>
```
Invoke a tool directly.

