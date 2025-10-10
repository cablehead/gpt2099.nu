# How to Configure Providers

This guide walks you through setting up AI providers and creating model aliases for easy access.

## Overview

gpt2099 uses a two-step provider setup:

1. **Enable providers** - Store API keys for authentication
2. **Create aliases** - Set up friendly names pointing to specific models

## Step-by-Step Setup

### 1. Enable a Provider

Store your API key and verify connectivity:

```nushell
gpt provider enable
```

This will:

- Prompt you to select from available providers
- Ask for your API key
- Test the connection by querying available models
- Store the key for future use

### 2. Create Model Aliases

Set up friendly aliases pointing to specific models:

```nushell
gpt provider ptr milli --set
```

This will:

- Show your enabled providers
- Let you select a provider and model
- Create an alias you can use with `-p milli`

## Alias Scheme

Aliases reflect relative model capabilities:

```
nano  < milli  < kilo  < giga
```

Add `.r` for reasoning-optimized variants:

- `milli.r` - reasoning-optimized lightweight model
- `kilo.r` - reasoning-optimized full-capability model

## Provider Capabilities

| Feature                 | Anthropic | Cerebras | Cohere | Gemini     | OpenAI     |
| ----------------------- | --------- | -------- | ------ | ---------- | ---------- |
| Text conversations      | yes       | yes      | yes    | yes        | yes        |
| PDF analysis            | yes       | no       | no     | yes        | yes        |
| Image analysis          | yes       | no       | yes*   | yes        | yes        |
| Web search              | yes       | no       | no     | yes        | no         |
| MCP tools               | yes       | yes      | yes    | yes        | yes        |
| Tools + search together | yes       | no       | no     | no         | no         |
| Document caching        | yes       | no       | no     | yes (auto) | yes        |

**Key limitations:**

- **Cerebras**: No vision/PDF support; JSON schema fields (`format`, `minimum`, `nullable`, `$schema`) recursively stripped from tools
- **Cohere**: Vision and tools mutually exclusive (vision models support images but not tools; other models support tools but not images); no PDF support; no built-in web search
- **Gemini**: Cannot use custom MCP tools and web search in the same conversation
- **OpenAI**: No built-in web search support

## Example Configuration

After setup, your aliases might look like:

```json
{
  "milli": {
    "provider": "anthropic",
    "model": "claude-3-5-haiku-20241022"
  },
  "kilo": {
    "provider": "openai",
    "model": "gpt-4.1"
  },
  "milli.r": {
    "provider": "openai",
    "model": "o4-mini"
  }
}
```

## Usage

Once configured, use aliases in your prompts:

```nushell
"Hello world" | gpt -p milli
"Complex analysis task" | gpt -p kilo
"Step-by-step reasoning" | gpt -p milli.r
```

## Managing Providers

See the [commands reference](../commands.md#gpt-provider) for the complete list of provider
management commands, including:

- `gpt provider models` - List available models
- `gpt provider ptr` - View current aliases
- `gpt provider enable` - Add more providers
