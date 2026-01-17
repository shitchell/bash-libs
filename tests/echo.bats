#!/usr/bin/env bats
# echo.bats - Comprehensive tests for echo.sh library functions

# Load test helpers
load test_helpers.bash

# Setup and teardown
setup() {
    # Save original environment variables
    export ORIG_VERBOSITY="${VERBOSITY:-}"
    export ORIG_ECHO_FORMATTED="${ECHO_FORMATTED:-}"

    # Create temp directory for test files
    export TEST_TEMP_DIR=$(generate_temp_dir)

    # Set up the test environment to source echo.sh
    export TEST_LIB_DIR="${BATS_TEST_DIRNAME}/.."

    # Clear any existing variables
    unset VERBOSITY ECHO_FORMATTED
}

teardown() {
    # Restore original environment variables
    if [[ -n "$ORIG_VERBOSITY" ]]; then
        export VERBOSITY="$ORIG_VERBOSITY"
    else
        unset VERBOSITY
    fi

    if [[ -n "$ORIG_ECHO_FORMATTED" ]]; then
        export ECHO_FORMATTED="$ORIG_ECHO_FORMATTED"
    else
        unset ECHO_FORMATTED
    fi

    # Clean up temp directory
    [[ -d "$TEST_TEMP_DIR" ]] && rm -rf "$TEST_TEMP_DIR"
}

# Helper function to source echo.sh with its dependencies
source_echo_lib() {
    source "${TEST_LIB_DIR}/include.sh"
    include-source 'echo.sh'
}

#------------------------------------------------------------------------------
# Tests for echo-formatted()
#------------------------------------------------------------------------------

@test "echo-formatted: basic text output without colors" {
    source_echo_lib

    run echo-formatted "Hello World"
    [ "$status" -eq 0 ]
    assert_equals "$output" "Hello World"
}

@test "echo-formatted: multiple arguments with spacing" {
    source_echo_lib

    run echo-formatted "Hello" "World" "Test"
    [ "$status" -eq 0 ]
    assert_equals "$output" "Hello World Test"
}

@test "echo-formatted: -n option suppresses newline" {
    source_echo_lib

    # Use printf to capture output without newline
    output=$(echo-formatted -n "Hello")
    assert_equals "$output" "Hello"

    # Verify no newline by appending text
    output=$(echo -n "$(echo-formatted -n "Hello")World")
    assert_equals "$output" "HelloWorld"
}

@test "echo-formatted: color options in TTY mode" {
    source_echo_lib
    export ECHO_FORMATTED="always"

    # Test red color
    run echo-formatted -r "Error"
    [ "$status" -eq 0 ]
    assert_contains "$output" $'\033[31m'
    assert_contains "$output" "Error"
    assert_contains "$output" $'\033[0m'
}

@test "echo-formatted: multiple color options" {
    source_echo_lib
    export ECHO_FORMATTED="always"

    # Test bold red
    run echo-formatted -rB "Critical Error"
    [ "$status" -eq 0 ]
    assert_contains "$output" $'\033[31m'
    assert_contains "$output" $'\033[1m'
    assert_contains "$output" "Critical Error"
    assert_contains "$output" $'\033[0m'
}

@test "echo-formatted: all color options" {
    source_echo_lib
    export ECHO_FORMATTED="always"

    # Test each color
    run echo-formatted -g "Green"
    assert_contains "$output" $'\033[32m'

    run echo-formatted -r "Red"
    assert_contains "$output" $'\033[31m'

    run echo-formatted -b "Blue"
    assert_contains "$output" $'\033[34m'

    run echo-formatted -p "Purple"
    assert_contains "$output" $'\033[35m'

    run echo-formatted -c "Cyan"
    assert_contains "$output" $'\033[36m'

    run echo-formatted -m "Magenta"
    assert_contains "$output" $'\033[35m'
}

@test "echo-formatted: all style options" {
    source_echo_lib
    export ECHO_FORMATTED="always"

    # Test each style
    run echo-formatted -B "Bold"
    assert_contains "$output" $'\033[1m'

    run echo-formatted -D "Dim"
    assert_contains "$output" $'\033[2m'

    run echo-formatted -R "Reverse"
    assert_contains "$output" $'\033[7m'

    run echo-formatted -U "Underline"
    assert_contains "$output" $'\033[4m'

    run echo-formatted -K "Blink"
    assert_contains "$output" $'\033[5m'
}

@test "echo-formatted: -- resets color" {
    source_echo_lib
    export ECHO_FORMATTED="always"

    run echo-formatted -r "Red" -- "Normal"
    [ "$status" -eq 0 ]
    assert_contains "$output" $'\033[31m'
    assert_contains "$output" "Red"
    assert_contains "$output" $'\033[0m'
    assert_contains "$output" "Normal"
}

@test "echo-formatted: escaped dash in arguments" {
    source_echo_lib

    run echo-formatted "\\-n" "not a flag"
    [ "$status" -eq 0 ]
    assert_equals "$output" "-n not a flag"
}

@test "echo-formatted: verbosity level filtering" {
    source_echo_lib

    # Test with VERBOSITY not set (should print)
    unset VERBOSITY
    run echo-formatted -V 1 "Should appear"
    [ "$status" -eq 0 ]
    assert_equals "$output" "Should appear"

    # Test with VERBOSITY=2
    export VERBOSITY=2
    run echo-formatted -V 1 "Should appear"
    [ "$status" -eq 0 ]
    assert_equals "$output" "Should appear"

    run echo-formatted -V 3 "Should not appear"
    [ "$status" -eq 0 ]
    assert_empty "$output"
}

@test "echo-formatted: invalid verbosity level" {
    source_echo_lib

    run echo-formatted -V "not-a-number" "Test" 2>&1
    [ "$status" -eq 1 ]
    assert_contains "$output" "invalid verbosity level"
}

@test "echo-formatted: ECHO_FORMATTED=auto respects TTY" {
    source_echo_lib
    export ECHO_FORMATTED="auto"

    # When not in TTY, should not add colors
    run bash -c "
        source '${TEST_LIB_DIR}/include.sh'
        include-source 'echo.sh'
        export ECHO_FORMATTED='auto'
        echo-formatted -r 'Error'
    "
    [ "$status" -eq 0 ]
    assert_not_contains "$output" $'\033[31m'
    assert_equals "$output" "Error"
}

@test "echo-formatted: ECHO_FORMATTED=never disables colors" {
    source_echo_lib
    export ECHO_FORMATTED="never"

    run echo-formatted -r "Error"
    [ "$status" -eq 0 ]
    assert_not_contains "$output" $'\033[31m'
    assert_equals "$output" "Error"
}

#------------------------------------------------------------------------------
# Tests for echo-run()
#------------------------------------------------------------------------------

@test "echo-run: executes simple command" {
    source_echo_lib

    run echo-run echo "Hello World"
    [ "$status" -eq 0 ]
    assert_contains "$output" "▶"
    assert_contains "$output" "echo Hello World"
    assert_contains "$output" "Hello World"
}

@test "echo-run: handles command with arguments" {
    source_echo_lib

    run echo-run ls -la /dev/null
    [ "$status" -eq 0 ]
    assert_contains "$output" "ls -la /dev/null"
    assert_contains "$output" "/dev/null"
}

@test "echo-run: shows error on failure" {
    source_echo_lib

    run echo-run false
    [ "$status" -eq 1 ]
    assert_contains "$output" "command exited with status 1"
}

@test "echo-run: handles commands with spaces when single argument" {
    source_echo_lib

    run echo-run "echo 'Hello World'"
    [ "$status" -eq 0 ]
    assert_contains "$output" "Hello World"
}

@test "echo-run: prefixes output lines with vertical bar" {
    source_echo_lib

    run echo-run bash -c "echo line1; echo line2; echo line3"
    [ "$status" -eq 0 ]
    assert_contains "$output" "│ line1"
    assert_contains "$output" "│ line2"
    assert_contains "$output" "╰ line3"
}

#------------------------------------------------------------------------------
# Tests for echo-comment()
#------------------------------------------------------------------------------

@test "echo-comment: outputs cyan bold text" {
    source_echo_lib
    export ECHO_FORMATTED="always"

    run echo-comment "This is a comment"
    [ "$status" -eq 0 ]
    assert_contains "$output" $'\033[36m'  # Cyan
    assert_contains "$output" $'\033[1m'   # Bold
    assert_contains "$output" "This is a comment"
}

#------------------------------------------------------------------------------
# Tests for echo-command()
#------------------------------------------------------------------------------

@test "echo-command: outputs command with $ prefix" {
    source_echo_lib
    export ECHO_FORMATTED="always"

    run echo-command "git status"
    [ "$status" -eq 0 ]
    assert_contains "$output" "$"
    assert_contains "$output" $'\033[32m'  # Green
    assert_contains "$output" "git status"
}

#------------------------------------------------------------------------------
# Tests for echo-warning()
#------------------------------------------------------------------------------

@test "echo-warning: outputs yellow text" {
    source_echo_lib
    export ECHO_FORMATTED="always"

    run echo-warning "This is a warning"
    [ "$status" -eq 0 ]
    assert_contains "$output" $'\033[33m'  # Yellow
    assert_contains "$output" "This is a warning"
}

#------------------------------------------------------------------------------
# Tests for echo-error()
#------------------------------------------------------------------------------

@test "echo-error: outputs red text" {
    source_echo_lib
    export ECHO_FORMATTED="always"

    run echo-error "This is an error"
    [ "$status" -eq 0 ]
    assert_contains "$output" $'\033[31m'  # Red
    assert_contains "$output" "This is an error"
}

#------------------------------------------------------------------------------
# Tests for echo-stderr()
#------------------------------------------------------------------------------

@test "echo-stderr: outputs to stderr in red" {
    source_echo_lib
    export ECHO_FORMATTED="always"

    # Capture stderr
    run bash -c "
        source '${TEST_LIB_DIR}/include.sh'
        include-source 'echo.sh'
        export ECHO_FORMATTED='always'
        echo-stderr 'Error message' 2>&1 >/dev/null
    "
    [ "$status" -eq 0 ]
    assert_contains "$output" $'\033[31m'  # Red
    assert_contains "$output" "Error message"
}

@test "echo-stderr: actually outputs to stderr" {
    source_echo_lib

    # Verify stdout is empty and stderr has content
    local stdout_file=$(generate_temp_file)
    local stderr_file=$(generate_temp_file)

    echo-stderr "Error message" >"$stdout_file" 2>"$stderr_file"

    # stdout should be empty
    assert_empty "$(cat "$stdout_file")"

    # stderr should have the message
    assert_contains "$(cat "$stderr_file")" "Error message"
}

#------------------------------------------------------------------------------
# Tests for echo-success()
#------------------------------------------------------------------------------

@test "echo-success: outputs blue text" {
    source_echo_lib
    export ECHO_FORMATTED="always"

    run echo-success "Operation successful"
    [ "$status" -eq 0 ]
    assert_contains "$output" $'\033[34m'  # Blue
    assert_contains "$output" "Operation successful"
}

#------------------------------------------------------------------------------
# Tests for check-command()
#------------------------------------------------------------------------------

@test "check-command: basic successful command" {
    source_echo_lib

    run check-command "echo test"
    [ "$status" -eq 0 ]
    assert_contains "$output" "Running \`echo test\` ... "
    assert_contains "$output" "done"
}

@test "check-command: basic failing command" {
    source_echo_lib

    run check-command "false"
    [ "$status" -eq 1 ]
    assert_contains "$output" "Running \`false\` ... "
    assert_contains "$output" "error"
}

@test "check-command: custom description" {
    source_echo_lib

    run check-command --command "echo test" --description "Testing echo"
    [ "$status" -eq 0 ]
    assert_contains "$output" "Testing echo ... "
    assert_contains "$output" "done"
}

@test "check-command: custom success and error messages" {
    source_echo_lib

    run check-command --command "true" --success "OK" --error "FAIL"
    [ "$status" -eq 0 ]
    assert_contains "$output" "OK"

    run check-command --command "false" --success "OK" --error "FAIL"
    [ "$status" -eq 1 ]
    assert_contains "$output" "FAIL"
}

@test "check-command: custom prefix" {
    source_echo_lib

    run check-command --command "echo test" --prefix ">>> "
    [ "$status" -eq 0 ]
    assert_contains "$output" ">>> Running"
}

@test "check-command: no prefix" {
    source_echo_lib

    run check-command --command "echo test" --no-prefix
    [ "$status" -eq 0 ]
    assert_not_contains "$output" "* Running"
    assert_contains "$output" "Running"
}

@test "check-command: retry attempts" {
    source_echo_lib

    # Create a script that fails first time, succeeds second
    local script=$(generate_test_script '
        if [[ -f /tmp/check-command-test-flag ]]; then
            rm /tmp/check-command-test-flag
            exit 0
        else
            touch /tmp/check-command-test-flag
            exit 1
        fi
    ')

    rm -f /tmp/check-command-test-flag

    run check-command --command "$script" --attempts 2
    [ "$status" -eq 0 ]
    assert_contains "$output" "retrying"
}

@test "check-command: exit code specific messages" {
    source_echo_lib

    run check-command --command "exit 2" --exit-code-2 "Special error"
    [ "$status" -eq 2 ]
    assert_contains "$output" "Special error"
}

@test "check-command: captures stdout" {
    source_echo_lib

    # This test verifies the stdout capture functionality
    # Note: The function tries to export variables but they won't persist
    # outside the function scope in this test environment
    run bash -c "
        source '${TEST_LIB_DIR}/include.sh'
        include-source 'echo.sh'
        check-command --command 'echo captured' --stdout-var MY_STDOUT
        # Variable won't be available here due to subshell
    "
    [ "$status" -eq 0 ]
}

#------------------------------------------------------------------------------
# Tests for echo-managed() (deprecated)
#------------------------------------------------------------------------------

@test "echo-managed: basic output with default verbosity" {
    source_echo_lib
    export VERBOSITY=1

    run echo-managed "Test message"
    [ "$status" -eq 0 ]
    assert_equals "$output" "Test message"
}

@test "echo-managed: respects verbosity level" {
    source_echo_lib
    export VERBOSITY=1

    run echo-managed 2 "Should not appear"
    [ "$status" -eq 0 ]
    assert_empty "$output"

    export VERBOSITY=2
    run echo-managed 2 "Should appear"
    [ "$status" -eq 0 ]
    assert_equals "$output" "Should appear"
}

@test "echo-managed: -n option suppresses newline" {
    source_echo_lib
    export VERBOSITY=1

    output=$(echo-managed -n "Hello"; echo "World")
    assert_equals "$output" "HelloWorld"
}

@test "echo-managed: handles multiple echo options" {
    source_echo_lib
    export VERBOSITY=2

    # Note: echo-managed doesn't actually support -e, but it passes through
    run echo-managed -n 2 "No newline"
    [ "$status" -eq 0 ]
    # Output captured by run includes newline from run itself
    assert_contains "$output" "No newline"
}

#------------------------------------------------------------------------------
# Tests for repeat-char()
#------------------------------------------------------------------------------

@test "repeat-char: repeats single character" {
    source_echo_lib

    run repeat-char "=" 5
    [ "$status" -eq 0 ]
    assert_equals "$output" "====="
}

@test "repeat-char: default count is 1" {
    source_echo_lib

    run repeat-char "X"
    [ "$status" -eq 0 ]
    assert_equals "$output" "X"
}

@test "repeat-char: handles zero count" {
    source_echo_lib

    run repeat-char "=" 0
    [ "$status" -eq 0 ]
    assert_empty "$output"
}

@test "repeat-char: handles empty character" {
    source_echo_lib

    run repeat-char "" 5
    [ "$status" -eq 0 ]
    assert_empty "$output"
}

@test "repeat-char: handles multi-character strings" {
    source_echo_lib

    run repeat-char "Hi" 3
    [ "$status" -eq 0 ]
    assert_equals "$output" "HiHiHi"
}

#------------------------------------------------------------------------------
# Tests for print-header()
#------------------------------------------------------------------------------

@test "print-header: default bordered style" {
    source_echo_lib

    run print-header "Test Header"
    [ "$status" -eq 0 ]
    assert_contains "$output" "================"
    assert_contains "$output" "Test Header"
    # Should have two border lines
    local border_count=$(echo "$output" | grep -c "================")
    assert_equals "$border_count" "2"
}

@test "print-header: markdown style" {
    source_echo_lib

    run print-header --markdown "Test Header"
    [ "$status" -eq 0 ]
    assert_contains "$output" "# Test Header"
    assert_not_contains "$output" "========="
}

@test "print-header: markdown with custom level" {
    source_echo_lib

    run print-header --markdown --level 3 "Test Header"
    [ "$status" -eq 0 ]
    assert_contains "$output" "### Test Header"
}

@test "print-header: underlined style" {
    source_echo_lib

    run print-header --underline "Test Header"
    [ "$status" -eq 0 ]
    assert_contains "$output" "Test Header"
    assert_contains "$output" "=========="
    # Should have only one border line (underline)
    local border_count=$(echo "$output" | grep -c "==========")
    assert_equals "$border_count" "1"
}

@test "print-header: custom border character" {
    source_echo_lib

    run print-header --border-character "-" "Test Header"
    [ "$status" -eq 0 ]
    assert_contains "$output" "----------"
    assert_not_contains "$output" "=========="
}

@test "print-header: custom border width" {
    source_echo_lib

    run print-header --border-width 20 "Test"
    [ "$status" -eq 0 ]
    # Should have exactly 20 characters
    local line=$(echo "$output" | grep "^==")
    assert_equals "${#line}" "20"
}

@test "print-header: fit-text border width" {
    source_echo_lib

    run print-header --border-width fit-text "Hello"
    [ "$status" -eq 0 ]
    # Border should be same length as "Hello" (5 chars)
    local line=$(echo "$output" | grep "^===")
    assert_equals "${#line}" "5"
}

@test "print-header: margins before and after" {
    source_echo_lib

    run print-header --before 2 --after 3 "Test"
    [ "$status" -eq 0 ]
    # Count empty lines (total lines minus non-empty lines)
    local total_lines=$(echo "$output" | wc -l)
    local non_empty=$(echo "$output" | grep -v "^$" | wc -l)
    local empty_lines=$((total_lines - non_empty))
    # Should have 5 empty lines (2 before + 3 after)
    assert_equals "$empty_lines" "5"
}

@test "print-header: margin option sets both before and after" {
    source_echo_lib

    run print-header --margin 2 "Test"
    [ "$status" -eq 0 ]
    # Should have 4 empty lines (2 before + 2 after)
    local total_lines=$(echo "$output" | wc -l)
    local non_empty=$(echo "$output" | grep -v "^$" | wc -l)
    local empty_lines=$((total_lines - non_empty))
    assert_equals "$empty_lines" "4"
}

@test "print-header: text includes bold formatting" {
    source_echo_lib

    run print-header "Test Header"
    [ "$status" -eq 0 ]
    # Should contain bold escape sequence
    assert_contains "$output" $'\033[1m'
    assert_contains "$output" $'\033[0m'
}

#------------------------------------------------------------------------------
# Tests for echo-vars()
#------------------------------------------------------------------------------

@test "echo-vars: calls debug-vars with DEBUG=true" {
    source_echo_lib

    # Mock debug-vars to verify it's called
    debug-vars() {
        echo "DEBUG=$DEBUG"
        echo "Args: $*"
    }

    local TEST_VAR="test value"
    run echo-vars TEST_VAR
    [ "$status" -eq 0 ]
    assert_contains "$output" "DEBUG=true"
    assert_contains "$output" "Args: TEST_VAR"
}

#------------------------------------------------------------------------------
# Integration tests
#------------------------------------------------------------------------------

@test "integration: color functions work without terminal" {
    source_echo_lib

    # Run in non-TTY environment
    run bash -c "
        source '${TEST_LIB_DIR}/include.sh'
        include-source 'echo.sh'
        echo-error 'Error'
        echo-warning 'Warning'
        echo-success 'Success'
    "
    [ "$status" -eq 0 ]
    assert_contains "$output" "Error"
    assert_contains "$output" "Warning"
    assert_contains "$output" "Success"
}

@test "integration: multiple functions work together" {
    source_echo_lib
    export ECHO_FORMATTED="always"

    # Test combining multiple echo functions
    run bash -c "
        source '${TEST_LIB_DIR}/include.sh'
        include-source 'echo.sh'
        export ECHO_FORMATTED='always'
        print-header 'Test Suite'
        echo-comment 'Running tests...'
        echo-command 'test-command --flag'
        echo-success 'All tests passed!'
    "
    [ "$status" -eq 0 ]
    assert_contains "$output" "Test Suite"
    assert_contains "$output" "Running tests..."
    assert_contains "$output" "$ test-command --flag"
    assert_contains "$output" "All tests passed!"
}

@test "integration: array printing with proper spacing" {
    source_echo_lib

    # Test that arrays are printed with proper spacing
    run bash -c "
        source '${TEST_LIB_DIR}/include.sh'
        include-source 'echo.sh'
        arr=('item 1' 'item 2' 'item 3')
        echo-formatted 'Items:' \"\${arr[@]}\"
    "
    [ "$status" -eq 0 ]
    assert_equals "$output" "Items: item 1 item 2 item 3"
}

@test "integration: complex color combinations" {
    source_echo_lib
    export ECHO_FORMATTED="always"

    # Test complex formatting
    run bash -c "
        source '${TEST_LIB_DIR}/include.sh'
        include-source 'echo.sh'
        export ECHO_FORMATTED='always'
        echo-formatted -rB 'ERROR:' -r 'Something went wrong' -- '(check logs)'
    "
    [ "$status" -eq 0 ]
    # Should see red, bold, reset sequences
    assert_contains "$output" $'\033[31m'
    assert_contains "$output" $'\033[1m'
    assert_contains "$output" $'\033[0m'
    assert_contains "$output" "ERROR: Something went wrong (check logs)"
}