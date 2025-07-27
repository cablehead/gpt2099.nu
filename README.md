<img
  src="https://github.com/user-attachments/assets/1b2a9834-dcbf-4f5a-85aa-32109a68397b"
  height="400"
/>

# gpt2099.nu [![Discord](https://img.shields.io/discord/1182364431435436042?logo=discord)](https://discord.com/invite/YNbScHBHrh)

A [Nushell](https://www.nushell.sh) scriptable [MCP client](https://modelcontextprotocol.io/sdk/java/mcp-client#model-context-protocol-client) with [editable context threads](https://cablehead.github.io/xs/tutorials/threaded-conversations/) stored in [cross.stream](https://cablehead.github.io/xs/)

<img width="660" alt="image" src="https://github.com/user-attachments/assets/2b8d8744-076c-40e1-ac2c-1b1864ca2b80" />

## Features

* **Consistent API Across Models:** Connect to Gemini + Search and Anthropic + Search through a single, simple interface. ([Add providers easily.](docs/reference/provider-api.md))
* **Persistent, Editable Conversations:** [Conversation threads](https://cablehead.github.io/xs/tutorials/threaded-conversations/) are saved across sessions. Review, edit, and control your own context window — no black-box history.
* **Flexible Tool Integration:** Connect to MCP servers to extend functionality. `gpt2099.nu` already rivals [Claude Code](https://docs.anthropic.com/en/docs/claude-code/overview) for local file editing, but with full provider independence and deeper flexibility.
* **Document Support:** Upload and reference documents (PDFs, images, text files) directly in conversations with automatic content-type detection and caching.

Built on [cross.stream](https://github.com/cablehead/xs) for event-driven processing, `gpt2099.nu` brings modern AI directly into your Nushell workflow — fully scriptable, fully inspectable, all in the terminal.

https://github.com/user-attachments/assets/1254aaa1-2ca2-46b5-96e8-b5e466c735bd

<small><i>"lady on the track" provided by [mobygratis](https://mobygratis.com)</i><small>

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

## Documentation

- **[Commands Reference](docs/commands.md)** - Complete command syntax and options
- **[How-To Guides](docs/how-to/)** - Task-oriented workflows:
  - [Configure Providers](docs/how-to/configure-providers.md) - Set up AI providers and model aliases
  - [Work with Documents](docs/how-to/work-with-documents.md) - Register and use documents in conversations
  - [Manage Conversations](docs/how-to/manage-conversations.md) - Threading, bookmarking, and continuation
  - [Use MCP Servers](docs/how-to/use-mcp-servers.md) - Extend functionality with external tools
  - [Generate Code Context](docs/how-to/generate-code-context.md) - Create structured context from Git repositories


## Reference Documentation

- **[Provider API](docs/reference/provider-api.md)** - Technical specification for implementing providers
- **[Schemas](docs/reference/schemas.md)** - Complete data structure reference for all gpt2099.nu schemas

## FAQ

- Why does the name include 2099? What else would you call the future?

## Original intro

This is how the project looked, 4 hours into its inception:

https://github.com/user-attachments/assets/768cc655-a892-47cc-bf64-8b5f61c41f35
