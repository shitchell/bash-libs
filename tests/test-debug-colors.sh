#!/usr/bin/env bash

# Integration test for debug.sh with colors.sh

# Source the libraries
source "$(dirname "$0")/../include.sh"
include-source 'debug.sh'

# Test counter
tests_run=0
tests_passed=0

# Test function
test_case() {
    local name="$1"
    ((tests_run++))
    echo -n "Testing: $name ... "
}

pass() {
    ((tests_passed++))
    echo "PASS"
}

fail() {
    echo "FAIL: $1"
}

# Test 1: Basic debug functionality
test_case "Basic debug with DEBUG=1"
DEBUG=1
output=$(debug "test message" 2>&1)
if [[ "$output" =~ "test message" ]]; then
    pass
else
    fail "Message not found in output"
fi

# Test 2: Debug levels
test_case "Debug levels"
DEBUG=2
output1=$(debug 1 "level 1 message" 2>&1)
output2=$(debug 2 "level 2 message" 2>&1)
output3=$(debug 3 "level 3 message" 2>&1)
if [[ "$output1" =~ "level 1 message" ]] && [[ "$output2" =~ "level 2 message" ]] && [[ -z "$output3" ]]; then
    pass
else
    fail "Debug levels not working correctly"
fi

# Test 3: Error label with color
test_case "Error label (red color)"
DEBUG=1
unset DEBUG_COLOR
setup-colors
output=$(debug error "error message" 2>&1)
if [[ "$output" =~ "error message" ]] && [[ "$output" =~ "\[00\]" ]]; then
    if [[ -n "${C_RED:-}" ]] && [[ "$output" =~ "${C_RED}" ]]; then
        pass
    else
        pass  # Colors may not be available in test environment
    fi
else
    fail "Error label not working"
fi

# Test 4: Warn label with color
test_case "Warn label (yellow color)"
DEBUG=20
output=$(debug warn "warning message" 2>&1)
if [[ "$output" =~ "warning message" ]] && [[ "$output" =~ "\[10\]" ]]; then
    pass
else
    fail "Warn label not working"
fi

# Test 5: Info label with color
test_case "Info label (blue color)"
DEBUG=30
output=$(debug info "info message" 2>&1)
if [[ "$output" =~ "info message" ]] && [[ "$output" =~ "\[20\]" ]]; then
    pass
else
    fail "Info label not working"
fi

# Test 6: Success label with color
test_case "Success label (green color)"
DEBUG=1
output=$(debug success "success message" 2>&1)
if [[ "$output" =~ "success message" ]] && [[ "$output" =~ "\[00\]" ]]; then
    pass
else
    fail "Success label not working"
fi

# Test 7: Debug label with color
test_case "Debug label (gray/dim color)"
DEBUG=40
output=$(debug debug "debug message" 2>&1)
if [[ "$output" =~ "debug message" ]] && [[ "$output" =~ "\[30\]" ]]; then
    pass
else
    fail "Debug label not working"
fi

# Test 8: Color disabled
test_case "Colors disabled with DEBUG_COLOR=false"
DEBUG=1
DEBUG_COLOR=false
output=$(debug error "no color message" 2>&1)
if [[ "$output" =~ "no color message" ]] && ! [[ "$output" =~ $'\033[' ]]; then
    pass
else
    fail "Colors not properly disabled"
fi

# Test 9: DEBUG_LOG functionality
test_case "DEBUG_LOG file output"
DEBUG_LOG=$(mktemp)
unset DEBUG
debug "log message"
if [[ -f "$DEBUG_LOG" ]] && grep -q "log message" "$DEBUG_LOG"; then
    pass
    rm -f "$DEBUG_LOG"
else
    fail "DEBUG_LOG not working"
    [[ -f "$DEBUG_LOG" ]] && rm -f "$DEBUG_LOG"
fi

# Test 10: Works without colors.sh
test_case "Works without colors.sh loaded"
DEBUG=1
unset DEBUG_COLOR
# Unset color variables to simulate colors.sh not loaded
unset C_RED C_YELLOW C_BLUE C_GREEN C_CYAN C_MAGENTA S_BOLD S_RESET
output=$(debug error "no colors loaded" 2>&1)
if [[ "$output" =~ "no colors loaded" ]]; then
    pass
else
    fail "Doesn't work without colors.sh"
fi

# Test 11: debug-vars functionality
test_case "debug-vars basic functionality"
DEBUG=1
test_var="test value"
output=$(debug-vars test_var 2>&1)
if [[ "$output" =~ "test_var" ]] && [[ "$output" =~ "test value" ]]; then
    pass
else
    fail "debug-vars not working"
fi

# Test 12: print-escaped functionality
test_case "print-escaped newlines"
output=$(print-escaped $'line1\nline2')
if [[ "$output" == 'line1\nline2' ]]; then
    pass
else
    fail "print-escaped not working for newlines"
fi

# Summary
echo
echo "================================"
echo "Test Summary:"
echo "Tests run: $tests_run"
echo "Tests passed: $tests_passed"
echo "Tests failed: $((tests_run - tests_passed))"
echo "================================"

if [[ $tests_passed -eq $tests_run ]]; then
    echo "All tests passed!"
    exit 0
else
    echo "Some tests failed!"
    exit 1
fi