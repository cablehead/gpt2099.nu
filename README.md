# gpt2099.nu [![Discord](https://img.shields.io/discord/1182364431435436042?logo=discord)](https://discord.com/invite/YNbScHBHrh)

A [Nushell](https://www.nushell.sh) scriptable [MCP client](https://modelcontextprotocol.io/sdk/java/mcp-client#model-context-protocol-client) with editable context threads stored in [cross.stream](https://github.com/cablehead/xs)

<img
  src="https://github.com/user-attachments/assets/1b2a9834-dcbf-4f5a-85aa-32109a68397b"
  height="300"
/>

<img height="300" alt="image" src="https://github.com/user-attachments/assets/19b52dfe-53c3-449d-8b62-aa1b434f901b" />


## Features

* **Consistent API Across Models:** Connect to Gemini + Search and Anthropic + Search through a single, simple interface. ([Add providers easily.](./provider-api.md))
* **Persistent, Editable Conversations:** Conversations are saved across sessions. Review, edit, and control your own context window — no black-box history.
* **Flexible Tool Integration:** Connect to MCP servers to extend functionality. `gpt2099.nu` already rivals [Claude Code](https://docs.anthropic.com/en/docs/claude-code/overview) for local file editing, but with full provider independence and deeper flexibility.

Built on [cross.stream](https://github.com/cablehead/xs) for event-driven processing, `gpt2099.nu` brings modern AI directly into your Nushell workflow — fully scriptable, fully inspectable, all in the terminal.

## Getting started

### Step 1.

First, install and configure [`cross.stream`](https://github.com/cablehead/xs). This may take a little effort to get right, but once it’s set up, you’ll have the full [`cross.stream`](https://github.com/cablehead/xs) ecosystem of tools for editing and working with your context windows.

- https://cablehead.github.io/xs/getting-started/installation/

After this step you should be able to run:

```nushell
"as easy as" | .append abc123
.head abc123 | .cas
```

<img height="200" alt="image" src="https://github.com/user-attachments/assets/dcff4ecf-e708-42fc-8cac-573375003320" />

### Step 2.

It really is easy from here.

```nushell
overlay use -pr ./gpt
```

### Step 3.

Enable your preferred provider. This stores the API key for later use:

```nushell
gpt provider enable
```

### Step 4.

Set up a `milli` alias for a lightweight model (try OpenAI's `gpt-4.1-mini` or Anthropic's `claude-3-5-haiku-20241022`):

```nushell
gpt provider ptr milli --set
```

### Step 5.

Give it a spin:

```nushell
"hola" | gpt -p milli
```
The default alias scheme ranks models by relative weight: `nano` < `milli` < `kilo` < `giga`. Reasoning-optimized variants use `.r`. See [docs/configure-providers.md](docs/configure-providers.md) for details.
For more commands see [docs/commands.md](docs/commands.md).


## Conversation Turn Schema (`gpt.turn`)

Each turn in a thread is stored as a `gpt.turn` frame, with these top-level
attributes in its `meta` record:

```
role
: speaker for this turn ("user", "assistant", "system")

inherited  (currently named "options")
: attributes auto-inherited down the thread (deep-merged at each turn)
    servers
    : list of MCP server names to use
    search
    : enable LLM-side search
    tool_mode
    : provider-specific tool mode
    provider_ptr (required)
    : the provider ptr to use for this turn, ("nano", "milli", "mega")

head
: thread bookmark; must be explicitly carried forward if continuity is needed

continues
: id or list of ids, links to previous turn(s) for context

cache
: ephemeral cache flag for this turn

content_type
: MIME type for content (e.g., "application/json")
```

> **Note:** We plan to rename `"options"` to `"inherited"` to clarify its behavior.

## FAQ

- Why does the name include 2099? What else would you call the future?

## Original intro

This is how the project looked, 4 hours into its inception:

https://github.com/user-attachments/assets/768cc655-a892-47cc-bf64-8b5f61c41f35
