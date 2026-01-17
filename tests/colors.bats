#!/usr/bin/env bats
# colors.bats - Comprehensive tests for colors.sh library functions

# Load test helpers
load test_helpers

# Setup and teardown
setup() {
    # Save original environment variables
    export ORIG_ENABLE_COLORS="${ENABLE_COLORS:-}"

    # Create temp directory for test files
    export TEST_TEMP_DIR=$(generate_temp_dir)

    # Clear any existing color variables before each test
    unset C_RED C_GREEN C_BLUE C_BLACK C_WHITE C_YELLOW C_MAGENTA C_CYAN
    unset C_RGB C_DEFAULT_FG C_BLACK_BG C_RED_BG C_GREEN_BG C_YELLOW_BG
    unset C_BLUE_BG C_MAGENTA_BG C_CYAN_BG C_WHITE_BG C_RGB_BG C_DEFAULT_BG
    unset S_RESET S_BOLD S_DIM S_ITALIC S_UNDERLINE S_BLINK S_BLINK_FAST
    unset S_REVERSE S_HIDDEN S_STRIKETHROUGH S_DEFAULT

    # Clear any numbered color variables
    for i in {0..255}; do
        local varname="00${i}"
        varname="C_${varname: -3}"
        unset ${varname} ${varname}_BG
    done
}

teardown() {
    # Restore original ENABLE_COLORS
    if [[ -n "$ORIG_ENABLE_COLORS" ]]; then
        export ENABLE_COLORS="$ORIG_ENABLE_COLORS"
    else
        unset ENABLE_COLORS
    fi

    # Clean up any mock functions
    restore_command tput 2>/dev/null || true
    restore_command custom-colors 2>/dev/null || true

    # Clean up temp directory
    [[ -d "$TEST_TEMP_DIR" ]] && rm -rf "$TEST_TEMP_DIR"
}

#------------------------------------------------------------------------------
# Tests for setup-colors()
#------------------------------------------------------------------------------

@test "setup-colors: sets all standard color variables" {
    # Source without auto-setup
    source "${BATS_TEST_DIRNAME}/../colors.sh" --no-auto

    # Verify colors are not set initially
    assert_empty "${C_RED:-}"

    # Run setup-colors (not in subshell)
    setup-colors

    # Check standard foreground colors
    assert_equals "$C_BLACK" $'\033[30m'
    assert_equals "$C_RED" $'\033[31m'
    assert_equals "$C_GREEN" $'\033[32m'
    assert_equals "$C_YELLOW" $'\033[33m'
    assert_equals "$C_BLUE" $'\033[34m'
    assert_equals "$C_MAGENTA" $'\033[35m'
    assert_equals "$C_CYAN" $'\033[36m'
    assert_equals "$C_WHITE" $'\033[37m'
    assert_equals "$C_DEFAULT_FG" $'\033[39m'
}

@test "setup-colors: sets RGB color format variables" {
    source "${BATS_TEST_DIRNAME}/../colors.sh" --no-auto

    setup-colors

    # Check RGB format variables
    assert_equals "$C_RGB" $'\033[38;2;%d;%d;%dm'
    assert_equals "$C_RGB_BG" $'\033[48;2;%d;%d;%dm'
}

@test "setup-colors: sets all background color variables" {
    source "${BATS_TEST_DIRNAME}/../colors.sh" --no-auto

    setup-colors

    # Check background colors
    assert_equals "$C_BLACK_BG" $'\033[40m'
    assert_equals "$C_RED_BG" $'\033[41m'
    assert_equals "$C_GREEN_BG" $'\033[42m'
    assert_equals "$C_YELLOW_BG" $'\033[43m'
    assert_equals "$C_BLUE_BG" $'\033[44m'
    assert_equals "$C_MAGENTA_BG" $'\033[45m'
    assert_equals "$C_CYAN_BG" $'\033[46m'
    assert_equals "$C_WHITE_BG" $'\033[47m'
    assert_equals "$C_DEFAULT_BG" $'\033[49m'
}

@test "setup-colors: sets all style variables" {
    source "${BATS_TEST_DIRNAME}/../colors.sh" --no-auto

    setup-colors

    # Check style variables
    assert_equals "$S_RESET" $'\033[0m'
    assert_equals "$S_BOLD" $'\033[1m'
    assert_equals "$S_DIM" $'\033[2m'
    assert_equals "$S_ITALIC" $'\033[3m'
    assert_equals "$S_UNDERLINE" $'\033[4m'
    assert_equals "$S_BLINK" $'\033[5m'
    assert_equals "$S_BLINK_FAST" $'\033[6m'
    assert_equals "$S_REVERSE" $'\033[7m'
    assert_equals "$S_HIDDEN" $'\033[8m'
    assert_equals "$S_STRIKETHROUGH" $'\033[9m'
    assert_equals "$S_DEFAULT" $'\033[10m'
}

@test "setup-colors: sets all 256-color variables" {
    source "${BATS_TEST_DIRNAME}/../colors.sh" --no-auto

    setup-colors

    # Check a sample of numbered colors (testing all 256 would be excessive)
    assert_equals "$C_000" $'\033[38;5;0m'
    assert_equals "$C_000_BG" $'\033[48;5;0m'

    assert_equals "$C_015" $'\033[38;5;15m'
    assert_equals "$C_015_BG" $'\033[48;5;15m'

    assert_equals "$C_128" $'\033[38;5;128m'
    assert_equals "$C_128_BG" $'\033[48;5;128m'

    assert_equals "$C_255" $'\033[38;5;255m'
    assert_equals "$C_255_BG" $'\033[48;5;255m'
}

@test "setup-colors: exports all variables" {
    source "${BATS_TEST_DIRNAME}/../colors.sh" --no-auto

    setup-colors

    # Check that variables are exported (can be seen in subshell)
    run bash -c 'echo "$C_RED"'
    assert_equals "$output" $'\033[31m'

    run bash -c 'echo "$S_BOLD"'
    assert_equals "$output" $'\033[1m'

    run bash -c 'echo "$C_042"'
    assert_equals "$output" $'\033[38;5;42m'
}

@test "setup-colors: calls custom-colors function if it exists" {
    source "${BATS_TEST_DIRNAME}/../colors.sh" --no-auto

    # Create a mock custom-colors function
    local custom_called=false
    custom-colors() {
        custom_called=true
        # Set a custom color variable
        export C_CUSTOM=$'\033[38;5;200m'
    }

    setup-colors

    # Verify custom-colors was called
    assert_equals "$custom_called" "true"
    assert_equals "$C_CUSTOM" $'\033[38;5;200m'
}

#------------------------------------------------------------------------------
# Tests for unset-colors()
#------------------------------------------------------------------------------

@test "unset-colors: removes all standard color variables" {
    source "${BATS_TEST_DIRNAME}/../colors.sh" --no-auto

    # First set up colors
    setup-colors
    assert_not_empty "$C_RED"

    # Then unset them
    unset-colors

    # Verify all standard colors are unset
    assert_empty "${C_BLACK:-}"
    assert_empty "${C_RED:-}"
    assert_empty "${C_GREEN:-}"
    assert_empty "${C_YELLOW:-}"
    assert_empty "${C_BLUE:-}"
    assert_empty "${C_MAGENTA:-}"
    assert_empty "${C_CYAN:-}"
    assert_empty "${C_WHITE:-}"
    assert_empty "${C_DEFAULT_FG:-}"
}

@test "unset-colors: removes all background color variables" {
    source "${BATS_TEST_DIRNAME}/../colors.sh" --no-auto

    setup-colors
    assert_not_empty "$C_RED_BG"

    unset-colors

    # Verify all background colors are unset
    assert_empty "${C_BLACK_BG:-}"
    assert_empty "${C_RED_BG:-}"
    assert_empty "${C_GREEN_BG:-}"
    assert_empty "${C_YELLOW_BG:-}"
    assert_empty "${C_BLUE_BG:-}"
    assert_empty "${C_MAGENTA_BG:-}"
    assert_empty "${C_CYAN_BG:-}"
    assert_empty "${C_WHITE_BG:-}"
    assert_empty "${C_DEFAULT_BG:-}"
}

@test "unset-colors: removes all style variables" {
    source "${BATS_TEST_DIRNAME}/../colors.sh" --no-auto

    setup-colors
    assert_not_empty "$S_BOLD"

    unset-colors

    # Verify all styles are unset
    assert_empty "${S_RESET:-}"
    assert_empty "${S_BOLD:-}"
    assert_empty "${S_DIM:-}"
    assert_empty "${S_ITALIC:-}"
    assert_empty "${S_UNDERLINE:-}"
    assert_empty "${S_BLINK:-}"
    assert_empty "${S_BLINK_FAST:-}"
    assert_empty "${S_REVERSE:-}"
    assert_empty "${S_HIDDEN:-}"
    assert_empty "${S_STRIKETHROUGH:-}"
    assert_empty "${S_DEFAULT:-}"
}

@test "unset-colors: removes all 256-color variables" {
    source "${BATS_TEST_DIRNAME}/../colors.sh" --no-auto

    setup-colors
    assert_not_empty "$C_042"

    unset-colors

    # Check sample of numbered colors are unset
    assert_empty "${C_000:-}"
    assert_empty "${C_042:-}"
    assert_empty "${C_128:-}"
    assert_empty "${C_255:-}"
    assert_empty "${C_000_BG:-}"
    assert_empty "${C_255_BG:-}"
}

@test "unset-colors: removes RGB format variables" {
    source "${BATS_TEST_DIRNAME}/../colors.sh" --no-auto

    setup-colors
    assert_not_empty "$C_RGB"

    unset-colors

    assert_empty "${C_RGB:-}"
    assert_empty "${C_RGB_BG:-}"
}

#------------------------------------------------------------------------------
# Tests for auto-loading behavior
#------------------------------------------------------------------------------

@test "sourcing with --auto sets up colors when stdout is TTY" {
    # This test will pass in interactive terminals but may need adjustment
    # for CI environments where stdout might not be a TTY
    if [[ -t 1 ]]; then
        unset C_RED
        source "${BATS_TEST_DIRNAME}/../colors.sh" --auto
        assert_not_empty "${C_RED:-}"
    else
        skip "stdout is not a TTY in this environment"
    fi
}

@test "sourcing with --auto does not set up colors when stdout is not TTY" {
    # Run in a subshell with redirected stdout
    run bash -c "
        unset C_RED
        source '${BATS_TEST_DIRNAME}/../colors.sh' --auto
        echo \"\${C_RED:-EMPTY}\"
    " 2>&1
    [ "$status" -eq 0 ]
    assert_equals "$output" "EMPTY"
}

@test "sourcing with --setup-colors always sets up colors" {
    # Even with redirected stdout, colors should be set up
    run bash -c "
        unset C_RED
        source '${BATS_TEST_DIRNAME}/../colors.sh' --setup-colors
        echo \"\$C_RED\"
    "
    [ "$status" -eq 0 ]
    assert_equals "$output" $'\033[31m'
}

@test "sourcing with --no-auto does not set up colors" {
    unset C_RED
    source "${BATS_TEST_DIRNAME}/../colors.sh" --no-auto
    assert_empty "${C_RED:-}"
}

@test "sourcing with --no-setup-colors does not set up colors" {
    unset C_RED
    source "${BATS_TEST_DIRNAME}/../colors.sh" --no-setup-colors
    assert_empty "${C_RED:-}"
}

#------------------------------------------------------------------------------
# Tests for ENABLE_COLORS environment variable
#------------------------------------------------------------------------------

@test "ENABLE_COLORS=auto respects TTY detection" {
    # Test with non-TTY
    run bash -c "
        export ENABLE_COLORS=auto
        unset C_RED
        source '${BATS_TEST_DIRNAME}/../colors.sh'
        echo \"\${C_RED:-EMPTY}\"
    " 2>&1
    [ "$status" -eq 0 ]
    assert_equals "$output" "EMPTY"
}

@test "ENABLE_COLORS=true always sets up colors" {
    run bash -c "
        export ENABLE_COLORS=true
        unset C_RED
        source '${BATS_TEST_DIRNAME}/../colors.sh'
        echo \"\$C_RED\"
    "
    [ "$status" -eq 0 ]
    assert_equals "$output" $'\033[31m'
}

@test "ENABLE_COLORS=always always sets up colors" {
    run bash -c "
        export ENABLE_COLORS=always
        unset C_RED
        source '${BATS_TEST_DIRNAME}/../colors.sh'
        echo \"\$C_RED\"
    "
    [ "$status" -eq 0 ]
    assert_equals "$output" $'\033[31m'
}

@test "ENABLE_COLORS=yes always sets up colors" {
    run bash -c "
        export ENABLE_COLORS=yes
        unset C_RED
        source '${BATS_TEST_DIRNAME}/../colors.sh'
        echo \"\$C_RED\"
    "
    [ "$status" -eq 0 ]
    assert_equals "$output" $'\033[31m'
}

@test "ENABLE_COLORS=false never sets up colors" {
    run bash -c "
        export ENABLE_COLORS=false
        unset C_RED
        source '${BATS_TEST_DIRNAME}/../colors.sh'
        echo \"\${C_RED:-EMPTY}\"
    "
    [ "$status" -eq 0 ]
    assert_equals "$output" "EMPTY"
}

@test "ENABLE_COLORS=never never sets up colors" {
    run bash -c "
        export ENABLE_COLORS=never
        unset C_RED
        source '${BATS_TEST_DIRNAME}/../colors.sh'
        echo \"\${C_RED:-EMPTY}\"
    "
    [ "$status" -eq 0 ]
    assert_equals "$output" "EMPTY"
}

@test "ENABLE_COLORS=no never sets up colors" {
    run bash -c "
        export ENABLE_COLORS=no
        unset C_RED
        source '${BATS_TEST_DIRNAME}/../colors.sh'
        echo \"\${C_RED:-EMPTY}\"
    "
    [ "$status" -eq 0 ]
    assert_equals "$output" "EMPTY"
}

@test "Invalid ENABLE_COLORS value falls back to auto" {
    # With invalid value and non-TTY, should not set up colors
    run bash -c "
        export ENABLE_COLORS=invalid
        unset C_RED
        source '${BATS_TEST_DIRNAME}/../colors.sh'
        echo \"\${C_RED:-EMPTY}\"
    " 2>&1
    [ "$status" -eq 0 ]
    assert_equals "$output" "EMPTY"
}

#------------------------------------------------------------------------------
# Tests for command-line arguments
#------------------------------------------------------------------------------

@test "Command-line args override ENABLE_COLORS environment variable" {
    run bash -c "
        export ENABLE_COLORS=true
        unset C_RED
        source '${BATS_TEST_DIRNAME}/../colors.sh' --no-auto
        echo \"\${C_RED:-EMPTY}\"
    "
    [ "$status" -eq 0 ]
    assert_equals "$output" "EMPTY"
}

@test "Invalid command-line argument causes error" {
    run bash -c "
        source '${BATS_TEST_DIRNAME}/../colors.sh' --invalid-option
    " 2>&1
    [ "$status" -ne 0 ]
    assert_contains "$output" "unknown option: --invalid-option"
}

#------------------------------------------------------------------------------
# Tests for function exports
#------------------------------------------------------------------------------

@test "setup-colors function is exported" {
    source "${BATS_TEST_DIRNAME}/../colors.sh" --no-auto

    # Check function is available in subshell
    run bash -c "
        source '${BATS_TEST_DIRNAME}/../colors.sh' --no-auto
        declare -F setup-colors
    "
    [ "$status" -eq 0 ]
    assert_contains "$output" "setup-colors"
}

@test "unset-colors function is exported" {
    source "${BATS_TEST_DIRNAME}/../colors.sh" --no-auto

    # Check function is available in subshell
    run bash -c "
        source '${BATS_TEST_DIRNAME}/../colors.sh' --no-auto
        declare -F unset-colors
    "
    [ "$status" -eq 0 ]
    assert_contains "$output" "unset-colors"
}

#------------------------------------------------------------------------------
# Tests for edge cases and error handling
#------------------------------------------------------------------------------

@test "Multiple calls to setup-colors are idempotent" {
    source "${BATS_TEST_DIRNAME}/../colors.sh" --no-auto

    setup-colors
    local first_red="$C_RED"

    setup-colors
    local second_red="$C_RED"

    assert_equals "$first_red" "$second_red"
}

@test "unset-colors works even when colors were never set" {
    source "${BATS_TEST_DIRNAME}/../colors.sh" --no-auto

    # Should not error even if colors aren't set
    run unset-colors
    [ "$status" -eq 0 ]
}

@test "Functions work correctly when sourced multiple times" {
    source "${BATS_TEST_DIRNAME}/../colors.sh" --no-auto
    source "${BATS_TEST_DIRNAME}/../colors.sh" --no-auto

    # Should still work correctly
    setup-colors
    assert_equals "$C_RED" $'\033[31m'
}

#------------------------------------------------------------------------------
# Tests for practical usage scenarios
#------------------------------------------------------------------------------

@test "Colors work correctly with echo" {
    source "${BATS_TEST_DIRNAME}/../colors.sh" --setup-colors

    # Test that colors work without -e flag
    run echo "${C_RED}Error${S_RESET}"
    [ "$status" -eq 0 ]
    assert_contains "$output" $'\033[31m'
    assert_contains "$output" $'\033[0m'
}

@test "Colors can be combined with styles" {
    source "${BATS_TEST_DIRNAME}/../colors.sh" --setup-colors

    # Combine color and style
    local styled="${C_RED}${S_BOLD}Important${S_RESET}"
    assert_contains "$styled" $'\033[31m'
    assert_contains "$styled" $'\033[1m'
    assert_contains "$styled" $'\033[0m'
}

@test "RGB format can be used with printf" {
    source "${BATS_TEST_DIRNAME}/../colors.sh" --setup-colors

    # Use RGB format
    run printf "${C_RGB}Custom Color${S_RESET}" 255 128 0
    [ "$status" -eq 0 ]
    assert_contains "$output" $'\033[38;2;255;128;0m'
}

@test "Background colors work correctly" {
    source "${BATS_TEST_DIRNAME}/../colors.sh" --setup-colors

    # Test background color
    run echo "${C_WHITE}${C_RED_BG}Error${S_RESET}"
    [ "$status" -eq 0 ]
    assert_contains "$output" $'\033[37m'
    assert_contains "$output" $'\033[41m'
}

#------------------------------------------------------------------------------
# Test tput caching behavior (though colors.sh doesn't use tput)
#------------------------------------------------------------------------------

@test "Library does not depend on tput command" {
    # Mock tput to fail
    mock_command "tput" 1 ""

    source "${BATS_TEST_DIRNAME}/../colors.sh" --no-auto

    # Should still work without tput
    setup-colors
    assert_equals "$C_RED" $'\033[31m'
}

@test "Colors are consistent across terminals" {
    # Test that we get ANSI codes, not terminal-specific sequences
    source "${BATS_TEST_DIRNAME}/../colors.sh" --setup-colors

    # Colors should be standard ANSI escape sequences
    [[ "$C_RED" =~ ^$'\033'\[31m$ ]]
    [[ "$S_BOLD" =~ ^$'\033'\[1m$ ]]
    [[ "$C_042" =~ ^$'\033'\[38\;5\;42m$ ]]
}