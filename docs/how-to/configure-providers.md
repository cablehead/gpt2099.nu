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

See the [commands reference](../commands.md#gpt-provider) for the complete list of provider management commands, including:
- `gpt provider models` - List available models
- `gpt provider ptr` - View current aliases
- `gpt provider enable` - Add more providers