# Testing

## Running Tests

```bash
# Run all Anthropic prepare-request tests
use tests/providers/anthropic/prepare-request.nu; prepare-request run-all

# Run individual test case
use tests/providers/anthropic/prepare-request.nu; prepare-request test-text-document
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