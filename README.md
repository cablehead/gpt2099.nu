# gpt2099.nu [![Discord](https://img.shields.io/discord/1182364431435436042?logo=discord)](https://discord.com/invite/YNbScHBHrh)

A [Nushell](https://www.nushell.sh) scriptable [MCP client](https://modelcontextprotocol.io/sdk/java/mcp-client#model-context-protocol-client) with editable context threads stored in [cross.stream](https://github.com/cablehead/xs)

<img
  src="https://github.com/user-attachments/assets/1b2a9834-dcbf-4f5a-85aa-32109a68397b"
  width="600"
/>

## Features

* **Consistent API Across Models:** Connect to Gemini + Search and Anthropic + Search through a single, simple interface. ([Add providers easily.](./provider-api.md))
* **Persistent, Editable Conversations:** Conversations are saved across sessions. Review, edit, and control your own context window — no black-box history.
* **Flexible Tool Integration:** Connect to MCP servers to extend functionality. `gpt2099.nu` already rivals [Claude Code](https://docs.anthropic.com/en/docs/claude-code/overview) for local file editing, but with full provider independence and deeper flexibility.

Built on [cross.stream](https://github.com/cablehead/xs) for event-driven processing, `gpt2099.nu` brings modern AI directly into your Nushell workflow — fully scriptable, fully inspectable, all in the terminal.

## Usage

First install and configure cross.stream:
https://cablehead.github.io/xs/getting-started/installation/

```nushell
overlay use -pr ./gpt
```

### gpt init

Installs the required dependencies into your cross.stream store, and prompts you
to select an LLM provider, an API key, and a model.

### gpt

Makes a request to the LLM provider.

### gpt thread

Review the current conversation thread.

### gpt mcp

[Model Context Protocol](https://modelcontextprotocol.io/introduction) (MCP)
servers are really just CLI tools that read from stdin and write to stdout.

[cross.stream](https://github.com/cablehead/xs)
[generators](https://cablehead.github.io/xs/reference/generators/) spawn CLI
tools and package each line of output into event frames (.recv) while routing
frames ending in .send as input, turning them into services you can
interactively poke at.

`gpt mcp` leverages this approach to provide a hands-on environment for
experimenting with and understanding MCP servers.

#### Features

- Spawn an MCP server as a cross.stream
  [generator](https://cablehead.github.io/xs/reference/generators/)
- List available tools on the server.

#### Spawn an MCP Server

Register your MCP server:

```nushell
# gpt mcp register <name> <command>
gpt mcp register filesystem 'npx -y "@modelcontextprotocol/server-filesystem" "/project/path"'
```

#### List Available Tools

List the tools provided by the MCP server:

```nushell
gpt mcp tools list filesystem
```

```
──#──┬───────────name────────────┬─────────────────────────────────────────────────────────────────────────description─────────────────────────────────────────────────────────────────────────┬─...─
 0   │ read_file                 │ Read the complete contents of a file from the file system. Handles various text encodings and provides detailed error messages if the file cannot be read.  │ ...
     │                           │ Use this tool when you need to examine the contents of a single file. Only works within allowed directories.                                                │
 1   │ read_multiple_files       │ Read the contents of multiple files simultaneously. This is more efficient than reading files one by one when you need to analyze or compare multiple files │ ...
     │                           │ . Each file's content is returned with its path as a reference. Failed reads for individual files won't stop the entire operation. Only works within allowe │
     │                           │ d directories.
 ...
```
