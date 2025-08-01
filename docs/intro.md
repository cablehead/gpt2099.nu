# gpt2099

A [Nushell](https://www.nushell.sh) scriptable
[MCP client](https://modelcontextprotocol.io/sdk/java/mcp-client#model-context-protocol-client)
with [editable context threads](https://cablehead.github.io/xs/tutorials/threaded-conversations/)
stored in [cross.stream](https://cablehead.github.io/xs/)

<img width="660" alt="image" src="https://github.com/user-attachments/assets/2b8d8744-076c-40e1-ac2c-1b1864ca2b80" />

## Features

- **Consistent API Across Models:** Connect to Gemini + Search and Anthropic + Search through a
  single, simple interface. ([Add providers easily.](reference/provider-api.md))
- **Persistent, Editable Conversations:**
  [Conversation threads](https://cablehead.github.io/xs/tutorials/threaded-conversations/) are
  saved across sessions. Review, edit, and control your own context window — no black-box history.
- **Flexible Tool Integration:** Connect to MCP servers to extend functionality. `gpt2099` already
  rivals [Claude Code](https://docs.anthropic.com/en/docs/claude-code/overview) for local file
  editing, but with full provider independence and deeper flexibility.
- **Document Support:** Upload and reference documents (PDFs, images, text files) directly in
  conversations with automatic content-type detection and optional caching.

Built on [cross.stream](https://github.com/cablehead/xs) for event-driven processing, `gpt2099`
brings modern AI directly into your Nushell workflow — fully scriptable, fully inspectable, all in
the terminal.

<video controls width="660">
  <source src="https://github.com/user-attachments/assets/1254aaa1-2ca2-46b5-96e8-b5e466c735bd" type="video/mp4">
  Your browser does not support the video tag.
</video>

<small><i>"lady on the track" provided by [mobygratis](https://mobygratis.com)</i><small>

## Original Intro

This is how the project looked, 4 hours into its inception:

<video controls width="660">
  <source src="https://github.com/user-attachments/assets/768cc655-a892-47cc-bf64-8b5f61c41f35" type="video/mp4">
  Your browser does not support the video tag.
</video>
