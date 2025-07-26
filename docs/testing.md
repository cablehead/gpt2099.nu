# Testing

## Running Tests

```bash
# Run all Anthropic prepare-request tests (fixture comparison only)
use tests/providers/anthropic/prepare-request.nu; prepare-request run-all

# Run all tests with actual API calls (⚠️ consumes tokens!)
use tests/providers/anthropic/prepare-request.nu; prepare-request run-all --call "your-api-key-here"

# Run individual test case
use tests/providers/anthropic/prepare-request.nu; prepare-request test-text-document

# Run individual test case with API call
use tests/providers/anthropic/prepare-request.nu; prepare-request test-text-document --call "your-api-key-here"

# Verbose output to see response details
GPT_TEST_VERBOSE=true use tests/providers/anthropic/prepare-request.nu; prepare-request run-all --call "your-api-key-here"
```

## Test Structure

### Fixture Organization

Tests use JSON fixtures to separate test data from test logic:

```
tests/
├── fixtures/
│   └── prepare-request/          # Shared across all providers
│       ├── text-document/
│       │   ├── input.json        # Provider-neutral input
│       │   ├── expected-anthropic.json
│       │   ├── expected-gemini.json    # (future)
│       │   └── expected-openai.json    # (future)
│       └── mixed-content/
│           └── ...
└── providers/
    ├── anthropic/
    │   └── prepare-request.nu    # Test runner
    ├── gemini/                   # (future)
    └── openai/                   # (future)
```

### Design Principles

- **Provider-neutral inputs**: `prepare-request` fixtures work across all providers since they use the neutral content representation
- **Provider-specific outputs**: Each provider transforms inputs differently, so separate expected files per provider
- **Method-specific organization**: Different provider methods get their own fixture directories
- **Descriptive naming**: Fixture directories named by input characteristics, not expected behavior
- **API testing option**: Tests can run against fixtures (fast) or make real API calls (validation)

### API Testing

The `--call` parameter enables testing the full pipeline by making actual API calls:

- **API Key**: Pass your Anthropic API key as the `--call` parameter value
- **Model**: Uses `claude-3-haiku-20240307` (cheapest model) to minimize costs
- **Validation**: Checks for expected response structure and event types
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

### Testing Best Practices

1. **Development workflow**: Use fixture-based tests for rapid iteration
2. **Integration validation**: Use `--call` tests to verify API compatibility 
3. **CI considerations**: Skip API tests in automated environments unless explicitly enabled
4. **Cost management**: API tests use the cheapest available model
5. **Error diagnosis**: Use verbose mode to inspect actual API responses when debugging