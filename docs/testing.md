# Testing

## Running Tests

```bash
use tests/providers/test-prepare-request.nu

# Test all cases for a provider
test-prepare-request anthropic
test-prepare-request gemini

# Test specific case
test-prepare-request anthropic image-document

# Test with real API calls (⚠️ consumes tokens!)
test-prepare-request anthropic --call "your-api-key"
```

## Test Structure

### Organization

```
tests/
├── fixtures/
│   ├── assets/                   # Binary test files
│   │   ├── doc.pdf
│   │   ├── img.png
│   │   └── doc.md
│   └── prepare-request/          # Provider transformation tests
│       ├── text-document/
│       │   ├── input.json        # Normalized context window format
│       │   ├── expected-anthropic.json
│       │   └── expected-gemini.json
│       ├── cache-control/        # Tests Anthropic's 4-breakpoint limit
│       ├── pdf-document/         # Dynamic asset loading
│       └── image-document/
├── schema/
│   └── test-schema-generation.nu # Tests normalized format generation
└── providers/
    └── test-prepare-request.nu   # Tests provider transformations
```

### Design Principles

- **Pipeline Testing**: Each layer tested separately with clear interfaces
- **Provider-neutral inputs**: Fixtures use normalized context window format
- **Provider-specific outputs**: Each provider transforms inputs differently
- **Dynamic asset loading**: Binary files loaded from `assets/` to avoid storing base64 in JSON
- **API testing option**: Run against fixtures (fast) or real APIs (validation)

### Dynamic Asset Loading

Binary fixtures are populated at runtime:

1. **Asset Storage**: Files in `tests/fixtures/assets/`
2. **Runtime Population**: Test runner loads and base64-encodes assets into fixtures
3. **Reduced repo size**: No large base64 strings in JSON files

### API Testing

The `--call` parameter enables full pipeline testing:

- **Token consumption**: Warns before making real API calls
- **Cheap models**: Uses `claude-3-5-haiku-20241022` (Anthropic), `gemini-2.5-flash` (Gemini)
- **Smoke test**: Verifies API calls return events without detailed validation
- **Debugging**: Set `GPT_TEST_VERBOSE=true` for response details

### Commands

```nushell
# Test schema generation
use tests/schema/test-schema-generation.nu; test-schema-generation

# Test provider transformations
use tests/providers/test-prepare-request.nu; test-prepare-request anthropic

# Test with real API (costs tokens)
use tests/providers/test-prepare-request.nu; test-prepare-request anthropic --call "key"
```

## Expansion

### Adding Test Cases

Create new fixture directories under `prepare-request/`:

- `system-messages/` - System message handling
- `tool-integration/` - MCP tool conversion
- `search-enabled/` - Web search capabilities

### Adding Providers

Add expected output files:

```bash
# Support new provider
echo '{}' > tests/fixtures/prepare-request/text-document/expected-newprovider.json
```

### Adding Methods

Provider-specific methods need separate fixture structure:

```
tests/fixtures/
├── prepare-request/              # Shared inputs
└── response-stream-aggregate/    # Method-specific tests
    ├── anthropic/
    └── gemini/
```
