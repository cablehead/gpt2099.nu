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

### Test Organization

The test suite is organized into pipeline-focused layers:

```
tests/
├── fixtures/
│   ├── assets/                   # Binary assets for dynamic fixtures
│   │   ├── doc.pdf              # PDF document for testing
│   │   ├── img.png              # PNG image for testing  
│   │   └── doc.md               # Markdown document for testing
│   └── prepare-request/          # Inputs for provider prepare-request tests
│       ├── text-document/
│       │   ├── input.json        # Normalized context window format
│       │   ├── expected-anthropic.json
│       │   ├── expected-gemini.json
│       │   └── expected-openai.json    # (future)
│       ├── cache-control/        # Tests Anthropic's 4-breakpoint limit
│       ├── pdf-document/         # Dynamic asset loading
│       ├── image-document/       # Dynamic asset loading
│       └── mixed-content/
│           └── ...
├── schema/
│   └── test-schema-generation.nu # Tests schema layer produces correct format
└── providers/
    ├── test-prepare-request.nu   # Tests provider transformation layer
    └── (legacy directories can be removed)
```

### Design Principles  

- **Pipeline Testing**: Each layer of the pipeline has focused tests with clear interfaces
- **Schema Generation**: `tests/schema/` validates that the schema layer produces normalized format
- **Provider Transformation**: `tests/providers/` validates provider-specific transformations
- **Provider-neutral inputs**: `prepare-request` fixtures use the normalized context window format
- **Provider-specific outputs**: Each provider transforms inputs differently, so separate expected files per provider
- **Method-specific organization**: Different provider methods get their own fixture directories
- **Descriptive naming**: Fixture directories named by input characteristics, not expected behavior  
- **Dynamic asset loading**: Binary fixtures (PDF, images) are dynamically populated from `tests/fixtures/assets/` to avoid storing large base64 data in JSON
- **API testing option**: Tests can run against fixtures (fast) or make real API calls (validation)
- **Contract validation**: Tests ensure interfaces between pipeline steps are maintained

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

### Schema Layer Testing

The schema generation layer is tested separately to ensure it produces the correct normalized format:

```nushell
# Test that schema functions create proper normalized turns
use tests/schema/test-schema-generation.nu
test-schema-generation
```

These tests validate:
- `schema user-turn` produces correct message structure  
- `schema document-turn` handles file types and metadata correctly
- Generated schemas are compatible with provider `prepare-request` functions
- Internal metadata is separated from normalized content

### Pipeline Integration

The test design ensures that changes to one pipeline step are caught by downstream tests:

1. **Schema tests** validate normalized format generation
2. **Provider tests** validate transformation of normalized format 
3. **Fixture compatibility** ensures the chain works end-to-end

This prevents regressions like internal fields leaking to providers.

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
3. **Pipeline testing**: Test each layer separately to isolate issues
4. **Schema validation**: Run schema tests when changing internal data structures
5. **Contract enforcement**: Fixture updates should be deliberate, not automatic
6. **CI considerations**: Skip API tests in automated environments unless explicitly enabled
7. **Cost management**: API tests use the cheapest available model
8. **Error diagnosis**: Use verbose mode to inspect actual API responses when debugging

#### Test Layer Commands

```nushell
# Test schema generation layer
use tests/schema/test-schema-generation.nu; test-schema-generation

# Test provider transformation layer  
use tests/providers/test-prepare-request.nu; test-prepare-request anthropic

# Test with real API calls (costs tokens)
use tests/providers/test-prepare-request.nu; test-prepare-request anthropic --call "your-api-key"
```