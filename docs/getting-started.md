# Getting Started

This guide walks you through installing and setting up gpt2099 for the first time.

## Prerequisites

gpt2099 is built on [cross.stream](https://github.com/cablehead/xs) and requires it to be installed
and configured first.

## Step 1: Install cross.stream

First, install and configure [`cross.stream`](https://github.com/cablehead/xs). Once set up, you'll
have the full [`cross.stream`](https://github.com/cablehead/xs) ecosystem of tools for editing and
working with your context windows.

- https://cablehead.github.io/xs/getting-started/installation/

After this step you should be able to run:

```nushell
"as easy as" | .append abc123
.head abc123 | .cas
```

<img height="200" alt="image" src="https://github.com/user-attachments/assets/dcff4ecf-e708-42fc-8cac-573375003320" />

## Step 2: Load the gpt2099 module

It really is easy from here.

```nushell
overlay use -pr ./gpt
```

## Step 3: Configure a provider

Enable your preferred provider. This stores the API key for later use:

```nushell
gpt provider enable
```

For detailed provider configuration, see [Configure Providers](how-to/configure-providers.md).

## Step 4: Set up a model alias

Set up a `milli` alias for a lightweight model (try OpenAI's `gpt-4.1-mini` or Anthropic's
`claude-3-5-haiku-20241022`):

```nushell
gpt provider ptr milli --set
```

## Step 5: Test your setup

Give it a spin:

```nushell
"hola" | gpt -p milli
```

## Next Steps

Now that you have gpt2099 running:

- Learn more about [configuring providers](how-to/configure-providers.md)
- Explore [working with documents](how-to/work-with-documents.md)
- Understand [conversation management](how-to/manage-conversations.md)
- Set up [MCP servers](how-to/use-mcp-servers.md) for extended functionality
