# Testing

## Running Tests

```bash
use tests/providers/test-prepare-request.nu

# Run all tests for a provider (fixture comparison)
test-prepare-request anthropic
test-prepare-request gemini

# Run specific test case
test-prepare-request anthropic image-document
test-prepare-request gemini pdf-document

# Run with actual API calls (⚠️ consumes tokens!)
test-prepare-request anthropic --call "your-api-key"
test-prepare-request anthropic text-document --call "your-api-key"
```

## Test Structure

### Fixture Organization

Tests use JSON fixtures to separate test data from test logic:

```
tests/
├── fixtures/
│   ├── assets/                   # Binary assets for dynamic fixtures
│   │   ├── doc.pdf              # PDF document for testing
│   │   ├── img.png              # PNG image for testing  
│   │   └── doc.md               # Markdown document for testing
│   └── prepare-request/          # Shared across all providers
│       ├── text-document/
│       │   ├── input.json        # Provider-neutral input
│       │   ├── expected-anthropic.json
│       │   ├── expected-gemini.json
│       │   └── expected-openai.json    # (future)
│       ├── pdf-document/         # Dynamic asset loading
│       ├── image-document/       # Dynamic asset loading
│       └── mixed-content/
│           └── ...
└── providers/
    ├── prepare-request.nu        # Unified test runner for all providers
    ├── anthropic/                # (legacy - can be removed)
    ├── gemini/                   # (legacy - can be removed)
    └── openai/                   # (future)
```

### Design Principles

- **Provider-neutral inputs**: `prepare-request` fixtures work across all providers since they use the neutral content representation
- **Provider-specific outputs**: Each provider transforms inputs differently, so separate expected files per provider
- **Method-specific organization**: Different provider methods get their own fixture directories
- **Descriptive naming**: Fixture directories named by input characteristics, not expected behavior
- **Dynamic asset loading**: Binary fixtures (PDF, images) are dynamically populated from `tests/fixtures/assets/` to avoid storing large base64 data in JSON
- **API testing option**: Tests can run against fixtures (fast) or make real API calls (validation)

### API Testing

The `--call` parameter enables testing the full pipeline by making actual API calls:

- **API Key**: Pass your Anthropic API key as the `--call` parameter value
- **Model**: Uses cheapest available models to minimize costs:
  - Anthropic: `claude-3-5-haiku-20241022`
  - Gemini: `gemini-2.5-flash`
- **Validation**: Simple smoke test - just verifies API calls return events
- **Safety**: Warns about token consumption before making calls
- **Debugging**: Set `GPT_TEST_VERBOSE=true` to see response event details

### Expansion Plan

#### Additional Test Cases
Add more `prepare-request` scenarios by creating new fixture directories:
- `system-messages/` - Test system message handling  
- `tool-integration/` - Test MCP tool conversion
- `search-enabled/` - Test web search tool addition
- `empty-content/` - Test edge cases

#### Additional Providers
Extend to other providers by adding expected outputs:
```bash
# Add Gemini support
echo '{}' > tests/fixtures/prepare-request/text-document/expected-gemini.json
```

#### Additional Methods
Provider-specific streaming methods need their own fixture structure:
```
tests/fixtures/
├── prepare-request/              # Shared inputs
└── response-stream-aggregate/    # Provider-specific inputs/outputs
    ├── anthropic/
    │   └── tool-response/
    │       ├── input.json        # Anthropic event stream
    │       └── expected.json     # Normalized output
    └── gemini/
        └── function-call/
            ├── input.json        # Gemini event stream  
            └── expected.json     # Normalized output
```

This structure scales cleanly as we add providers and test more complex scenarios.

### Dynamic Asset Loading

For fixtures that contain binary data (PDFs, images), the test system uses dynamic asset loading:

1. **Asset Storage**: Binary files are stored in `tests/fixtures/assets/`
2. **Runtime Population**: Test runner loads assets and base64-encodes them into fixtures
3. **Asset Mapping**: `prepare-request.nu` contains a mapping of test cases to their asset files
4. **Automatic Updates**: When assets change, fixtures are automatically updated with new data

This approach:
- **Reduces repo size**: Avoids storing large base64 strings in JSON files
- **Improves maintainability**: Binary files can be easily replaced or updated
- **Ensures consistency**: All test cases use the same asset files
- **Supports version control**: Binary assets are tracked separately from test logic

### Testing Best Practices

1. **Development workflow**: Use fixture-based tests for rapid iteration
2. **Integration validation**: Use `--call` tests to verify API compatibility 
3. **CI considerations**: Skip API tests in automated environments unless explicitly enabled
4. **Cost management**: API tests use the cheapest available model
5. **Error diagnosis**: Use verbose mode to inspect actual API responses when debugging