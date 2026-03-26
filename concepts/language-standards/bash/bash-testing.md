---
title: Bash Testing Patterns
topics:
  - BATS framework
  - mocking
  - test structure
  - CI integration
version_requirements: BATS 1.0+ (bats-core)
---

# Bash Testing Patterns

> BATS framework, mocking strategies, test isolation, and CI integration.

## BATS Framework Setup

```bash
# Install bats-core and helpers
brew install bats-core  # macOS
# or
git clone https://github.com/bats-core/bats-core.git
cd bats-core && ./install.sh /usr/local

# Install helper libraries
git clone https://github.com/bats-core/bats-support.git test/test_helper/bats-support
git clone https://github.com/bats-core/bats-assert.git test/test_helper/bats-assert
git clone https://github.com/bats-core/bats-file.git test/test_helper/bats-file
```

---

## Basic Test Structure

```bash
#!/usr/bin/env bats
# test/my_script.bats

# Load helpers (in setup_file for once-per-file, setup for once-per-test)
setup_file() {
    # Runs once before all tests in file
    export TEST_TEMP_DIR="$(mktemp -d)"
}

teardown_file() {
    # Runs once after all tests in file
    rm -rf "$TEST_TEMP_DIR"
}

setup() {
    # Runs before each test
    load 'test_helper/bats-support/load'
    load 'test_helper/bats-assert/load'

    # Source the script under test (testable script pattern)
    source "${BATS_TEST_DIRNAME}/../src/my_script.sh"
}

teardown() {
    # Runs after each test
    :
}

@test "validate_input accepts valid port" {
    run validate_input "8080"
    assert_success
}

@test "validate_input rejects invalid port" {
    run validate_input "invalid"
    assert_failure
    assert_output --partial "Error"
}

@test "calculate_checksum returns correct hash" {
    echo "test content" > "$TEST_TEMP_DIR/testfile"
    run calculate_checksum "$TEST_TEMP_DIR/testfile"
    assert_success
    # SHA-256 of "test content\n"
    assert_output "d1b2a59fbea7e20077af9f91b27e95e865061b270be03ff539ab3b73587882e8"
}
```

---

## Testable Script Pattern

**Scripts must be sourceable without executing:**

```bash
#!/usr/bin/env bash
set -Eeuo pipefail

# All business logic in functions
validate_port() {
    local port="$1"
    [[ "$port" =~ ^[0-9]+$ ]] && (( port >= 1024 && port <= 65535 ))
}

process_file() {
    local file="$1"
    [[ -f "$file" ]] || return 1
    # ... processing logic
}

main() {
    local port="${1:-8080}"
    validate_port "$port" || {
        echo "Error: Invalid port" >&2
        return 1
    }
    # ... main logic
}

# CRITICAL: Guard execution - allows sourcing for tests
if [[ "${BASH_SOURCE[0]}" = "${0}" ]]; then
    main "$@"
fi
```

**In tests:**
```bash
setup() {
    # Source script WITHOUT executing main
    source "${BATS_TEST_DIRNAME}/../src/server.sh"
}

@test "validate_port accepts 8080" {
    run validate_port 8080
    assert_success
}
```

---

## Mocking Commands

### Simple Mock with Override

```bash
@test "script handles curl failure" {
    # Mock curl to fail
    curl() {
        return 1
    }
    export -f curl

    run fetch_data "https://example.com"
    assert_failure
    assert_output --partial "Failed to fetch"
}

@test "script processes curl output" {
    # Mock curl with specific output
    curl() {
        echo '{"status": "ok"}'
    }
    export -f curl

    run fetch_data "https://example.com"
    assert_success
    assert_output "ok"
}
```

### Mock with Verification

```bash
# Track mock calls
setup() {
    export MOCK_CALLS=""
}

@test "calls API with correct arguments" {
    curl() {
        MOCK_CALLS+="curl $*;"
        echo '{"result": "success"}'
    }
    export -f curl

    run make_api_call "POST" "/users" '{"name": "test"}'
    assert_success

    # Verify curl was called correctly
    [[ "$MOCK_CALLS" == *"curl -X POST"* ]]
    [[ "$MOCK_CALLS" == *"/users"* ]]
}
```

### Using bats-mock (Advanced)

```bash
setup() {
    load 'test_helper/bats-support/load'
    load 'test_helper/bats-assert/load'

    # Create mock
    export DOCKER="$(mock_create)"
    mock_set_output "${DOCKER}" "container_id_123"
}

@test "starts docker container" {
    # Replace docker command
    docker() { "${DOCKER}" "$@"; }
    export -f docker

    run start_container "myimage"
    assert_success

    # Verify mock was called
    assert_equal "$(mock_get_call_num "${DOCKER}")" 1
    assert_equal "$(mock_get_call_args "${DOCKER}" 1)" "run -d myimage"
}
```

---

## Testing Error Conditions

```bash
@test "exits on missing required env var" {
    unset REQUIRED_VAR

    run main
    assert_failure
    assert_output --partial "REQUIRED_VAR"
}

@test "handles file not found" {
    run process_file "/nonexistent/path"
    assert_failure 1  # Specific exit code
    assert_output --partial "not found"
}

@test "handles permission denied" {
    touch "$TEST_TEMP_DIR/restricted"
    chmod 000 "$TEST_TEMP_DIR/restricted"

    run read_file "$TEST_TEMP_DIR/restricted"
    assert_failure
    assert_output --partial "permission"

    chmod 644 "$TEST_TEMP_DIR/restricted"  # Cleanup
}
```

---

## Testing Output and Exit Codes

```bash
@test "outputs to stderr on error" {
    run --separate-stderr process_invalid_input

    assert_failure
    assert_output ""  # Nothing on stdout
    assert_equal "$stderr" "Error: Invalid input"
}

@test "returns specific exit code for specific errors" {
    run process_data "invalid"
    assert_failure 2  # Exit code 2 for validation errors

    run process_data ""
    assert_failure 3  # Exit code 3 for missing input
}

@test "outputs JSON on success" {
    run generate_report
    assert_success
    # Validate JSON structure
    echo "$output" | jq -e '.status == "complete"'
}
```

---

## CI Integration

### GitHub Actions

```yaml
# .github/workflows/test.yml
name: Test
on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Install BATS
        run: |
          git clone --depth 1 https://github.com/bats-core/bats-core.git
          sudo ./bats-core/install.sh /usr/local
          git clone --depth 1 https://github.com/bats-core/bats-support.git test/test_helper/bats-support
          git clone --depth 1 https://github.com/bats-core/bats-assert.git test/test_helper/bats-assert

      - name: Run ShellCheck
        run: shellcheck src/*.sh

      - name: Run Tests
        run: bats test/*.bats --formatter tap

      - name: Run Tests (TAP output for CI)
        run: bats test/*.bats --formatter tap13 > test-results.tap

      - uses: dorny/test-reporter@v1
        if: always()
        with:
          name: BATS Tests
          path: test-results.tap
          reporter: java-junit  # TAP format supported
```

### GitLab CI

```yaml
# .gitlab-ci.yml
test:
  image: bats/bats:latest
  script:
    - shellcheck src/*.sh
    - bats test/*.bats --formatter tap
  artifacts:
    reports:
      junit: test-results.xml
```

### Makefile Integration

```makefile
.PHONY: test lint format

test: lint
	bats test/*.bats

lint:
	shellcheck src/*.sh

format:
	shfmt -w src/*.sh

ci: lint test
	@echo "All checks passed"
```

---

## Test Organization

```
project/
├── src/
│   ├── main.sh
│   └── lib/
│       ├── validation.sh
│       └── utils.sh
├── test/
│   ├── test_helper/
│   │   ├── bats-support/
│   │   ├── bats-assert/
│   │   └── common.bash    # Shared test utilities
│   ├── main.bats
│   ├── validation.bats
│   └── utils.bats
├── .shellcheckrc
└── Makefile
```

### Shared Test Helper

```bash
# test/test_helper/common.bash

# Create temp directory for test artifacts
create_test_dir() {
    TEST_DIR="$(mktemp -d)"
    export TEST_DIR
}

# Clean up test artifacts
cleanup_test_dir() {
    [[ -d "${TEST_DIR:-}" ]] && rm -rf "$TEST_DIR"
}

# Assert file contains pattern
assert_file_contains() {
    local file="$1"
    local pattern="$2"
    grep -q "$pattern" "$file" || {
        echo "Expected '$file' to contain '$pattern'" >&2
        return 1
    }
}

# Skip test on specific platform
skip_if_macos() {
    [[ "$(uname)" == "Darwin" ]] && skip "Test not supported on macOS"
}
```

---

## Quick Reference

| Pattern | Example |
|---------|---------|
| Run function | `run my_function "arg"` |
| Assert success | `assert_success` |
| Assert failure | `assert_failure [exit_code]` |
| Assert output | `assert_output "expected"` |
| Assert partial | `assert_output --partial "substring"` |
| Assert regex | `assert_output --regexp "pattern"` |
| Assert line | `assert_line --index 0 "first line"` |
| Skip test | `skip "reason"` |
| Mock command | `cmd() { echo "mock"; }; export -f cmd` |
| Temp file | `TEST_FILE="$(mktemp)"` |
| Source script | `source script.sh` (with guard) |

---

## Common Pitfalls

1. **Forgetting to export mocked functions**: Use `export -f func_name`
2. **Not using `run`**: Always `run cmd`, not `cmd` directly in tests
3. **Missing guard in scripts**: Scripts execute on source without `BASH_SOURCE` guard
4. **Not cleaning up**: Use `teardown` or `trap` for temp files
5. **Testing implementation, not behavior**: Focus on outputs, not internals
6. **Flaky tests**: Avoid `sleep`, use proper synchronization
