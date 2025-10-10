# Testing

## Running Tests

```nushell
# All tests
nu tests/run.nu

# Individual test suites
nu tests/run.nu unit
nu tests/run.nu providers
nu tests/run.nu integration

# Specific provider tests
nu tests/providers/prepare-request.nu anthropic
nu tests/providers/response-stream.nu openai

# Integration tests (with store)
nu -c 'use xs.nu *; use tests/integration/integration.nu; integration'

# With real API calls (costs tokens)
nu tests/providers/prepare-request.nu anthropic --call "api-key"
nu tests/providers/prepare-request.nu anthropic --call {|p| $env.($"($p | str upcase)_API_KEY")}
```

## Test Structure

```
tests/
├── run.nu                      # Complete suite runner
├── unit/                       # Pure function tests
│   └── util.nu
├── providers/                  # Provider transformation tests
│   ├── prepare-request.nu      # Request transformation
│   └── response-stream.nu      # Streaming response processing
├── integration/                # Full pipeline tests
│   └── integration.nu
├── utils/                      # Test utilities (not runnable)
│   ├── output.nu               # Test output formatting
│   ├── test-mcp-server.nu      # MCP test server
│   └── generate-expected-outputs.nu
└── fixtures/
    ├── providers/
    │   ├── prepare-request/    # Request transformation fixtures
    │   ├── response-stream/    # Captured API responses
    │   └── tools/              # MCP tool definitions
    ├── unit/                   # Unit test fixtures
    └── assets/                 # Binary files (PDF, images)
```

## Provider Tests

### prepare-request

Tests input transformation for each provider's API format. Compares transformed requests against expected fixtures.

```bash
# Run all prepare-request tests for a provider
nu tests/providers/prepare-request.nu anthropic

# Run single test case
nu tests/providers/prepare-request.nu gemini document-image

# Smoke test with real API (costs tokens)
nu tests/providers/prepare-request.nu openai --call $env.OPENAI_API_KEY
```

### response-stream

Tests streaming response processing (aggregate and streamer methods). Uses captured API responses for deterministic playback.

```bash
# Run all response-stream tests for a provider
nu tests/providers/response-stream.nu anthropic

# Test only aggregate or streamer
nu tests/providers/response-stream.nu gemini --aggregate
nu tests/providers/response-stream.nu openai --streamer
```

### Capture & Playback Workflow

To add streaming tests for new cases:

```bash
# 1. Capture real API responses
nu tests/providers/prepare-request.nu anthropic tool-use --call $env.ANTHROPIC_API_KEY --capture

# 2. Generate expected outputs
nu tests/utils/generate-expected-outputs.nu anthropic tool-use

# 3. Run playback tests
nu tests/providers/response-stream.nu anthropic tool-use
```

This saves raw streaming events to `tests/fixtures/providers/response-stream/{provider}/{case}/events.jsonl` and generates expected outputs for both aggregate and streamer methods.

## Adding Tests

### New prepare-request Case

```bash
mkdir tests/fixtures/providers/prepare-request/new-case/
echo '{"messages": [...], "options": {...}}' > tests/fixtures/providers/prepare-request/new-case/input.json
echo '{...}' > tests/fixtures/providers/prepare-request/new-case/expected-anthropic.json
echo 'Error message' > tests/fixtures/providers/prepare-request/new-case/expected-gemini.err
```

### New Provider Support

For each existing test case, create expected output:

```bash
# For supported features
echo '{...}' > tests/fixtures/providers/prepare-request/{case}/expected-newprovider.json

# For unsupported features
echo 'Error message' > tests/fixtures/providers/prepare-request/{case}/expected-newprovider.err
```

Then capture and generate streaming fixtures:

```bash
for case in cache-control document-image system-message tool-use; do
  nu tests/providers/prepare-request.nu newprovider $case --call $api_key --capture
  nu tests/utils/generate-expected-outputs.nu newprovider $case
done
```

### Binary Assets

- Add files to `tests/fixtures/assets/`
- Reference in `assets` const in `tests/providers/prepare-request.nu`
- Test runner auto-populates `data` fields with base64-encoded content
