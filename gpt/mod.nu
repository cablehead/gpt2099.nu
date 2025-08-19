# This module provides commands for interacting with Language Model (LLM) APIs.
# It manages conversation threads, supports different providers, and handles tool use.
#
# See docs/reference/schemas.md for detailed documentation on core concepts
# including the 'headish' mechanism for conversation threading.

export use ./ctx.nu
export use ./mcp.nu
export use ./providers
export use ./provider.nu
export use ./prep.nu
export use ./schema.nu

export def document [
  path: string # Path to the document file
  --name (-n): string # Optional name for the document (defaults to filename)
  --cache # Enable caching for this document
  --bookmark (-b): string # Bookmark this document registration
] {
  # Validate file exists
  if not ($path | path exists) {
    error make {
      msg: $"File does not exist: ($path)"
      label: {
        text: "this path"
        span: (metadata $path).span
      }
    }
  }

  # Detect content type from file extension
  let content_type = match ($path | path parse | get extension | str downcase) {
    "pdf" => "application/pdf"
    "txt" => "text/plain"
    "md" => "text/markdown"
    "json" => "application/json"
    "csv" => "text/csv"
    "jpg"|"jpeg" => "image/jpeg"
    "png" => "image/png"
    "webp" => "image/webp"
    "gif" => "image/gif"
    "docx" => "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
    "xlsx" => "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
    _ => {
      let detected = (file --mime-type $path | split row ":" | get 1 | str trim)
      print $"Warning: Unknown extension, detected MIME type: ($detected)"
      $detected
    }
  }

  # Check file size (rough limit)
  let file_size = ($path | path expand | ls $in | get size | first)
  if $file_size > 100MB {
    error make {
      msg: $"File too large: ($file_size). Consider splitting or compressing."
    }
  }

  let document_name = $name | default ($path | path basename)

  # Build storage metadata
  let meta = {
    role: "user"
    type: "document"
    content_type: $content_type
    document_name: $document_name
    original_path: ($path | path expand)
    file_size: $file_size
  } | conditional-pipe ($bookmark | is-not-empty) {
    insert head $bookmark
  } | conditional-pipe $cache {
    insert cache true
  }

  # Store raw binary directly in cross.stream
  let turn = open $path --raw | .append gpt.turn --meta $meta

  $turn
}

export def main [
  --continues (-c): any # Previous `headish` to continue a conversation, can be a list of `headish`
  --respond (-r) # Continue from the last turn
  --servers: list<string> # MCP servers to use
  --search # enable LLM-side search (currently anthropic + gemini only)
  --bookmark (-b): string # bookmark this turn: this will become the thread's head name
  --provider-ptr (-p): string # a short alias for provider to going-forward
  --json (-j) # Treat input as JSON formatted content
  --cache # Enable caching for this turn
] {
  let content = if $in == null {
    input "Enter prompt: "
  } else {
    $in
  }

  # Create turn using schema layer
  let turn = $content | schema add-turn {
    continues: $continues
    respond: $respond
    servers: $servers
    search: $search
    bookmark: $bookmark
    provider_ptr: $provider_ptr
    json: $json
    cache: $cache
  }

  process-turn $turn
}

export def --env process-turn-response [turn: record] {
  let content = .cas $turn.hash | from json
  let tool_use = $content | where type == "tool_use"
  if ($tool_use | is-empty) { return }
  let tool_use = $tool_use | first
  print ($tool_use | table -e)

  let yolo_mode = $env.GPT2099_YOLO? | default false

  let choice = if $yolo_mode {
    print "🚀 YOLO mode: auto-executing..."
    "yes"
  } else {
    ["yes" "no: do something different" "no" "activate: yolo"] | input list "Execute?"
  }

  # Handle yolo activation
  if $choice == "activate: yolo" {
    $env.GPT2099_YOLO = true
    print "🚀 YOLO mode activated for future tool calls"
  }

  match $choice {
    "yes"|"activate: yolo" => {
      # Execute tool call
      let namespace = ($tool_use.name | split row "___")
      let mcp_toolscall = $tool_use | {
        "jsonrpc": "2.0"
        "id": $turn.id
        "method": "tools/call"
        "params": {"name": $namespace.1 "arguments": ($in.input | default {})}
      }
      let res = $mcp_toolscall | mcp call $namespace.0
      let tool_result = [
        ($res | mcp response-to-tool-result $tool_use)
      ]
      print ($tool_result | table -e)
      let meta = {
        role: "user"
        content_type: "application/json"
        continues: $turn.id
      } | conditional-pipe ($turn.meta?.head? | is-not-empty) { insert head $turn.meta?.head? }
      let turn = $tool_result | to json | .append gpt.turn --meta $meta
      process-turn $turn
    }
    "no: do something different" => {
      # New custom input path
      let custom_text = input "Enter alternative response: "
      let tool_result = [
        {
          type: "tool_result"
          tool_use_id: $tool_use.id
          content: [
            {
              type: "text"
              text: $custom_text
            }
          ]
          is_error: true
          name: $tool_use.name
        }
      ]
      print ($tool_result | table -e)
      let meta = {
        role: "user"
        content_type: "application/json"
        continues: $turn.id
      } | conditional-pipe ($turn.meta?.head? | is-not-empty) { insert head $turn.meta?.head? }
      let turn = $tool_result | to json | .append gpt.turn --meta $meta
      process-turn $turn
    }
    "no" => {
      return {}
    }
  }
}

export def process-turn [turn: record] {
  let role = $turn.meta | default "user" role | get role
  if $role == "assistant" {
    return (process-turn-response $turn)
  }

  let res = call $turn.id {
    generate {|chunk block = ""|
      let chunk = $chunk | .cas $in.hash | from json
      if $chunk == null { return {next: $block} } # Skip ignored chunks

      let next_block = $chunk.type? | default $block

      # Handle type indicator chunks (new content blocks)
      if $next_block != $block {
        if $block != "" {
          print "\n"
        }
        if $next_block != "text" {
          print -n $next_block
          if "name" in $chunk {
            print -n $"\(($chunk.name)\)"
          }
          print ":"
        }
      }

      # Handle content addition chunks
      if "content" in $chunk {
        print -n $chunk.content
      }

      {next: $next_block} # Continue with the next block
    }
  }

  if $res.topic == "gpt.error" {
    print "womp" ($res | table -e)
    return
  }

  .cas $res.hash | process-turn-response $res
}

export def call [turn_id: string preview?: closure] {
  let req = .append gpt.call --meta {continues: $turn_id}
  let res = .cat -f --last-id $req.id
  | conditional-pipe ($preview | is-not-empty) {
    tee {
      where {|frame|
        ($frame.topic == "gpt.recv") and ($frame.meta?.frame_id == $req.id)
      } | do $preview
    }
  }
  | where {|frame|
    let end = ($frame.topic in ["gpt.error" "gpt.turn"]) and ($frame.meta?.frame_id == $req.id)
    $end
  }
  | first
  $res
}

export def version [] {
  # When updating this version, also update clientInfo.version in mcp-rpc.nu
  "0.6"
}

export def init [
  --refresh (-r) # Skip configuration if set
] {
  const base = (path self) | path dirname
  cat ($base | path join "ctx.nu") | .append gpt.mod.ctx
  cat ($base | path join "mcp-rpc.nu") | .append gpt.mod.mcp-rpc
  cat ($base | path join "providers/anthropic/mod.nu") | .append gpt.mod.provider.anthropic
  cat ($base | path join "providers/gemini/mod.nu") | .append gpt.mod.provider.gemini
  cat ($base | path join "xs/command-call.nu") | .append gpt.define
  cat ($base | path join "xs/handler-mcp.nu") | .append mcp.manager.register
  if not $refresh {
  }
  ignore
}

def conditional-pipe [
  condition: bool
  action: closure
] {
  if $condition { do $action } else { }
}
