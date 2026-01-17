#!/usr/bin/env bats
# git.bats - Comprehensive tests for git.sh library functions

# Load test helpers and the library being tested
load test_helpers

setup() {
    # Source the library
    source "${BATS_TEST_DIRNAME}/../include.sh"
    include-source 'git.sh'

    # Save original directory
    export ORIGINAL_DIR="$PWD"
}

teardown() {
    # Restore original directory
    cd "$ORIGINAL_DIR"

    # Restore any mocked commands
    restore_command git 2>/dev/null || true
}

#------------------------------------------------------------------------------
# Tests for git-root (git-toplevel)
#------------------------------------------------------------------------------

@test "git-root: returns repository root in git repo" {
    # Setup test repo
    local repo=$(setup_test_repo)
    cd "$repo"

    # Create subdirectory and navigate to it
    mkdir -p sub/dir/deep
    cd sub/dir/deep

    # Execute
    run git-root

    # Assert
    assert_success
    assert_equals "$output" "$repo"
}

@test "git-root: fails when not in git repository" {
    # Create non-git directory
    local tempdir=$(generate_temp_dir)
    cd "$tempdir"

    # Execute
    run git-root

    # Assert
    assert_failure
    assert_contains "$output" "not a git repository"
}

@test "git-root: works with custom path argument" {
    # Setup test repo
    local repo=$(setup_test_repo)

    # Create another temp directory
    local tempdir=$(generate_temp_dir)
    cd "$tempdir"

    # Execute with path to repo
    run git-root "$repo"

    # Assert
    assert_success
    assert_equals "$output" "$repo"
}

@test "git-root: handles paths with spaces" {
    # Create repo with spaces in name
    local repo_name="test repo with spaces"
    local repo_dir=$(generate_temp_dir ".$repo_name")

    cd "$repo_dir"
    git init --quiet
    echo "test" > file.txt
    git add file.txt
    git config user.email "test@example.com"
    git config user.name "Test User"
    git commit --quiet -m "Initial"

    # Execute
    run git-root

    # Assert
    assert_success
    assert_equals "$output" "$repo_dir"
}

#------------------------------------------------------------------------------
# Tests for git-branch-name
#------------------------------------------------------------------------------

@test "git-branch-name: returns current branch name" {
    # Setup test repo
    local repo=$(setup_test_repo)
    cd "$repo"

    # Create and checkout a branch
    git checkout -b feature/test-branch --quiet

    # Execute
    run git-branch-name

    # Assert
    assert_success
    assert_equals "$output" "feature/test-branch"
}

@test "git-branch-name: returns master/main on default branch" {
    # Setup test repo
    local repo=$(setup_test_repo)
    cd "$repo"

    # Get the default branch name (could be master or main)
    local default_branch=$(git symbolic-ref --short HEAD)

    # Execute
    run git-branch-name

    # Assert
    assert_success
    assert_equals "$output" "$default_branch"
}

@test "git-branch-name: handles detached HEAD with name option" {
    # Setup test repo
    local repo=$(setup_test_repo)
    cd "$repo"

    # Create a tag and checkout (creates detached HEAD)
    git tag v1.0.0
    git checkout v1.0.0 --quiet 2>/dev/null

    # Execute with name option
    run git-branch-name --detached-name

    # Assert
    assert_success
    # Output should contain tag name without commit suffix
    assert_contains "$output" "v1.0.0"
}

@test "git-branch-name: handles detached HEAD with commit option" {
    # Setup test repo
    local repo=$(setup_test_repo)
    cd "$repo"

    # Get current commit hash
    local commit=$(git rev-parse --short HEAD)

    # Checkout commit directly (detached HEAD)
    git checkout "$commit" --quiet 2>/dev/null

    # Execute with commit option
    run git-branch-name --detached-commit

    # Assert
    assert_success
    assert_equals "$output" "$commit"
}

@test "git-branch-name: handles detached HEAD with both option" {
    # Setup test repo
    local repo=$(setup_test_repo)
    cd "$repo"

    # Create a tag and checkout
    git tag v2.0.0
    git checkout v2.0.0 --quiet 2>/dev/null

    # Execute with both option
    run git-branch-name --detached-both

    # Assert
    assert_success
    assert_contains "$output" "v2.0.0"
    assert_contains "$output" ":"
}

@test "git-branch-name: shows help with -h flag" {
    # Execute
    run git-branch-name -h

    # Assert
    assert_success
    assert_contains "$output" "usage:"
}

#------------------------------------------------------------------------------
# Tests for git-remote-tracking-branch
#------------------------------------------------------------------------------

@test "git-remote-tracking-branch: returns remote branch for tracking branch" {
    # Mock git commands
    mock_function "git rev-parse --symbolic-full-name HEAD" 'echo "refs/heads/main"'
    mock_function "git for-each-ref --format='%(upstream:short)' refs/heads/main" 'echo "origin/main"'

    # Execute
    run git-remote-tracking-branch

    # Assert
    assert_success
    assert_equals "$output" "origin/main"
}

@test "git-remote-tracking-branch: returns empty for non-tracking branch" {
    # Mock git commands
    mock_function "git rev-parse --symbolic-full-name HEAD" 'echo "refs/heads/feature"'
    mock_function "git for-each-ref --format='%(upstream:short)' refs/heads/feature" 'echo ""'

    # Execute
    run git-remote-tracking-branch

    # Assert
    assert_failure
    assert_empty "$output"
}

@test "git-remote-tracking-branch: handles detached HEAD" {
    # Mock git command to simulate detached HEAD
    mock_function "git rev-parse --symbolic-full-name HEAD" 'echo "HEAD"; return 0'

    # Execute
    run git-remote-tracking-branch

    # Assert
    assert_failure
    assert_empty "$output"
}

@test "git-remote-tracking-branch: works with branch argument" {
    # Mock git commands
    mock_function "git rev-parse --symbolic-full-name develop" 'echo "refs/heads/develop"'
    mock_function "git for-each-ref --format='%(upstream:short)' refs/heads/develop" 'echo "origin/develop"'

    # Execute
    run git-remote-tracking-branch develop

    # Assert
    assert_success
    assert_equals "$output" "origin/develop"
}

#------------------------------------------------------------------------------
# Tests for git-latest-tag
#------------------------------------------------------------------------------

@test "git-latest-tag: returns latest tag from current branch" {
    # Setup test repo
    local repo=$(setup_test_repo)
    cd "$repo"

    # Create some tags
    echo "v1" > file.txt && git add file.txt && git commit -m "v1" --quiet
    git tag v1.0.0

    echo "v2" > file.txt && git add file.txt && git commit -m "v2" --quiet
    git tag v2.0.0

    # Execute
    run git-latest-tag

    # Assert
    assert_success
    assert_equals "$output" "v2.0.0"
}

@test "git-latest-tag: returns all tags with --all option" {
    # Setup test repo
    local repo=$(setup_test_repo)
    cd "$repo"

    # Create tags on different branches
    git tag v1.0.0
    git checkout -b feature --quiet
    echo "feature" > feature.txt && git add feature.txt && git commit -m "feature" --quiet
    git tag v2.0.0-beta

    # Execute
    run git-latest-tag --all

    # Assert
    assert_success
    # Should return the most recent tag
    assert_contains "$output" "v2.0.0-beta"
}

@test "git-latest-tag: returns multiple tags with count option" {
    # Setup test repo
    local repo=$(setup_test_repo)
    cd "$repo"

    # Create multiple tags
    git tag v1.0.0
    echo "v2" > file.txt && git add file.txt && git commit -m "v2" --quiet
    git tag v2.0.0
    echo "v3" > file.txt && git add file.txt && git commit -m "v3" --quiet
    git tag v3.0.0

    # Execute
    run git-latest-tag --all --count 2

    # Assert
    assert_success
    local line_count=$(echo "$output" | wc -l)
    assert_equals "$line_count" "2"
}

@test "git-latest-tag: works with specific commit" {
    # Setup test repo
    local repo=$(setup_test_repo)
    cd "$repo"

    # Create tags
    git tag v1.0.0
    local first_commit=$(git rev-parse HEAD)

    echo "v2" > file.txt && git add file.txt && git commit -m "v2" --quiet
    git tag v2.0.0

    # Execute - get latest tag from first commit
    run git-latest-tag "$first_commit"

    # Assert
    assert_success
    assert_equals "$output" "v1.0.0"
}

#------------------------------------------------------------------------------
# Tests for functions that might not exist (git-is-clean, git-remote-branches, git-local-branches)
#------------------------------------------------------------------------------

@test "git-is-clean: check if implemented" {
    # Check if function exists
    if ! declare -f git-is-clean >/dev/null 2>&1; then
        skip "git-is-clean is not implemented"
    fi

    # If it exists, test it
    local repo=$(setup_test_repo)
    cd "$repo"

    # Should be clean initially
    run git-is-clean
    assert_success

    # Make it dirty
    echo "changes" > file.txt
    run git-is-clean
    assert_failure
}

@test "git-remote-branches: check if implemented" {
    # Check if function exists
    if ! declare -f git-remote-branches >/dev/null 2>&1; then
        skip "git-remote-branches is not implemented"
    fi

    # If it exists, test it
    mock_command "git" 0 "origin/main
origin/develop
origin/feature/test"

    run git-remote-branches
    assert_success
    assert_contains "$output" "origin/main"
    assert_contains "$output" "origin/develop"
}

@test "git-local-branches: check if implemented" {
    # Check if function exists
    if ! declare -f git-local-branches >/dev/null 2>&1; then
        skip "git-local-branches is not implemented"
    fi

    # If it exists, test it
    local repo=$(setup_test_repo)
    cd "$repo"

    # Create some branches
    git branch feature
    git branch develop

    run git-local-branches
    assert_success
    assert_contains "$output" "feature"
    assert_contains "$output" "develop"
}

#------------------------------------------------------------------------------
# Error handling tests
#------------------------------------------------------------------------------

@test "git functions handle missing git command gracefully" {
    # Mock git to simulate it's not installed
    mock_command "git" 127

    # Test git-root
    run git-root
    assert_failure

    # Test git-branch-name
    run git-branch-name
    assert_failure
}

@test "git functions handle corrupted git repo" {
    # Create a directory that looks like git repo but is corrupted
    local tempdir=$(generate_temp_dir)
    cd "$tempdir"
    mkdir .git
    echo "corrupted" > .git/HEAD

    # These should handle the corruption gracefully
    run git-root
    assert_failure

    run git-branch-name
    # Should either fail or return HEAD
    if [[ $status -eq 0 ]]; then
        assert_equals "$output" "HEAD"
    else
        assert_failure
    fi
}

#------------------------------------------------------------------------------
# Integration tests
#------------------------------------------------------------------------------

@test "git functions work together in typical workflow" {
    # Setup test repo
    local repo=$(setup_test_repo)
    cd "$repo"

    # Create and checkout feature branch
    git checkout -b feature/new-feature --quiet

    # Verify we can get repo root
    run git-root
    assert_success
    local repo_root="$output"

    # Verify we can get branch name
    run git-branch-name
    assert_success
    assert_equals "$output" "feature/new-feature"

    # Create a tag
    git tag v1.0.0-alpha

    # Verify we can get latest tag
    run git-latest-tag
    assert_success
    assert_equals "$output" "v1.0.0-alpha"

    # Navigate to subdirectory and verify git-root still works
    mkdir -p src/lib
    cd src/lib
    run git-root
    assert_success
    assert_equals "$output" "$repo_root"
}

@test "git functions handle special characters in branch names" {
    # Setup test repo
    local repo=$(setup_test_repo)
    cd "$repo"

    # Create branch with special characters
    git checkout -b "feature/test-#123-@special" --quiet

    # Execute
    run git-branch-name

    # Assert
    assert_success
    assert_equals "$output" "feature/test-#123-@special"
}

@test "git functions handle unicode in paths and branches" {
    # Skip if system doesn't support unicode well
    if ! locale | grep -q "UTF-8"; then
        skip "System doesn't support UTF-8"
    fi

    # Setup test repo
    local repo=$(setup_test_repo)
    cd "$repo"

    # Create branch with unicode
    git checkout -b "feature/测试-分支" --quiet 2>/dev/null || \
        skip "Git doesn't support unicode branches"

    # Execute
    run git-branch-name

    # Assert
    assert_success
    assert_equals "$output" "feature/测试-分支"
}