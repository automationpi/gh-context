#!/usr/bin/env bash

# Test helper functions for gh-context

# Set up test environment
setup_test_env() {
  export TEST_DIR="${BATS_TMPDIR}/gh-context-test-$$"
  export TEST_CTX_DIR="$TEST_DIR/.config/gh/contexts"
  export TEST_REPO_DIR="$TEST_DIR/test-repo"
  export GH_CONTEXT_EXECUTABLE="${BATS_TEST_DIRNAME}/../gh-context"
  
  # Override XDG config home for tests
  export XDG_CONFIG_HOME="$TEST_DIR/.config"
  
  mkdir -p "$TEST_CTX_DIR"
  mkdir -p "$TEST_REPO_DIR"
  
  # Initialize test repo
  (cd "$TEST_REPO_DIR" && git init >/dev/null 2>&1)
}

# Clean up test environment
teardown_test_env() {
  [[ -d "$TEST_DIR" ]] && rm -rf "$TEST_DIR"
  unset TEST_DIR TEST_CTX_DIR TEST_REPO_DIR XDG_CONFIG_HOME
}

# Create a mock context file
create_mock_context() {
  local name="$1"
  local hostname="${2:-github.com}"
  local user="${3:-testuser}"
  local transport="${4:-ssh}"
  local ssh_host="${5:-}"
  
  cat > "$TEST_CTX_DIR/$name.ctx" <<EOF
HOSTNAME=$hostname
USER=$user
TRANSPORT=$transport
SSH_HOST_ALIAS=$ssh_host
EOF
}

# Set active context
set_active_context() {
  echo "$1" > "$TEST_CTX_DIR/active"
}

# Create a .ghcontext file in test repo
create_repo_binding() {
  echo "$1" > "$TEST_REPO_DIR/.ghcontext"
}

# Mock gh command for testing
mock_gh() {
  local subcommand="$1"
  shift
  
  case "$subcommand" in
    "auth")
      case "$1" in
        "token")
          # Mock successful token check
          return 0
          ;;
        "switch")
          # Mock successful auth switch
          echo "✓ Switched to $*"
          return 0
          ;;
        "setup-git")
          # Mock successful git setup
          echo "✓ Configured git"
          return 0
          ;;
        "refresh")
          # Mock successful refresh
          return 0
          ;;
        *)
          echo "Unknown gh auth command: $1" >&2
          return 1
          ;;
      esac
      ;;
    "api")
      if [[ "$1" == "user" ]]; then
        # Mock user API response
        echo '{"login": "testuser"}'
        return 0
      fi
      ;;
    *)
      echo "Unknown gh command: $subcommand" >&2
      return 1
      ;;
  esac
}

# Helper to run gh-context with test environment
run_gh_context() {
  run "$GH_CONTEXT_EXECUTABLE" "$@"
}

# Helper to check if context file exists
context_exists() {
  [[ -f "$TEST_CTX_DIR/$1.ctx" ]]
}

# Helper to get context file content
get_context_content() {
  cat "$TEST_CTX_DIR/$1.ctx"
}

# Helper to check active context
get_active_context() {
  [[ -f "$TEST_CTX_DIR/active" ]] && cat "$TEST_CTX_DIR/active" || echo ""
}

# Helper to check repo binding
get_repo_binding() {
  [[ -f "$TEST_REPO_DIR/.ghcontext" ]] && cat "$TEST_REPO_DIR/.ghcontext" || echo ""
}

# Assert helpers
assert() {
  if ! "$@"; then
    echo "Assertion failed: $*"
    return 1
  fi
}

assert_success() {
  if [[ "$status" -ne 0 ]]; then
    echo "Expected success but got status $status"
    echo "Output: $output"
    return 1
  fi
}

assert_failure() {
  if [[ "$status" -eq 0 ]]; then
    echo "Expected failure but got success"
    echo "Output: $output"
    return 1
  fi
}

assert_output_contains() {
  if [[ "$output" != *"$1"* ]]; then
    echo "Expected output to contain '$1'"
    echo "Actual output: $output"
    return 1
  fi
}

assert_output_not_contains() {
  if [[ "$output" == *"$1"* ]]; then
    echo "Expected output to not contain '$1'"
    echo "Actual output: $output"
    return 1
  fi
}