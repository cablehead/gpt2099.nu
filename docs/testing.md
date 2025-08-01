# Testing

## Running Tests

```nushell
# All tests
nu -c 'use tests/run.nu ; run'

# Individual suites
nu -c 'use tests/unit/util.nu ; util'
nu -c 'use tests/providers/test-prepare-request.nu ; test-prepare-request anthropic'

# With real API calls (costs tokens)
nu -c 'use tests/providers/test-prepare-request.nu ; test-prepare-request anthropic --call "api-key"'
```

## Test Structure

```
tests/
├── run.nu                      # Complete suite
├── unit/                       # Fast isolated tests
├── schema/                     # Schema validation
├── providers/                  # Provider transformations
├── end-to-end/                 # Real API integration
└── fixtures/                   # Test data
    ├── assets/                 # Binary files (PDF, images)
    └── prepare-request/        # Provider test cases
```

## Test Levels

- **Unit**: Pure functions, no dependencies
- **Schema**: Normalized format validation  
- **Provider**: Fixture-based transformation tests (+ optional API smoke tests)
- **End-to-end**: Full pipeline with real API calls

## Adding Tests

### New Provider Test Case
```bash
mkdir tests/fixtures/prepare-request/new-case/
echo '{"messages": [...], "options": {...}}' > tests/fixtures/prepare-request/new-case/input.json
echo '{...}' > tests/fixtures/prepare-request/new-case/expected-anthropic.json
echo 'Error message' > tests/fixtures/prepare-request/new-case/expected-gemini.err  # For unsupported features
```

### New Provider Support
```bash
echo '{}' > tests/fixtures/prepare-request/existing-case/expected-newprovider.json
# Repeat for all test cases
```

### Binary Assets
- Add files to `tests/fixtures/assets/`
- Reference in const `assets` in `tests/providers/test-prepare-request.nu`
- Test runner auto-populates fixtures with base64 data

## Output Format

All tests use standardized output:
```
- test-name
- ok
```

Failed tests show error details, warnings show skip reasons.