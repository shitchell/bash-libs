#!/usr/bin/env bats
# shell.bats - Comprehensive tests for shell.sh library functions

# Setup and teardown
setup() {
    # Source the test helpers
    source "${BATS_TEST_DIRNAME}/test_helpers.bash"

    # Source the shell library
    source "${BATS_TEST_DIRNAME}/../shell.sh"

    # Create temp directory for test files
    export TEST_TEMP_DIR=$(generate_temp_dir)
}

teardown() {
    # Clean up any mock functions
    restore_command ps 2>/dev/null || true
    restore_command basename 2>/dev/null || true

    # Clean up temp directory
    [[ -d "$TEST_TEMP_DIR" ]] && rm -rf "$TEST_TEMP_DIR"
}

#------------------------------------------------------------------------------
# Tests for get-shell()
#------------------------------------------------------------------------------

@test "get-shell: returns current shell name in lowercase" {
    # This test depends on the actual shell running the test
    run get-shell
    assert_success
    assert_not_empty "$output"
    # Output should be lowercase
    assert_matches "$output" "^[a-z]+$"
}

@test "get-shell: handles bash shell" {
    # Mock ps to return bash
    mock_command "ps" 0 "/bin/bash"
    mock_command "basename" 0 "bash"

    run get-shell
    assert_success
    assert_equals "$output" "bash"
}

@test "get-shell: handles shells with leading dash" {
    # Mock ps to return shell with leading dash (login shell)
    mock_command "ps" 0 "-bash"
    mock_command "basename" 0 "-bash"

    run get-shell
    assert_success
    assert_equals "$output" "bash"
}

#------------------------------------------------------------------------------
# Tests for functionname()
#------------------------------------------------------------------------------

@test "functionname: returns current function name in bash" {
    # Mock get-shell to return bash
    mock_function "get-shell" 'echo "bash"'

    test_function() {
        functionname
    }

    run test_function
    assert_success
    assert_equals "$output" "test_function"
}

@test "functionname: returns calling function with index" {
    # Mock get-shell to return bash
    mock_function "get-shell" 'echo "bash"'

    outer_function() {
        inner_function
    }

    inner_function() {
        functionname 2  # Get the caller's name
    }

    run outer_function
    assert_success
    assert_equals "$output" "outer_function"
}

@test "functionname: fails for unknown shell" {
    # Mock get-shell to return unknown shell
    mock_function "get-shell" 'echo "unknown"'

    test_function() {
        functionname
    }

    run test_function
    assert_failure
    assert_contains "$output" "unknown shell: unknown"
}

#------------------------------------------------------------------------------
# Tests for in-array()
#------------------------------------------------------------------------------

@test "in-array: finds item in array" {
    local array=("apple" "banana" "cherry")

    run in-array "banana" "${array[@]}"
    assert_success
}

@test "in-array: returns failure when item not in array" {
    local array=("apple" "banana" "cherry")

    run in-array "grape" "${array[@]}"
    assert_failure
}

@test "in-array: handles empty array" {
    local array=()

    run in-array "test" "${array[@]}"
    assert_failure
}

@test "in-array: handles array with spaces in elements" {
    local array=("hello world" "foo bar" "test string")

    run in-array "foo bar" "${array[@]}"
    assert_success
}

@test "in-array: handles special characters" {
    local array=('$test' '*wild*' '[bracket]')

    run in-array '$test' "${array[@]}"
    assert_success
}

#------------------------------------------------------------------------------
# Tests for get-var()
#------------------------------------------------------------------------------

@test "get-var: returns variable value by name" {
    local TEST_VAR="hello world"

    run get-var "TEST_VAR"
    assert_success
    assert_equals "$output" "hello world"
}

@test "get-var: handles unset variables" {
    unset NONEXISTENT_VAR

    run get-var "NONEXISTENT_VAR"
    assert_success
    assert_empty "$output"
}

@test "get-var: handles variables with special characters" {
    local "VAR_WITH-DASH"="dash-value"
    local "VAR_WITH_UNDERSCORE"="underscore-value"

    run get-var "VAR_WITH-DASH"
    assert_success
    assert_equals "$output" "dash-value"

    run get-var "VAR_WITH_UNDERSCORE"
    assert_success
    assert_equals "$output" "underscore-value"
}

@test "get-var: handles empty variable names" {
    run get-var ""
    assert_success
    assert_empty "$output"
}

#------------------------------------------------------------------------------
# Tests for truthy()
#------------------------------------------------------------------------------

@test "truthy: returns true for non-empty strings" {
    run truthy "hello"
    assert_success

    run truthy "1"
    assert_success

    run truthy "true"
    assert_success
}

@test "truthy: returns false for falsy values" {
    run truthy ""
    assert_failure

    run truthy "false"
    assert_failure

    run truthy "0"
    assert_failure
}

@test "truthy: verbose mode outputs true/false" {
    run truthy --verbose "hello"
    assert_success
    assert_equals "$output" "true"

    run truthy --verbose ""
    assert_failure
    assert_equals "$output" "false"
}

@test "truthy: handles variable names with --varname" {
    local TEST_TRUE="hello"
    local TEST_FALSE=""

    run truthy --varname "TEST_TRUE"
    assert_success

    run truthy --varname "TEST_FALSE"
    assert_failure
}

@test "truthy: handles arrays with --varname" {
    local -a EMPTY_ARRAY=()
    local -a FULL_ARRAY=("item1" "item2")

    run truthy --varname "EMPTY_ARRAY"
    assert_failure

    run truthy --varname "FULL_ARRAY"
    assert_success
}

#------------------------------------------------------------------------------
# Tests for require()
#------------------------------------------------------------------------------

@test "require: checks for required commands" {
    # Test with existing command
    run require "bash"
    assert_success

    # Test with non-existing command
    run require --no-exit "nonexistent_command_xyz"
    assert_failure
    assert_contains "$output" "missing required command: 'nonexistent_command_xyz'"
}

@test "require: handles optional dependencies" {
    run require --optional "nonexistent_optional_cmd" --quiet --no-exit
    assert_success
}

@test "require: checks one-of dependencies" {
    # At least one of these should exist
    run require --one-of shell="bash sh zsh fish_xyz" --no-exit
    assert_success

    # None of these should exist
    run require --one-of missing="cmd1_xyz cmd2_xyz cmd3_xyz" --no-exit
    assert_failure
    assert_contains "$output" "missing 'missing': cmd1_xyz cmd2_xyz cmd3_xyz"
}

@test "require: checks variable values" {
    local TEST_VAR="correct"

    run require --variable-value TEST_VAR="correct" --no-exit
    assert_success

    run require --variable-value TEST_VAR="wrong" --no-exit
    assert_failure
    assert_contains "$output" "variable 'TEST_VAR' is set to 'correct', not 'wrong'"
}

@test "require: checks if variables are set" {
    local SET_VAR="value"
    unset UNSET_VAR

    run require --is-set SET_VAR --no-exit
    assert_success

    run require --is-set UNSET_VAR --no-exit
    assert_failure
    assert_contains "$output" "variable 'UNSET_VAR' must be set"
}

#------------------------------------------------------------------------------
# Tests for index-of()
#------------------------------------------------------------------------------

@test "index-of: finds index of item in array" {
    local array=("apple" "banana" "cherry")

    run index-of "banana" "${array[@]}"
    assert_success
    assert_equals "$output" "1"
}

@test "index-of: returns failure when item not found" {
    local array=("apple" "banana" "cherry")

    run index-of "grape" "${array[@]}"
    assert_failure
    assert_equals "$output" "3"  # Returns length when not found
}

@test "index-of: handles empty array" {
    local array=()

    run index-of "test" "${array[@]}"
    assert_failure
    assert_equals "$output" "0"
}

@test "index-of: finds first occurrence" {
    local array=("apple" "banana" "apple" "cherry")

    run index-of "apple" "${array[@]}"
    assert_success
    assert_equals "$output" "0"
}

#------------------------------------------------------------------------------
# Tests for catch()
#------------------------------------------------------------------------------

@test "catch: captures stdout and stderr" {
    test_command() {
        echo "stdout message"
        echo "stderr message" >&2
        return 42
    }

    local stdout stderr
    catch stdout stderr test_command
    local exit_code=$?

    assert_equals "$stdout" "stdout message"
    assert_equals "$stderr" "stderr message"
    assert_equals "$exit_code" "42"
}

@test "catch: handles commands with arguments" {
    local stdout stderr
    catch stdout stderr echo "hello world"

    assert_equals "$stdout" "hello world"
    assert_empty "$stderr"
}

@test "catch: preserves exit codes" {
    local stdout stderr

    # Success case
    catch stdout stderr true
    assert_equals "$?" "0"

    # Failure case
    catch stdout stderr false
    assert_equals "$?" "1"
}

#------------------------------------------------------------------------------
# Tests for first-value()
#------------------------------------------------------------------------------

@test "first-value: returns first non-empty value" {
    run first-value "" "" "third" "fourth"
    assert_success
    assert_equals "$output" "third"
}

@test "first-value: returns failure when all values empty" {
    run first-value "" "" ""
    assert_failure
    assert_empty "$output"
}

@test "first-value: handles single non-empty value" {
    run first-value "only"
    assert_success
    assert_equals "$output" "only"
}

@test "first-value: handles zero as non-empty" {
    run first-value "" "0" "other"
    assert_success
    assert_equals "$output" "0"
}

@test "first-value: handles special characters" {
    run first-value "" '$special' "*wild*"
    assert_success
    assert_equals "$output" '$special'
}

#------------------------------------------------------------------------------
# Additional edge case tests
#------------------------------------------------------------------------------

@test "in-array: handles array elements with newlines" {
    local array=($'first\nline' "normal" $'multi\nline\ntext')

    run in-array $'first\nline' "${array[@]}"
    assert_success
}

@test "get-var: handles variable names with equals signs" {
    # This should fail as bash doesn't allow = in variable names
    run get-var "VAR=WITH=EQUALS"
    assert_success
    assert_empty "$output"
}

@test "truthy: handles integer variables" {
    local -i INT_ZERO=0
    local -i INT_POSITIVE=42
    local -i INT_NEGATIVE=-5

    run truthy --varname --verbose "INT_ZERO"
    assert_failure
    assert_equals "$output" "false"

    run truthy --varname --verbose "INT_POSITIVE"
    assert_success
    assert_equals "$output" "true"

    run truthy --varname --verbose "INT_NEGATIVE"
    assert_success
    assert_equals "$output" "true"
}

@test "require: handles read/write permission checks" {
    local test_file=$(generate_temp_file)
    local test_dir=$(generate_temp_dir)

    # Should succeed for existing file/dir
    run require --read "$test_file" --no-exit
    assert_success

    run require --write "$test_dir" --no-exit
    assert_success

    # Should fail for non-existent
    run require --read "/nonexistent/file" --no-exit
    assert_failure
    assert_contains "$output" "must have read permissions"
}

@test "index-of: handles arrays with duplicate empty strings" {
    local array=("" "item" "" "")

    run index-of "" "${array[@]}"
    assert_success
    assert_equals "$output" "0"  # First empty string at index 0
}

@test "catch: handles commands that produce no output" {
    local stdout stderr
    catch stdout stderr true

    assert_empty "$stdout"
    assert_empty "$stderr"
}

@test "first-value: handles mix of whitespace" {
    run first-value "   " $'\t' $'\n' "actual"
    assert_success
    assert_equals "$output" "   "  # Space is non-empty
}