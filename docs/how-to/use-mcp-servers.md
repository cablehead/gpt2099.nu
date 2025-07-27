# How to Use MCP Servers

This guide shows you how to set up and interact with Model Context Protocol (MCP) servers to extend gpt2099's capabilities.

## Overview

MCP servers are external tools that provide additional capabilities like file editing, web search, or database access. gpt2099 integrates with these servers through the `cross.stream` generator pattern, allowing you to experiment with and understand server capabilities before using them in conversations.

## Setting Up MCP Servers

### 1. Register an MCP Server

```nushell
gpt mcp register filesystem "npx -y @modelcontextprotocol/server-filesystem /path/to/allowed/directory"
```

This spawns the server as a cross.stream generator, making its tools available for use.

### 2. Discover Available Tools

```nushell
gpt mcp tool list filesystem
```

This shows you what tools the server provides:

```text
──#──┬───────────name────────────┬─────────────────────────────────────
 0   │ read_file                 │ Read the contents of a file
 1   │ read_multiple_files       │ Read multiple files at once
 2   │ write_file                │ Write content to a file
 3   │ create_directory          │ Create a new directory
 ...
```

### 3. Test Tools Directly

Before using tools in conversations, test them manually:

```nushell
gpt mcp tool call filesystem read_file {path: "/path/to/file.txt"}
```

This helps you understand the tool's input format and expected output.

## Using MCP Servers in Conversations

### Basic Usage

Once registered, specify servers when making requests:

```nushell
"Read the contents of config.json and explain its structure" | gpt --servers [filesystem] -p milli
```

The LLM will automatically use the appropriate tools from the filesystem server.

### Multiple Servers

You can use multiple servers simultaneously:

```nushell
gpt mcp register web-search "npx -y @modelcontextprotocol/server-brave-search"

"Research current best practices and update our README.md file" | gpt --servers [web-search, filesystem] -p kilo
```

### Interactive Tool Execution

When the LLM wants to use a tool, you'll see:
1. The proposed tool call with its arguments
2. A prompt asking if you want to execute it
3. Options to execute, provide alternative input, or skip

```text
┌─────────────┬──────────────────────────────────────────────────────────┐
│ name        │ filesystem___write_file                                  │
│ input       │ {path: "config.json", content: "{\n  \"updated\": true}"}│
└─────────────┴──────────────────────────────────────────────────────────┘

Execute? 
> yes
  no: do something different  
  no
```

This gives you full control over what actions are taken on your system.

## Server Management

### List Active Servers

```nushell
gpt mcp list
```

Shows all currently running MCP servers.

### Server Lifecycle

Servers run as cross.stream generators and will:
- Automatically restart if they crash
- Be available across multiple conversations
- Terminate when the cross.stream session ends

## Common MCP Servers

Here are some useful MCP servers to try:

**File System Operations:**
```nushell
gpt mcp register filesystem "npx -y @modelcontextprotocol/server-filesystem /workspace"
```

**Web Search:**
```nushell
gpt mcp register brave-search "npx -y @modelcontextprotocol/server-brave-search"
```

**Git Operations:**
```nushell
gpt mcp register git "npx -y @modelcontextprotocol/server-git"
```

**Database Access:**
```nushell
gpt mcp register postgres "npx -y @modelcontextprotocol/server-postgres postgresql://user:pass@localhost/db"
```

## Experimentation Workflow

The recommended approach for working with new MCP servers:

1. **Register** the server
2. **List** available tools to understand capabilities
3. **Test** individual tools with `gpt mcp tool call`
4. **Use** in conversations with `--servers` flag
5. **Iterate** based on results

This hands-on experimentation helps you understand server capabilities and build effective prompts that leverage the available tools.

See the [commands reference](../commands.md#gpt-mcp) for complete MCP command options.