## gpt2099 [![Discord](https://img.shields.io/discord/1182364431435436042?logo=discord)](https://discord.com/invite/YNbScHBHrh)

This [Nushell](https://www.nushell.sh) module builds on
[gpt.nu](https://github.com/cablehead/gpt.nu) to maintain conversation threads
in a [cross.stream](https://github.com/cablehead/xs) store.

## Prerequisites

- Install [Nushell](https://www.nushell.sh)
- Install
  [xs (cross-stream)](https://cablehead.github.io/xs/getting-started/installation/)
  and
  [orientate yourself](https://cablehead.github.io/xs/getting-started/first-stream/)

### Download the required modules

```nu
> [
  "https://raw.githubusercontent.com/cablehead/gpt.nu/main/gpt.nu"
  "https://raw.githubusercontent.com/cablehead/xs/main/xs.nu"
  "https://raw.githubusercontent.com/cablehead/gpt2099.nu/main/gpt2099.nu"
] | each {|url| http get $url | save ($url | path basename)}

> use ./gpt.nu
> use ./xs.nu *
> use ./gpt2099.nu
```

### Configure your LLM provider

See the [gpt.nu README](https://github.com/cablehead/gpt.nu) for more
configuration options.

```nu
> gpt select-provider
```

### Run a cross.stream store

Launch a local `xs` server. You can launch it anywhere. Just
remember where you put it. You will need to reference it later.

```bash
cd ~
xs serve ./store
```

## Getting Started

Here is an example:

```nu
"anthropomorphize" | gpt2099 new
To anthropomorphize is to attribute human characteristics, emotions, behaviors, or intentions to non-human entities, such as:

1. Animals
- "The dog felt guilty about chewing the shoe"
- "The cat plotted revenge"

2. Objects
- "The car refused to start today"
- "The computer is being stubborn"
...
```

To make things even easier, create an alias in your
[Nushell config](https://www.nushell.sh/book/configuration.html#quickstart):

```nu
alias llm = gpt2099 new
alias llm. = gpt2099 resume
```

How, you can quick ask:

```nu
"chuck steak" | llm # original question
"best cook method" | llm. # followup question
```

## Commands

The purpose of this section is to help you learn how to use gpt2099. Rather than
repeat what is already available in code, we are going to help you learn by
using.

To view all available commands, use Nushell's auto complete feature by typing in
gpt2099 and pressing tab. Here is an example:

```nu
~> gpt2099 <tab>
gpt2099 id-to-messages
gpt2099 new
gpt2099 prep
gpt2099 resume
gpt2099 system
```

To learn about any one subcommand, call the -h option for help.

```nu
~> gpt2099 new -h
Usage:
  > new

Flags:
  -h, --help: Display the help message for this command

Input/output types:
  ╭───┬───────┬────────╮
  │ # │ input │ output │
  ├───┼───────┼────────┤
  │ 0 │ any   │ any    │
  ╰───┴───────┴────────╯
```

If at any time you feel the help is incomplete, either post to the
[![Discord](https://img.shields.io/discord/1182364431435436042?logo=discord)](https://discord.com/invite/YNbScHBHrh)
or create a pull request. We welcome all feedback.

## Usage Modes

The purpose of this section is to help you better understand how to use gpt2099.

Here are the modes:

- Pipeline/script (no tty)
- Interactive (tty)

### Pipeline/Script

In previous examples, we demonstrated the following non-interactive command. The
below example could be part of a bigger pipeline or script.

```nu
"lets talk about cats" | gpt2099 new
```

### Interactive

One of the goals of the project is to demonstrate how you can create CLI tools
that are interactive using Nushell. Rather than simply have a command fail, we
would like to prompt the user for more information if and when possible.

Example interaction where the system prompts you if you did not supply one:

```nu
~> gpt2099 new
prompt: lets talk about cats
Absolutely, I'd love to talk about cats! Cats are fascinating creatures.
```

Example interaction where the system prompts you for an LLM API key if not
already set as part of the `select-provider` subcommand:

https://github.com/user-attachments/assets/dd99e920-480c-4d47-ba52-6c62217d1194

## xs (cross-stream) Details

The purpose of the section is to help you use your local `xs` instance
specifically in the context of gpt2099. We will use these details in the below
gpt2099 use cases.

To view a list of current conversations/events, use the `xs` command `.cat`:

```nu
.cat
```

To view the contents of any one conversation/event, use the `xs` command `.get`
to get the hash and the `xs` command `.cas` to print the message from the hash:

```nu
.get <id> | .cas
```

To print all messages up to an event id, use the `gpt2099` command
`id-to-messages`:

```nu
gpt2099 id-to-messages <id>
```

## Conversation Forking Use Case

The purpose of this section is to illustrate how easy it is to fork a
conversation using `xs` and `gpt2099`. Here is an example:

```nu
"start a conversation about something" | gpt2099 new
"continue the converation" | gpt2099 resume
"let's pretent the last result from the llm was not good" | gpt2099 resume
.cat # to see all messages
gpt2099 id-to-messages <id> # to confirm we get the id of the last known desired conversation
gpt2099 resume --id <id> # using any previous good id as the point to fork the conversation
```

Here is a visual to help demonstrate the use case:

```mermaid
flowchart TD
    A[Message ID 1: Start] -->|continues| B[Message ID 2]
    B -->|continues| C[Message ID 3]
    C -->|continues| D[Message ID 4]

    C -->|forks| E[Message ID 5: Detail Thread 1]
    E -->|continues| F[Message ID 6: Detail Thread 1]

    B -->|forks| G[Message ID 7: Detail Thread 2]
    G -->|continues| H[Message ID 8: Detail Thread 2]
    H -->|continues| I[Message ID 9: Detail Thread 2]
```

We feel it is important to note that forking a conversation is not easy to
reason about when you are writing an application. Creating a good user
experience with proper flexibility is difficult and code intensive.

However, this use case becomes almost trivial when you think about it in terms
of tools (nushell + xs) as demonstrated above.

## Document Aggregation Use Case

The purpose of this section is to illustrate how you can aggregate documents and
artifacts for LLM analysis.

![agg-doc-use-case](https://github.com/user-attachments/assets/1d63e8c0-122c-4a8e-924c-3c25e2387053)

## FAQ

- Why does the name include 2099? What else would you call the future?
- What is a message?
- What is a conversation?
- What is an event?

## Original intro

https://github.com/user-attachments/assets/4c74e5e6-c413-402b-8283-45a3a149bce5
