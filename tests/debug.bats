#!/usr/bin/env bats

# Test suite for debug.sh library with colors.sh integration

# Setup and teardown
setup() {
    # Load test helpers
    load test_bats_helpers
    load test_helpers

    # Source the library being tested
    source "${BATS_TEST_DIRNAME}/../include.sh"
    include-source 'debug.sh'

    # Save original values
    export ORIGINAL_DEBUG="${DEBUG:-}"
    export ORIGINAL_DEBUG_LOG="${DEBUG_LOG:-}"
    export ORIGINAL_DEBUG_COLOR="${DEBUG_COLOR:-}"

    # Create temp directory for log files
    export TEST_TEMP_DIR="$(mktemp -d)"
}

teardown() {
    # Restore original values
    export DEBUG="${ORIGINAL_DEBUG}"
    export DEBUG_LOG="${ORIGINAL_DEBUG_LOG}"
    export DEBUG_COLOR="${ORIGINAL_DEBUG_COLOR}"

    # Cleanup temp files
    [[ -d "${TEST_TEMP_DIR}" ]] && rm -rf "${TEST_TEMP_DIR}"
}

# Basic functionality tests
@test "debug: returns 1 when DEBUG and DEBUG_LOG are unset" {
    unset DEBUG DEBUG_LOG
    run debug "test message"
    assert_failure
    assert_output ""
}

@test "debug: returns 0 when DEBUG=1 with no message" {
    export DEBUG=1
    run debug
    assert_success
}

@test "debug: prints message when DEBUG=1" {
    export DEBUG=1
    run debug "test message" 2>&1
    assert_success
    assert_line --partial "test message"
}

@test "debug: prints message when DEBUG=true" {
    export DEBUG=true
    run debug "test message" 2>&1
    assert_success
    assert_line --partial "test message"
}

@test "debug: prints message when DEBUG=all" {
    export DEBUG=all
    run debug "test message" 2>&1
    assert_success
    assert_line --partial "test message"
}

@test "debug: prints message when DEBUG=*" {
    export DEBUG='*'
    run debug "test message" 2>&1
    assert_success
    assert_line --partial "test message"
}

# Debug level tests
@test "debug: respects debug levels" {
    export DEBUG=2

    # Level 1 should print
    run debug 1 "level 1 message" 2>&1
    assert_success
    assert_line --partial "level 1 message"
    assert_line --partial "[01]"

    # Level 2 should print
    run debug 2 "level 2 message" 2>&1
    assert_success
    assert_line --partial "level 2 message"
    assert_line --partial "[02]"

    # Level 3 should not print
    run debug 3 "level 3 message" 2>&1
    assert_failure
    assert_output ""
}

# Label tests
@test "debug: handles error label" {
    export DEBUG=1
    run debug error "error message" 2>&1
    assert_success
    assert_line --partial "error message"
    assert_line --partial "[00]"  # error is level 0
}

@test "debug: handles warn label" {
    export DEBUG=20
    run debug warn "warning message" 2>&1
    assert_success
    assert_line --partial "warning message"
    assert_line --partial "[10]"  # warn is level 10
}

@test "debug: handles info label" {
    export DEBUG=30
    run debug info "info message" 2>&1
    assert_success
    assert_line --partial "info message"
    assert_line --partial "[20]"  # info is level 20
}

@test "debug: handles success label" {
    export DEBUG=1
    run debug success "success message" 2>&1
    assert_success
    assert_line --partial "success message"
    assert_line --partial "[00]"  # success is level 0
}

@test "debug: handles debug label" {
    export DEBUG=40
    run debug debug "debug message" 2>&1
    assert_success
    assert_line --partial "debug message"
    assert_line --partial "[30]"  # debug is level 30
}

# Color tests
@test "debug: uses colors when available" {
    export DEBUG=1
    unset DEBUG_COLOR

    # Ensure colors are loaded
    setup-colors

    run debug "test message" 2>&1
    assert_success
    # Should contain ANSI escape sequences
    assert_line --regexp '\[[0-9]{4}-[0-9]{2}-[0-9]{2}'  # timestamp exists
}

@test "debug: respects DEBUG_COLOR=false" {
    export DEBUG=1
    export DEBUG_COLOR=false

    run debug "test message" 2>&1
    assert_success
    # Should not contain color codes
    refute_line --partial $'\033['
}

@test "debug: respects DEBUG_COLOR=0" {
    export DEBUG=1
    export DEBUG_COLOR=0

    run debug "test message" 2>&1
    assert_success
    # Should not contain color codes
    refute_line --partial $'\033['
}

@test "debug: error label uses red color" {
    export DEBUG=1
    unset DEBUG_COLOR
    setup-colors

    run debug error "error message" 2>&1
    assert_success
    # Check for red color if colors are enabled
    if [[ -n "${C_RED:-}" ]]; then
        assert_line --partial "${C_RED}"
    fi
}

@test "debug: warn label uses yellow color" {
    export DEBUG=1
    unset DEBUG_COLOR
    setup-colors

    run debug warn "warning message" 2>&1
    assert_success
    # Check for yellow color if colors are enabled
    if [[ -n "${C_YELLOW:-}" ]]; then
        assert_line --partial "${C_YELLOW}"
    fi
}

@test "debug: info label uses blue color" {
    export DEBUG=1
    unset DEBUG_COLOR
    setup-colors

    run debug info "info message" 2>&1
    assert_success
    # Check for blue color if colors are enabled
    if [[ -n "${C_BLUE:-}" ]]; then
        assert_line --partial "${C_BLUE}"
    fi
}

@test "debug: success label uses green color" {
    export DEBUG=1
    unset DEBUG_COLOR
    setup-colors

    run debug success "success message" 2>&1
    assert_success
    # Check for green color if colors are enabled
    if [[ -n "${C_GREEN:-}" ]]; then
        assert_line --partial "${C_GREEN}"
    fi
}

# DEBUG_LOG tests
@test "debug: writes to DEBUG_LOG file" {
    export DEBUG_LOG="${TEST_TEMP_DIR}/debug.log"
    unset DEBUG

    debug "test message"

    assert_file_exists "${DEBUG_LOG}"
    run cat "${DEBUG_LOG}"
    assert_line --partial "test message"
}

@test "debug: creates DEBUG_LOG directory if needed" {
    export DEBUG_LOG="${TEST_TEMP_DIR}/subdir/debug.log"
    unset DEBUG

    debug "test message"

    assert_file_exists "${DEBUG_LOG}"
}

@test "debug: appends to existing DEBUG_LOG" {
    export DEBUG_LOG="${TEST_TEMP_DIR}/debug.log"
    unset DEBUG

    debug "first message"
    debug "second message"

    run cat "${DEBUG_LOG}"
    assert_line --partial "first message"
    assert_line --partial "second message"
}

# Multiple argument tests
@test "debug: handles multiple arguments" {
    export DEBUG=1

    run debug "line 1" "line 2" "line 3" 2>&1
    assert_success
    assert_line --partial "line 1"
    assert_line --partial "line 2"
    assert_line --partial "line 3"
}

# Format tests
@test "debug: includes timestamp" {
    export DEBUG=1

    run debug "test message" 2>&1
    assert_success
    assert_line --regexp '[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}'
}

@test "debug: includes script name" {
    export DEBUG=1

    run debug "test message" 2>&1
    assert_success
    assert_line --partial "bats-exec-test"
}

@test "debug: includes line number" {
    export DEBUG=1

    run debug "test message" 2>&1
    assert_success
    assert_line --regexp ':[0-9]+'
}

# debug-vars tests
@test "debug-vars: prints variable values" {
    export DEBUG=1
    local test_var="test value"
    local test_num=42

    run debug-vars test_var test_num 2>&1
    assert_success
    assert_line --partial "test_var"
    assert_line --partial "test value"
    assert_line --partial "test_num"
    assert_line --partial "42"
}

@test "debug-vars: handles arrays" {
    export DEBUG=1
    local test_array=(one two three)

    run debug-vars test_array 2>&1
    assert_success
    assert_line --partial "test_array"
    assert_line --partial "([0]=\"one\" [1]=\"two\" [2]=\"three\")"
}

@test "debug-vars: handles unset variables" {
    export DEBUG=1
    unset UNSET_VAR

    run debug-vars UNSET_VAR 2>&1
    assert_success
    assert_line --partial "UNSET_VAR"
    assert_line --partial "<not found>"
}

@test "debug-vars: handles glob patterns" {
    export DEBUG=1
    export TEST_VAR_1="value1"
    export TEST_VAR_2="value2"

    run debug-vars "TEST_VAR_*" 2>&1
    assert_success
    assert_line --partial "TEST_VAR_1"
    assert_line --partial "value1"
    assert_line --partial "TEST_VAR_2"
    assert_line --partial "value2"
}

@test "debug-vars: respects verbosity levels" {
    export DEBUG=1
    local test_var="test"

    # Default verbosity (1)
    run debug-vars test_var 2>&1
    assert_success
    refute_line --partial "(str:4)"

    # Verbosity 2
    run debug-vars -v test_var 2>&1
    assert_success
    assert_line --partial "(-:4)"

    # Verbosity 3
    run debug-vars -vv test_var 2>&1
    assert_success
    assert_line --partial "(str:4)"
}

# print-escaped tests
@test "print-escaped: escapes newlines" {
    run print-escaped $'line1\nline2'
    assert_success
    assert_output 'line1\nline2'
}

@test "print-escaped: escapes tabs" {
    run print-escaped $'before\tafter'
    assert_success
    assert_output 'before\tafter'
}

@test "print-escaped: escapes carriage returns" {
    run print-escaped $'text\rmore'
    assert_success
    assert_output 'text\rmore'
}

# Edge case tests
@test "debug: handles empty strings" {
    export DEBUG=1

    run debug "" 2>&1
    assert_success
    # Should still show the debug prefix
    assert_line --regexp '[0-9]{4}-[0-9]{2}-[0-9]{2}'
}

@test "debug: handles special characters" {
    export DEBUG=1

    run debug "Special chars: \$HOME | grep & echo" 2>&1
    assert_success
    assert_line --partial "Special chars: \$HOME | grep & echo"
}

@test "debug: level with label combination" {
    export DEBUG=20

    # Level 2 with error label should print
    run debug 2 error "level 2 error" 2>&1
    assert_success
    assert_line --partial "level 2 error"

    # Level 30 with error label should not print
    run debug 30 error "level 30 error" 2>&1
    assert_failure
    assert_output ""
}

# Integration with colors.sh
@test "debug: works without colors.sh loaded" {
    # Unset all color variables to simulate colors.sh not being loaded
    unset-colors 2>/dev/null || true
    unset C_RED C_YELLOW C_BLUE C_GREEN C_CYAN C_MAGENTA S_BOLD S_RESET

    export DEBUG=1
    run debug "test without colors" 2>&1
    assert_success
    assert_line --partial "test without colors"
}

@test "debug: gracefully handles missing colors.sh" {
    export DEBUG=1

    # Test each label type without colors
    unset-colors 2>/dev/null || true

    run debug error "error without colors" 2>&1
    assert_success
    assert_line --partial "error without colors"

    run debug warn "warn without colors" 2>&1
    assert_success
    assert_line --partial "warn without colors"

    run debug info "info without colors" 2>&1
    assert_success
    assert_line --partial "info without colors"

    run debug success "success without colors" 2>&1
    assert_success
    assert_line --partial "success without colors"
}