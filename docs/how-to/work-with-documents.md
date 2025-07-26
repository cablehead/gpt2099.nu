# How to Work with Documents

This guide shows you how to register, reference, and work with documents in conversations.

## Overview

gpt2099.nu supports various document types that can be registered and referenced in conversations. Documents are automatically cached for better performance and can be given custom names and bookmarks for easy reference.

## Supported Document Types

- **PDFs** (`application/pdf`)
- **Images** (`image/jpeg`, `image/png`, `image/webp`, `image/gif`)
- **Text files** (`text/plain`, `text/markdown`, `text/csv`)
- **Office documents** (`application/vnd.openxmlformats-officedocument.*`)
- **JSON** (`application/json`)

## Basic Document Workflow

### 1. Register a Document

```nushell
gpt document ~/reports/analysis.pdf
```

This returns a document record with an `id` field you can reference later.

### 2. Use Document in Conversation

```nushell
let doc = (gpt document ~/manual.pdf)
"Summarize this manual" | gpt --continues $doc.id -p milli
```

### 3. Continue the Conversation

```nushell
"What are the key safety procedures?" | gpt -r -p milli
```

The `-r` flag continues from the last turn automatically.

## Advanced Document Usage

### Custom Names and Bookmarks

```nushell
# Register with custom name and bookmark for easy reference
gpt document ~/data.csv --name "Sales Data Q4" --bookmark "sales-data"

# Reference by bookmark later
"Analyze quarterly trends" | gpt --continues sales-data -p kilo
```

### Multiple Documents

You can reference multiple documents by passing a list of IDs:

```nushell
let doc1 = (gpt document ~/report1.pdf)
let doc2 = (gpt document ~/report2.pdf)
"Compare these reports" | gpt --continues [$doc1.id, $doc2.id] -p kilo
```

### Working with Different Content Types

**Text-based documents** (markdown, CSV, JSON) are converted to text blocks:
```nushell
gpt document ~/README.md --name "Project Documentation"
```

**Binary documents** (PDFs, images) are kept in their original format:
```nushell
gpt document ~/chart.png --name "Sales Chart"
```

## Document Caching

Documents automatically use ephemeral caching with supported providers (like Anthropic) to improve performance on repeated references. You can control caching with the `--cache` flag:

```nushell
gpt document ~/large-file.pdf --cache ephemeral
gpt document ~/dynamic-data.json --cache none
```

## Thread Management with Documents

Documents integrate seamlessly with conversation threading:

```nushell
# Start a research session
let research_doc = (gpt document ~/research.pdf --bookmark "research-session")

# Ask initial question
"What are the main findings?" | gpt --continues $research_doc.id -p milli

# Continue the research thread
"How does this relate to previous studies?" | gpt -r -p milli

# Branch the conversation
"Summarize for a general audience" | gpt --continues research-session -p milli
```

See the [commands reference](../commands.md#gpt-document) for complete document command options.