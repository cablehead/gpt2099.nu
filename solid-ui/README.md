# a Web UI for your chat threads

This is a [`SolidJS`](https://www.solidjs.com) UI gpt2099's threaded chat
history

Requirements:

- [Deno2](https://deno.com)
- [xs](https://github.com/cablehead/xs)

## To run

Start `xs`:

```
xs serve ./store --expose :3021
```

Todo: create some chat threads

Start UI:

```
deno task dev
open http://localhost:5173
```

# tool use

- `acall.nu`: a command to call anthropic with tool use. It's trigger with
  `.append llm.call --meta {id: <id>}`. The response is stream out to llm.recv
  events as it arrives.
- `save-response.nu`: watches for streamed responses from an LLM and records
  them as assistant messages
- `w.nu` watch llm response stream in

Resume:

```nushell
"prompt" | .append message --meta {continues: "id to resume from"} | .append llm.call --meta {id: $in.id }
```

Tool use:

```nushell
handle-tool-use-request (.last) | .append llm.call --meta {id: $in.id}
```
