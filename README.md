## Usage

First install and configure cross.stream:
https://cablehead.github.io/xs/getting-started/installation/

```nushell
use gpt
```

### gpt thread

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

## Features

- Spawn an MCP server as a cross.stream
  [generator](https://cablehead.github.io/xs/reference/generators/)
- List available tools on the server.

### Spawn an MCP Server

Register your MCP server:

```nushell
# gpt mcp register <name> <command>
gpt mcp register filesystem 'npx -y "@modelcontextprotocol/server-filesystem" "/project/path"'
```

### List Available Tools

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
