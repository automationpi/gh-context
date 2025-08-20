#!/usr/bin/env bats

load test_helper

setup() {
  setup_test_env
  
  # Mock gh command for tests
  export PATH="$BATS_TMPDIR:$PATH"
  cat > "$BATS_TMPDIR/gh" <<'EOF'
#!/bin/bash
# Mock gh for testing
case "$1" in
  "auth")
    case "$2" in
      "token")
        exit 0  # Always succeed for token checks
        ;;
      "switch")
        echo "✓ Switched to $*"
        exit 0
        ;;
      "setup-git")
        echo "✓ Configured git"
        exit 0
        ;;
      "refresh")
        exit 0  # Always succeed for refresh
        ;;
    esac
    ;;
  "api")
    if [[ "$2" == "user" && "$3" == "--hostname" && "$5" == "--jq" && "$6" == ".login" ]]; then
      echo "testuser"
      exit 0
    elif [[ "$2" == "user" ]]; then
      echo '{"login": "testuser"}'
      exit 0
    fi
    ;;
esac
exit 1
EOF
  chmod +x "$BATS_TMPDIR/gh"
}

teardown() {
  teardown_test_env
  rm -f "$BATS_TMPDIR/gh"
}

@test "displays usage when no arguments" {
  run_gh_context
  assert_success
  assert_output_contains "Usage:"
  assert_output_contains "gh context list"
}

@test "displays usage with --help" {
  run_gh_context --help
  assert_success
  assert_output_contains "gh-context: A kubectx-style context switcher"
}

@test "lists contexts when none exist" {
  run_gh_context list
  assert_success
  assert_output_contains "No contexts found"
}

@test "creates context from current session" {
  run_gh_context new --from-current --name test
  assert_success
  assert_output_contains "Created context 'test'"
  assert context_exists "test"
  
  # Check context file content
  content=$(get_context_content "test")
  [[ "$content" == *"HOSTNAME=github.com"* ]]
  [[ "$content" == *"USER=testuser"* ]]
  [[ "$content" == *"TRANSPORT=ssh"* ]]
}

@test "creates context with explicit parameters" {
  run_gh_context new --hostname example.com --user alice --transport https --name work
  assert_success
  assert_output_contains "Created context 'work'"
  assert context_exists "work"
  
  content=$(get_context_content "work")
  [[ "$content" == *"HOSTNAME=example.com"* ]]
  [[ "$content" == *"USER=alice"* ]]
  [[ "$content" == *"TRANSPORT=https"* ]]
}

@test "rejects invalid context names" {
  run_gh_context new --from-current --name "invalid name"
  assert_failure
  assert_output_contains "invalid characters"
}

@test "rejects duplicate context names" {
  create_mock_context "existing"
  
  run_gh_context new --from-current --name existing
  assert_failure
  assert_output_contains "already exists"
}

@test "lists existing contexts" {
  create_mock_context "context1" "github.com" "user1" "ssh"
  create_mock_context "context2" "example.com" "user2" "https"
  set_active_context "context1"
  
  run_gh_context list
  assert_success
  assert_output_contains "context1 *"
  assert_output_contains "context2"
  assert_output_contains "user1@github.com"
  assert_output_contains "user2@example.com"
}

@test "shows current context when active" {
  create_mock_context "test" "github.com" "testuser" "ssh"
  set_active_context "test"
  
  run_gh_context current
  assert_success
  assert_output_contains "Active: test"
  assert_output_contains "testuser@github.com"
}

@test "shows no active context when none set" {
  run_gh_context current
  assert_success
  assert_output_contains "No active context"
}

@test "switches to existing context" {
  create_mock_context "test" "github.com" "testuser" "ssh"
  
  run_gh_context use test
  assert_success
  assert_output_contains "Now using context 'test'"
  
  active=$(get_active_context)
  [[ "$active" == "test" ]]
}

@test "fails to switch to non-existent context" {
  run_gh_context use nonexistent
  assert_failure
  assert_output_contains "Context 'nonexistent' not found"
}

@test "deletes existing context" {
  create_mock_context "test"
  
  run_gh_context delete test
  assert_success
  assert_output_contains "Deleted context 'test'"
  ! context_exists "test"
}

@test "clears active pointer when deleting active context" {
  create_mock_context "test"
  set_active_context "test"
  
  run_gh_context delete test
  assert_success
  
  active=$(get_active_context)
  [[ -z "$active" ]]
}

@test "fails to delete non-existent context" {
  run_gh_context delete nonexistent
  assert_failure
  assert_output_contains "Context 'nonexistent' not found"
}

@test "binds repo to context" {
  create_mock_context "test"
  cd "$TEST_REPO_DIR"
  
  run_gh_context bind test
  assert_success
  assert_output_contains "Bound repo to context 'test'"
  
  binding=$(get_repo_binding)
  [[ "$binding" == "test" ]]
}

@test "fails to bind non-existent context" {
  cd "$TEST_REPO_DIR"
  
  run_gh_context bind nonexistent
  assert_failure
  assert_output_contains "Context 'nonexistent' not found"
}

@test "fails to bind outside git repo" {
  create_mock_context "test"
  cd "$TEST_DIR"  # Not a git repo
  
  run_gh_context bind test
  assert_failure
  assert_output_contains "Not inside a Git repository"
}

@test "unbinds repo" {
  cd "$TEST_REPO_DIR"
  create_repo_binding "test"
  
  run_gh_context unbind
  assert_success
  assert_output_contains "Removed repo binding"
  
  binding=$(get_repo_binding)
  [[ -z "$binding" ]]
}

@test "unbind when no binding exists" {
  cd "$TEST_REPO_DIR"
  
  run_gh_context unbind
  assert_success
  assert_output_contains "No repo binding found"
}

@test "applies repo binding" {
  create_mock_context "test" "github.com" "testuser" "ssh"
  cd "$TEST_REPO_DIR"
  create_repo_binding "test"
  
  run_gh_context apply
  assert_success
  assert_output_contains "Now using context 'test'"
  
  active=$(get_active_context)
  [[ "$active" == "test" ]]
}

@test "fails to apply when no binding exists" {
  cd "$TEST_REPO_DIR"
  
  run_gh_context apply
  assert_failure
  assert_output_contains "No .ghcontext file found"
}

@test "generates shell hook" {
  run_gh_context shell-hook
  assert_success
  assert_output_contains "gh_context_auto_apply"
  assert_output_contains "PROMPT_COMMAND"
  assert_output_contains "precmd"
}

@test "validates transport parameter" {
  run_gh_context new --hostname example.com --user alice --transport invalid --name test
  assert_failure
  assert_output_contains "Transport must be 'ssh' or 'https'"
}

@test "requires name parameter for new context" {
  run_gh_context new --from-current
  assert_failure
  assert_output_contains "Context name is required"
}

@test "requires either from-current or hostname/user" {
  run_gh_context new --name test
  assert_failure
  assert_output_contains "Provide either --from-current or both --hostname and --user"
}

@test "shows repo binding in current command" {
  create_mock_context "test"
  set_active_context "test"
  cd "$TEST_REPO_DIR"
  create_repo_binding "work"
  
  run_gh_context current
  assert_success
  assert_output_contains "Active: test"
  assert_output_contains "Repo-bound: work"
}

@test "handles missing active context file gracefully" {
  create_mock_context "test"
  set_active_context "nonexistent"
  
  run_gh_context current
  assert_success
  assert_output_contains "Active context 'nonexistent' points to missing file"
}