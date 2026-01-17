#!/usr/bin/env bash
#
# errors.sh - Error handling and exception management for bash scripts
#
# This library provides comprehensive error handling mechanisms including
# error initialization, handlers, stack traces, and pseudo try-catch blocks.

# Global error state variables
declare -g ERROR_CODE=0
declare -g ERROR_MESSAGE=""
declare -g ERROR_SOURCE=""
declare -g ERROR_LINE=0
declare -g ERROR_TRACE_ENABLED=1
declare -g ERROR_EXIT_ON_ERROR=0
declare -g ERROR_HANDLER_SET=0

function error-init() {
    : 'Initialize error handling for the script

    Sets up error handling with ERR trap and optionally enables strict mode.
    Call this at the beginning of your script for comprehensive error handling.

    @arg $1 [optional] Set to "strict" to enable set -euo pipefail
    @return 0 on success
    @example error-init
    @example error-init strict
    '
    local mode="${1:-}"

    # Set error trap
    trap '__error_handler $? "$BASH_COMMAND" "$BASH_SOURCE" "$LINENO"' ERR
    ERROR_HANDLER_SET=1

    # Enable strict mode if requested
    if [[ "$mode" == "strict" ]]; then
        set -euo pipefail
        ERROR_EXIT_ON_ERROR=1
    fi

    # Enable extended debugging for better stack traces
    shopt -s extdebug

    return 0
}

function error-handler() {
    : 'Set a custom error handler function

    Allows setting a custom function to be called on errors.
    The function will receive: exit_code, command, source_file, line_number

    @arg $1 Function name to use as error handler
    @return 0 on success, 1 if function does not exist
    @example error-handler my_custom_handler
    '
    local handler_func="$1"

    # Verify the handler function exists
    if ! declare -f "$handler_func" >/dev/null 2>&1; then
        echo "Error: Handler function '$handler_func' does not exist" >&2
        return 1
    fi

    # Set custom handler
    trap '__error_handler $? "$BASH_COMMAND" "$BASH_SOURCE" "$LINENO" '"$handler_func" ERR
    ERROR_HANDLER_SET=1

    return 0
}

function __error_handler() {
    : 'Internal error handler called by ERR trap

    @private
    '
    local exit_code="$1"
    local command="$2"
    local source_file="$3"
    local line_number="$4"
    local custom_handler="${5:-}"

    # Skip if error code is 0 (sometimes ERR trap fires on success)
    [[ "$exit_code" -eq 0 ]] && return 0

    # Update global error state
    ERROR_CODE="$exit_code"
    ERROR_MESSAGE="Command failed: $command"
    ERROR_SOURCE="$source_file"
    ERROR_LINE="$line_number"

    # Call custom handler if set
    if [[ -n "$custom_handler" ]]; then
        "$custom_handler" "$exit_code" "$command" "$source_file" "$line_number"
        return $?
    fi

    # Default error output
    echo "ERROR: $ERROR_MESSAGE" >&2
    echo "  Location: $ERROR_SOURCE:$ERROR_LINE" >&2
    echo "  Exit code: $ERROR_CODE" >&2

    # Show stack trace if enabled
    if [[ "$ERROR_TRACE_ENABLED" -eq 1 ]]; then
        stack-trace >&2
    fi

    # Exit if strict mode is enabled
    if [[ "$ERROR_EXIT_ON_ERROR" -eq 1 ]]; then
        exit "$exit_code"
    fi

    return "$exit_code"
}

function throw() {
    : 'Throw an error with a custom message

    Triggers the error handler with a custom message and optional exit code.

    @arg $1 Error message
    @arg $2 [optional] Exit code (default: 1)
    @return Never returns, always exits with the specified code
    @example throw "Invalid configuration"
    @example throw "File not found" 2
    '
    local message="${1:-Error}"
    local exit_code="${2:-1}"

    # Update error state
    ERROR_CODE="$exit_code"
    ERROR_MESSAGE="$message"
    ERROR_SOURCE="${BASH_SOURCE[1]:-unknown}"
    ERROR_LINE="${BASH_LINENO[0]:-0}"

    # Print error message
    echo "ERROR: $message" >&2
    if [[ "$ERROR_TRACE_ENABLED" -eq 1 ]]; then
        stack-trace >&2
    fi

    # Exit with error code
    exit "$exit_code"
}

function try() {
    : 'Start a try-catch block (bash 4+ pseudo-implementation)

    This is a pseudo-implementation of try-catch for bash. Must be paired with catch.
    Works by temporarily disabling exit on error and capturing the result.

    @stdout Sets up error capture context
    @example
        try
            command_that_might_fail
            another_risky_command
        catch
            echo "Error caught: $ERROR_MESSAGE"
        endtry
    '
    [[ -n "${TRY_CATCH_LEVEL:-}" ]] && TRY_CATCH_LEVEL=$((TRY_CATCH_LEVEL + 1)) || TRY_CATCH_LEVEL=1

    # Save current error settings
    eval "TRY_CATCH_OLD_ERRMODE_$TRY_CATCH_LEVEL=\$-"
    eval "TRY_CATCH_OLD_PIPEFAIL_$TRY_CATCH_LEVEL=\$(shopt -po pipefail || true)"

    # Disable exit on error for try block
    set +e
    set +o pipefail

    # Reset error state
    ERROR_CODE=0
    ERROR_MESSAGE=""

    # Mark try block start
    eval "TRY_CATCH_ACTIVE_$TRY_CATCH_LEVEL=1"
}

function catch() {
    : 'Catch errors from try block

    Must follow a try block. The code after catch runs only if an error occurred.

    @stdout Checks for errors and conditionally executes catch block
    @example See try function example
    '
    local level="${TRY_CATCH_LEVEL:-0}"

    if [[ "$level" -eq 0 ]]; then
        echo "Error: catch without try" >&2
        return 1
    fi

    # Check if we had an error
    local try_active
    eval "try_active=\${TRY_CATCH_ACTIVE_$level:-0}"

    if [[ "$try_active" -eq 1 ]]; then
        # Capture the last error code
        local last_error=$?
        ERROR_CODE=${ERROR_CODE:-$last_error}

        # Mark that we're in catch block
        eval "TRY_CATCH_ACTIVE_$level=0"
        eval "TRY_CATCH_IN_CATCH_$level=1"

        # Execute catch block only if there was an error
        if [[ "$ERROR_CODE" -ne 0 ]] || [[ "$last_error" -ne 0 ]]; then
            return 0  # Execute catch block
        else
            return 1  # Skip catch block
        fi
    fi

    return 1
}

function endtry() {
    : 'End a try-catch block and restore error settings

    Must be called after catch to properly restore error handling state.

    @stdout Restores previous error handling settings
    @example See try function example
    '
    local level="${TRY_CATCH_LEVEL:-0}"

    if [[ "$level" -eq 0 ]]; then
        echo "Error: endtry without try" >&2
        return 1
    fi

    # Restore error settings
    local old_errmode old_pipefail
    eval "old_errmode=\${TRY_CATCH_OLD_ERRMODE_$level:-}"
    eval "old_pipefail=\${TRY_CATCH_OLD_PIPEFAIL_$level:-}"

    # Restore exit on error if it was set
    if [[ "$old_errmode" == *e* ]]; then
        set -e
    fi

    # Restore pipefail if it was set
    if [[ "$old_pipefail" == *pipefail* ]]; then
        set -o pipefail
    fi

    # Clean up variables
    unset "TRY_CATCH_ACTIVE_$level"
    unset "TRY_CATCH_IN_CATCH_$level"
    unset "TRY_CATCH_OLD_ERRMODE_$level"
    unset "TRY_CATCH_OLD_PIPEFAIL_$level"

    # Decrement level
    if [[ "$level" -gt 1 ]]; then
        TRY_CATCH_LEVEL=$((level - 1))
    else
        unset TRY_CATCH_LEVEL
    fi
}

function stack-trace() {
    : 'Print a stack trace of the current call stack

    Shows the function call hierarchy leading to the current point.
    Useful for debugging and error reporting.

    @stdout Stack trace with function names, files, and line numbers
    @example stack-trace
    @example stack-trace >&2  # Send to stderr
    '
    local frame=0
    local func file line

    echo "Stack trace:"
    while true; do
        # Get frame info
        func="${FUNCNAME[$frame]:-}"
        file="${BASH_SOURCE[$frame]:-}"
        line="${BASH_LINENO[$((frame - 1))]:-}"

        # Stop at main script level
        [[ -z "$func" ]] || [[ "$func" == "main" ]] && break

        # Skip internal error handling functions
        if [[ "$func" == "__error_handler" ]] || [[ "$func" == "stack-trace" ]]; then
            ((frame++))
            continue
        fi

        # Format and print frame
        if [[ "$frame" -eq 0 ]]; then
            echo "  -> in $func() at $file:$line"
        else
            echo "     in $func() at $file:$line"
        fi

        ((frame++))

        # Prevent infinite loops
        [[ "$frame" -gt 50 ]] && break
    done
}

function error-reset() {
    : 'Reset global error state variables

    Clears all error-related global variables. Useful after handling an error.

    @return 0
    @example error-reset
    '
    ERROR_CODE=0
    ERROR_MESSAGE=""
    ERROR_SOURCE=""
    ERROR_LINE=0
}

function error-info() {
    : 'Display current error state information

    Shows all error-related global variables for debugging.

    @stdout Current error state
    @example error-info
    '
    echo "Error State Information:"
    echo "  ERROR_CODE: $ERROR_CODE"
    echo "  ERROR_MESSAGE: $ERROR_MESSAGE"
    echo "  ERROR_SOURCE: $ERROR_SOURCE"
    echo "  ERROR_LINE: $ERROR_LINE"
    echo "  ERROR_TRACE_ENABLED: $ERROR_TRACE_ENABLED"
    echo "  ERROR_EXIT_ON_ERROR: $ERROR_EXIT_ON_ERROR"
    echo "  ERROR_HANDLER_SET: $ERROR_HANDLER_SET"
}

# Convenience aliases
alias try-catch='try'
alias try-catch-end='endtry'