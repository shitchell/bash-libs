#!/usr/bin/env bash
# Test helper functions for shell library tests

# Track test results
declare -g TESTS_RUN=0
declare -g TESTS_PASSED=0
declare -g TESTS_FAILED=0
declare -g CURRENT_TEST=""

# Colors for test output
if [[ -t 1 ]]; then
    TEST_GREEN=$'\033[32m'
    TEST_RED=$'\033[31m'
    TEST_YELLOW=$'\033[33m'
    TEST_RESET=$'\033[0m'
else
    TEST_GREEN=""
    TEST_RED=""
    TEST_YELLOW=""
    TEST_RESET=""
fi

# Include path setup is handled by the test script

# Basic assertions

assert_equals() {
    local actual="$1"
    local expected="$2"
    local message="${3:-Values should be equal}"

    if [[ "$actual" == "$expected" ]]; then
        pass "$message"
    else
        fail "$message: expected '$expected', got '$actual'"
    fi
}

assert_not_equals() {
    local actual="$1"
    local expected="$2"
    local message="${3:-Values should not be equal}"

    if [[ "$actual" != "$expected" ]]; then
        pass "$message"
    else
        fail "$message: values are equal: '$actual'"
    fi
}

assert_contains() {
    local haystack="$1"
    local needle="$2"
    local message="${3:-Should contain substring}"

    if [[ "$haystack" == *"$needle"* ]]; then
        pass "$message"
    else
        fail "$message: '$haystack' does not contain '$needle'"
    fi
}

assert_not_contains() {
    local haystack="$1"
    local needle="$2"
    local message="${3:-Should not contain substring}"

    if [[ "$haystack" != *"$needle"* ]]; then
        pass "$message"
    else
        fail "$message: '$haystack' contains '$needle'"
    fi
}

assert_empty() {
    local value="$1"
    local message="${2:-Value should be empty}"

    if [[ -z "$value" ]]; then
        pass "$message"
    else
        fail "$message: value is not empty: '$value'"
    fi
}

assert_not_empty() {
    local value="$1"
    local message="${2:-Value should not be empty}"

    if [[ -n "$value" ]]; then
        pass "$message"
    else
        fail "$message: value is empty"
    fi
}

assert_true() {
    local condition="$1"
    local message="${2:-Condition should be true}"

    if eval "$condition"; then
        pass "$message"
    else
        fail "$message: condition is false: $condition"
    fi
}

assert_false() {
    local condition="$1"
    local message="${2:-Condition should be false}"

    if ! eval "$condition"; then
        pass "$message"
    else
        fail "$message: condition is true: $condition"
    fi
}

assert_exit_code() {
    local expected="$1"
    local actual="$2"
    local message="${3:-Exit code should match}"

    if [[ "$actual" -eq "$expected" ]]; then
        pass "$message"
    else
        fail "$message: expected exit code $expected, got $actual"
    fi
}

# Test execution helpers

pass() {
    local message="$1"
    ((TESTS_PASSED++))
    echo "${TEST_GREEN}✓${TEST_RESET} $message"
}

fail() {
    local message="$1"
    ((TESTS_FAILED++))
    echo "${TEST_RED}✗${TEST_RESET} $message"
    if [[ -n "$CURRENT_TEST" ]]; then
        echo "  in test: $CURRENT_TEST"
    fi
}

run_test() {
    local test_name="$1"
    CURRENT_TEST="$test_name"
    ((TESTS_RUN++))

    echo "${TEST_YELLOW}Running $test_name...${TEST_RESET}"

    # Run test function directly (not in subshell to preserve functions)
    local exit_code=0
    "$test_name" || exit_code=$?

    if [[ $exit_code -ne 0 ]]; then
        fail "Test exited with code $exit_code"
    fi

    CURRENT_TEST=""
}

run_tests() {
    echo "Running tests..."
    echo

    # Find all functions starting with test_
    local test_functions=($(declare -F | grep -o 'test_[^ ]*' || true))

    if [[ ${#test_functions[@]} -eq 0 ]]; then
        echo "No test functions found!"
        return 1
    fi

    # Run each test
    for test_func in "${test_functions[@]}"; do
        run_test "$test_func"
    done

    # Summary
    echo
    echo "Test Summary:"
    echo "  Total:  $TESTS_RUN"
    echo "  Passed: ${TEST_GREEN}$TESTS_PASSED${TEST_RESET}"
    echo "  Failed: ${TEST_RED}$TESTS_FAILED${TEST_RESET}"

    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo
        echo "${TEST_GREEN}All tests passed!${TEST_RESET}"
        return 0
    else
        echo
        echo "${TEST_RED}Some tests failed!${TEST_RESET}"
        return 1
    fi
}

# Setup and teardown hooks (can be overridden)
setup() {
    true
}

teardown() {
    true
}