# Configuring Providers

Use `gpt provider enable` to store an API key for a provider. Once enabled, create friendly pointers (aliases) with `gpt provider ptr <name> --set`.

## Alias Scheme

Aliases reflect the relative size of the model:

```
nano  < milli  < kilo  < giga
```

Add `.r` to point at a reasoning‑optimized variant.

Example configuration:

```json
{
  "nano": {
    "openai": "gpt-4.1-nano",
    "anthropic": "n/a",
    "gemini": "n/a"
  },
  "milli": {
    "openai": "gpt-4.1-mini",
    "anthropic": "claude-3-5-haiku-20241022",
    "gemini": "gemini-2.5-flash-preview-04-17-thinking"
  },
  "kilo": {
    "openai": "gpt-4.1",
    "anthropic": "claude-3-7-sonnet-20250219",
    "gemini": "n/a"
  },
  "milli.r": {
    "openai": "o4-mini",
    "anthropic": "n/a",
    "gemini": "gemini-2.5-flash-preview-04-17-thinking"
  },
  "kilo.r": {
    "openai": "o3",
    "anthropic": "n/a",
    "gemini": "gemini-2.5-pro-preview-05-06"
  },
  "giga": {
    "openai": "gpt-4.5-preview",
    "anthropic": "n/a",
    "gemini": "n/a"
  }
}
```
