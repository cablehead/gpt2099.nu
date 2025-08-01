# Testing

## Running Tests

### Complete Test Suite

```nushell
nu -c 'use tests/run.nu ; run'
```

Runs all test levels: unit, schema, provider transformations, and end-to-end integration.

### Individual Test Suites

```nushell
# Unit tests
nu -c 'use tests/unit/util.nu ; util'
nu -c 'use tests/unit/mcp-response-processing.nu ; mcp-response-processing'

# Schema generation tests
nu -c 'use tests/schema/test-schema-generation.nu ; test-schema-generation'

# Provider transformation tests
nu -c 'use tests/providers/test-prepare-request.nu ; test-prepare-request'
nu -c 'use tests/providers/test-prepare-request.nu ; test-prepare-request anthropic'
nu -c 'use tests/providers/test-prepare-request.nu ; test-prepare-request anthropic document-image'

# End-to-end integration tests (requires API keys)
nu -c 'use xs.nu *; overlay use -pr /root/session/gpt2099.nu/gpt ; use tests/end-to-end/test-end-to-end.nu ; test-end-to-end'
```

### API Testing

Provider tests support real API validation:

```nushell
# Test with real API calls (⚠️ consumes tokens!)
nu -c 'use tests/providers/test-prepare-request.nu ; test-prepare-request anthropic --call "your-api-key"'
```

## Test Structure

```
tests/
├── run.nu                       # Complete test runner
├── unit/                        # Fast isolated tests
│   ├── util.nu
│   └── mcp-response-processing.nu
├── schema/                      # Schema validation
│   └── test-schema-generation.nu
├── providers/                   # Provider transformations
│   └── test-prepare-request.nu
├── end-to-end/                  # Real API integration
│   └── test-end-to-end.nu
└── fixtures/                    # Test data
    ├── assets/                  # Binary test files
    ├── prepare-request/         # Provider test cases
    └── mcp-response-to-tool-result/
```

## Test Levels

### Unit Tests
- **util.nu**: Core utility functions
- **mcp-response-processing.nu**: MCP response transformation
- **Fast**: No external dependencies
- **Isolated**: Test individual functions

### Schema Tests
- **test-schema-generation.nu**: Validates normalized format generation
- **Pipeline validation**: Ensures schema consistency

### Provider Tests
- **test-prepare-request.nu**: Tests provider transformations
- **11 test cases**: Documents, tools, cache control, search
- **3 providers**: anthropic, gemini, openai (fixtures missing)
- **API option**: `--call` flag for real API validation

### End-to-End Tests
- **test-end-to-end.nu**: Full pipeline integration
- **Real API calls**: Tests `gpt.call.basics` and `gpt.call.tool_use`
- **Environment dependent**: Requires gpt module loaded

## Fixture Structure

Provider test cases use normalized input with provider-specific expected outputs:

```
tests/fixtures/prepare-request/document-text/
├── input.json                   # Normalized context window
├── expected-anthropic.json      # Anthropic transformation
├── expected-gemini.json         # Gemini transformation
└── expected-openai.json         # OpenAI (missing)
```

### Error Testing

Unsupported features use `.err` files:

```
tool-use-with-search/
├── input.json
├── expected-anthropic.json      # Works
└── expected-gemini.err          # Error message
```

### Dynamic Assets

Binary files loaded at runtime to avoid large base64 in fixtures:
- `tests/fixtures/assets/` contains PDF, image, markdown files
- Test runner dynamically populates document fixtures

## Adding Tests

### New Provider
Add expected output files:
```bash
echo '{}' > tests/fixtures/prepare-request/document-text/expected-newprovider.json
```

### New Test Case
Create fixture directory under `prepare-request/` with:
- `input.json` (normalized format)
- `expected-{provider}.json` for each supported provider
- `expected-{provider}.err` for unsupported features

### API Keys for Testing
Set provider API keys in environment or pass via `--call` flag for real API validation.