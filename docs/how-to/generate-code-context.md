# How to Generate Code Context

This guide shows you how to create structured XML context from your Git repository for LLM
analysis.

## Overview

The `gpt prep gr` command generates XML representations of your repository files for LLM analysis,
refactoring, or documentation tasks.

## Basic Usage

### Generate Context for Specific Files

```nushell
gpt prep gr main.py utils.py config.json | gpt -p kilo
```

### Generate Context from Git Files

```nushell
git ls-files | lines | gpt prep gr
```

This creates XML context for all files tracked by Git.

### Preview Generated Context

```nushell
git ls-files ./gpt | lines | gpt prep gr | bat -l xml
```

Use `bat` with XML syntax highlighting to preview the structure before sending to an LLM.

## Advanced Context Generation

### Filter Specific File Types

```nushell
# Only Python files
git ls-files | lines | where ($it | str ends-with ".py") | gpt prep gr

# Multiple file types
git ls-files | lines | where ($it | str ends-with ".py" or $it | str ends-with ".nu") | gpt prep gr
```

### Exclude Certain Directories

```nushell
git ls-files | lines | where ($it | str contains "tests/" | not) | gpt prep gr
```

### Include Specific Subdirectory

```nushell
git ls-files ./src | lines | gpt prep gr
```

## Context Structure

The generated XML has this structure:

```xml
<context type="git-repo" path="/path/to/repo" origin="https://github.com/user/repo" caveats="XML special characters have been escaped. Be sure to unescape them before processing">
  <file name="main.py">
    def main():
        print("Hello, world!")
  </file>
  <file name="utils.py">
    def helper_function():
        return "utility"
  </file>
</context>
```

## Custom Content Processing

### Using Custom Content Fetcher

```nushell
# Custom closure to process file content
git ls-files | lines | gpt prep gr --with-content {|| head -n 20}
```

This reads only the first 20 lines of each file.

### Adding Instructions

```nushell
git ls-files ./src | lines | gpt prep gr --instructions "Focus on code architecture and design patterns"
```

## Common Workflows

### Code Review Request

```nushell
# Generate context and request review
git ls-files ./src | lines | gpt prep gr | "Review this codebase for potential improvements" | gpt -p kilo
```

### Documentation Generation

```nushell
# Generate API documentation
git ls-files | lines | where ($it | str ends-with ".py") | gpt prep gr | "Generate API documentation" | gpt -p kilo --bookmark "api-docs"
```

### Architecture Analysis

```nushell
# Analyze system architecture
git ls-files | lines | gpt prep gr --instructions "Focus on system architecture and component relationships" | "Analyze the overall architecture and suggest improvements" | gpt -p kilo
```

### Refactoring Assistance

```nushell
# Get refactoring suggestions for specific modules
git ls-files ./legacy | lines | gpt prep gr | "Suggest refactoring strategies for this legacy code" | gpt -p kilo
```

### Bug Investigation

```nushell
# Include relevant files for bug analysis
["src/main.py", "src/parser.py", "tests/test_parser.py"] | gpt prep gr | "Analyze these files for potential bugs in the parser logic" | gpt -p kilo
```

## Working with Large Repositories

### Selective Context Generation

For large repositories, be selective about what you include:

```nushell
# Core modules only
["src/core/", "src/api/"] | each {|dir| git ls-files $dir | lines } | flatten | gpt prep gr

# Recently changed files
git diff --name-only HEAD~10 | lines | gpt prep gr
```

### Chunked Analysis

Break large repositories into chunks:

```nushell
# Analyze backend separately
git ls-files ./backend | lines | gpt prep gr | "Analyze backend architecture" | gpt --bookmark "backend-analysis" -p kilo

# Analyze frontend separately
git ls-files ./frontend | lines | gpt prep gr | "Analyze frontend architecture" | gpt --bookmark "frontend-analysis" -p kilo

# Compare architectures
"Compare the backend and frontend architectures" | gpt --continues [backend-analysis, frontend-analysis] -p kilo
```

## Integration with Conversations

### Continue Code Analysis

```nushell
# Initial analysis
git ls-files ./src | lines | gpt prep gr | "What are the main components?" | gpt --bookmark "code-review" -p kilo

# Follow-up questions
"What design patterns are used?" | gpt -r -p milli
"Are there any code smells?" | gpt -r -p milli
```

### Combine with Documentation

```nushell
# Include both code and documentation
let doc = (gpt document ./README.md)
git ls-files ./src | lines | gpt prep gr | "How well does the code match the documentation?" | gpt --continues $doc.id -p kilo
```

## Performance Tips

1. **Be selective** - Don't include unnecessary files (tests, generated files, etc.)
2. **Use appropriate models** - Simple questions can use smaller models like `milli`
3. **Break up large requests** - Chunk analysis for very large codebases
4. **Preview context** - Use `bat -l xml` to check structure before sending
5. **Save analysis** - Use bookmarks for important code review sessions

See the [commands reference](../commands.md#gpt-prep) for complete context generation options.
