# How to Manage Conversations

This guide shows you how to create, continue, and organize conversation threads using bookmarks and
continuation patterns.

## Overview

gpt2099 stores conversations as persistent, editable threads. Each conversation turn is linked to
previous turns, creating a branching conversation history you can navigate, edit, and continue from
any point.

## Basic Conversation Flow

### Starting a Conversation

```nushell
"What is the capital of France?" | gpt -p milli
```

This creates a new conversation turn and generates a response.

### Continuing a Conversation

```nushell
# Continue from the last turn automatically
"What about its population?" | gpt -r -p milli

# Or specify a specific turn ID to continue from
"What about Italy?" | gpt --continues 01JG123ABC456DEF789GHI012 -p milli
```

## Bookmarking Conversations

### Creating Bookmarks

Use bookmarks to name conversation threads for easy reference:

```nushell
"Let's discuss European capitals" | gpt --bookmark "europe-capitals" -p milli
```

### Using Bookmarks

Continue conversations using bookmark names instead of IDs:

```nushell
"What about Germany's capital?" | gpt --continues europe-capitals -p milli
```

### Automatic Bookmark Inheritance

Bookmarks are automatically carried forward in a thread:

```nushell
# Start with bookmark
"Analyze this data" | gpt --bookmark "data-analysis" -p kilo

# Bookmark is inherited in responses
"What are the trends?" | gpt -r -p milli  # Still part of "data-analysis"
```

## Branching Conversations

### Creating Branches

Start different conversation branches from the same point:

```nushell
# Original conversation
"Explain quantum physics" | gpt --bookmark "physics" -p milli

# Branch 1: Technical deep-dive
"Go deeper into wave-particle duality" | gpt --continues physics -p kilo

# Branch 2: Simple explanation
"Explain this for a 10-year-old" | gpt --continues physics -p milli
```

### Multiple Continuation Points

Continue from multiple previous turns:

```nushell
let turn1 = "First topic" | gpt -p milli
let turn2 = "Second topic" | gpt -p milli

"Combine insights from both topics" | gpt --continues [$turn1.id, $turn2.id] -p kilo
```

## Inspecting Conversation History

### View Raw Thread History

```nushell
gpt ctx list europe-capitals
```

Shows the chronological sequence of turns in a thread.

### View Resolved Context

```nushell
gpt ctx resolve europe-capitals
```

Shows the full context window as it would be sent to the LLM, with all options merged.

### Context Without Bookmark

```nushell
# View context for a specific turn ID
gpt ctx list 01JG123ABC456DEF789GHI012
```

## Advanced Threading Patterns

### Document-Based Conversations

```nushell
# Register document with bookmark
let doc = (gpt document ~/report.pdf --bookmark "report-analysis")

# Start analysis thread
"Summarize the key findings" | gpt --continues $doc.id -p milli

# Continue the same thread
"What are the recommendations?" | gpt -r -p milli

# Branch for different analysis
"What are the potential risks?" | gpt --continues report-analysis -p milli
```

### Project-Based Organization

```nushell
# Organize conversations by project
"Review code architecture" | gpt --bookmark "project-alpha-arch" -p kilo
"Plan deployment strategy" | gpt --bookmark "project-alpha-deploy" -p milli
"Analyze user feedback" | gpt --bookmark "project-alpha-feedback" -p milli
```

### Research Sessions

```nushell
# Long-running research with multiple documents
let paper1 = (gpt document ~/research/paper1.pdf)
let paper2 = (gpt document ~/research/paper2.pdf)

"Compare methodologies" | gpt --continues [$paper1.id, $paper2.id] --bookmark "research-session" -p kilo

# Continue research across sessions
"How do these findings impact current practice?" | gpt --continues research-session -p milli
```

## Context Window Management

### Controlling Context Size

Use selective continuation to manage context window size:

```nushell
# Instead of continuing the entire thread
"New question" | gpt -r -p milli

# Continue from a specific earlier point
"New question" | gpt --continues specific-turn-id -p milli
```

### Thread Options Inheritance

Thread options (servers, search, provider settings) are inherited:

```nushell
# Set options for a thread
"Initial query" | gpt --servers [filesystem] --search --bookmark "research" -p kilo

# Options are inherited in continuations
"Follow-up question" | gpt -r  # Inherits filesystem server and search
```

You can override inherited options:

```nushell
"Different follow-up" | gpt --continues research --servers [web-search] -p milli
```

## Best Practices

1. **Use descriptive bookmarks** for important conversation threads
2. **Branch conversations** when exploring different approaches to the same topic
3. **Inspect context** with `gpt ctx resolve` to understand what's being sent to the LLM
4. **Manage context size** by continuing from specific points rather than entire threads
5. **Organize by project or topic** using consistent bookmark naming schemes

See the [commands reference](../commands.md#gpt-ctx) for complete context inspection commands.
