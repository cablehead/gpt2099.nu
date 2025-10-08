# Version Management

This guide explains how to manage version information in gpt2099.

## Current Version

You can check the current version using:

```nushell
gpt version
```

## Version Storage

The version is stored in two locations that must be kept in sync:

### 1. MCP Client Info (`gpt/mcp-rpc.nu`)

The version is declared in the MCP JSON-RPC module within the `initialize` function's `clientInfo`
structure:

```nushell
clientInfo: {
  name: "gpt2099"
  version: "0.6"  # <-- Update this
}
```

This version is sent to MCP servers during initialization to identify the gpt2099 client.

### 2. Version Command (`gpt/mod.nu`)

The version command returns the current version:

```nushell
export def version [] {
  "0.6"  # <-- Update this to match mcp-rpc.nu
}
```

## Updating the Version

To increment the version (e.g., from 0.6 to 0.7):

1. **Update MCP client info**:

   ```bash
   # Edit gpt/mcp-rpc.nu - find the clientInfo.version field
   version: "0.7"
   ```

2. **Update version command**:

   ```bash
   # Edit gpt/mod.nu - find the version command export
   export def version [] {
     "0.7"
   }
   ```

3. **Verify the update**:
   ```nushell
   gpt version
   ```

## Version Consistency

Both locations must always have the same version string to maintain consistency across:

- MCP server communication
- User-facing version reporting
- Development and debugging

## Semantic Versioning

gpt2099 follows a simplified semantic versioning scheme:

- **0.x** - Development versions with breaking changes expected
- Future versions may adopt full semantic versioning (MAJOR.MINOR.PATCH)
