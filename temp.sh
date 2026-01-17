#!/usr/bin/env bash
: 'Temporary file and directory management library

This library provides functions for creating and managing temporary files and
directories with automatic cleanup on exit. All temporary resources are tracked
and cleaned up via EXIT traps to prevent leaving orphaned files.

Key features:
- Create temporary files and directories with guaranteed cleanup
- Execute code in temporary directories with automatic cleanup
- Track all temporary resources for batch cleanup
- Support for custom mktemp options
- Works correctly with command substitution

Example usage:
```bash
# Create a temp file
tmp_file=$(temp-file)
echo "data" > "$tmp_file"
# File is automatically cleaned up on exit

# Create a temp directory
tmp_dir=$(temp-dir)
# Directory is automatically cleaned up on exit

# Execute code in a temp directory
with-temp-dir 'echo "Working in: $PWD"; touch file.txt'

# Manual cleanup if needed
temp-cleanup
```
'

# File to track temporary resources (process-specific)
declare -g __TEMP_TRACKING_FILE="${TMPDIR:-/tmp}/.temp-lib-$$-tracking"

# Ensure tracking file is cleaned up on exit
trap 'rm -f "$__TEMP_TRACKING_FILE"' EXIT

function temp-file() {
    : 'Create a temporary file with automatic cleanup on exit

        Creates a temporary file using mktemp and registers it for automatic
        cleanup when the shell exits. The file path is returned on stdout.

        @usage
            [options...]

        @optarg options
            Options to pass to mktemp (e.g., --suffix=.txt)

        @stdout
            Path to the created temporary file

        @example
            tmp=$(temp-file)
            echo "data" > "$tmp"

            # With suffix
            tmp=$(temp-file --suffix=.json)
            echo "{}" > "$tmp"
    '
    local temp_file
    local mktemp_opts=("$@")

    # Create the temporary file
    temp_file=$(mktemp "${mktemp_opts[@]}") || {
        echo "temp-file: failed to create temporary file" >&2
        return 1
    }

    # Register for cleanup
    __temp-register "$temp_file"

    # Return the path
    echo "$temp_file"
}

function temp-dir() {
    : 'Create a temporary directory with automatic cleanup on exit

        Creates a temporary directory using mktemp and registers it for
        automatic cleanup when the shell exits. The directory path is
        returned on stdout.

        @usage
            [options...]

        @optarg options
            Options to pass to mktemp (e.g., --suffix=.tmp)

        @stdout
            Path to the created temporary directory

        @example
            tmp_dir=$(temp-dir)
            touch "$tmp_dir/file.txt"

            # With suffix
            tmp_dir=$(temp-dir --suffix=.build)
    '
    local temp_dir
    local mktemp_opts=(-d "$@")

    # Create the temporary directory
    temp_dir=$(mktemp "${mktemp_opts[@]}") || {
        echo "temp-dir: failed to create temporary directory" >&2
        return 1
    }

    # Register for cleanup
    __temp-register "$temp_dir"

    # Return the path
    echo "$temp_dir"
}

function temp-cleanup() {
    : 'Clean up all registered temporary files and directories

        Removes all temporary files and directories that have been created
        by temp-file and temp-dir. This is automatically called on EXIT but
        can be called manually if needed.

        @usage
            (no arguments)

        @return 0
            All resources cleaned up successfully

        @return 1
            One or more resources failed to clean up

        @stderr
            Error messages for any cleanup failures
    '
    local resource
    local failed=0

    # Check if tracking file exists
    [[ -f "$__TEMP_TRACKING_FILE" ]] || return 0

    # Read and clean up resources in reverse order
    while IFS= read -r resource; do
        # Skip empty lines
        [[ -n "$resource" ]] || continue

        # Skip if already cleaned up
        [[ -e "$resource" ]] || continue

        # Remove the resource
        if [[ -d "$resource" ]]; then
            if ! rm -rf "$resource" 2>/dev/null; then
                echo "temp-cleanup: failed to remove directory: $resource" >&2
                failed=1
            fi
        elif [[ -f "$resource" ]] || [[ -L "$resource" ]]; then
            if ! rm -f "$resource" 2>/dev/null; then
                echo "temp-cleanup: failed to remove file: $resource" >&2
                failed=1
            fi
        fi
    done < <(awk '{a[NR]=$0} END {for (i=NR; i>0; i--) print a[i]}' "$__TEMP_TRACKING_FILE" 2>/dev/null)

    # Clear the tracking file
    : > "$__TEMP_TRACKING_FILE"

    return $failed
}

function with-temp-dir() {
    : 'Execute commands in a temporary directory

        Creates a temporary directory, changes to it, executes the provided
        commands, then returns to the original directory. The temporary
        directory is automatically cleaned up.

        @usage
            <command>

        @arg command
            Command string to execute in the temporary directory

        @return
            Exit status of the executed command

        @example
            with-temp-dir "echo Working in: \$PWD; touch file.txt"

            # Multi-line command
            with-temp-dir "echo Building project...; make; make test"
    '
    local command="$1"
    local original_dir="$PWD"
    local temp_dir
    local exit_code=0

    # Validate arguments
    if [[ -z "$command" ]]; then
        echo "with-temp-dir: no command provided" >&2
        return 1
    fi

    # Create temporary directory - but don't register it for auto-cleanup
    # since we'll clean it up manually
    temp_dir=$(mktemp -d) || {
        echo "with-temp-dir: failed to create temporary directory" >&2
        return 1
    }

    # Execute command in temp directory
    (
        cd "$temp_dir" || exit 1
        eval "$command"
    )
    exit_code=$?

    # Clean up the temp directory
    rm -rf "$temp_dir" 2>/dev/null || true

    return $exit_code
}

function __temp-register() {
    : 'Register a resource for cleanup (internal function)

        @usage
            <path>

        @arg path
            Path to register for cleanup
    '
    local resource="$1"

    # Add to tracking file
    echo "$resource" >> "$__TEMP_TRACKING_FILE"

    # Set up EXIT trap if not already set (only in main shell)
    if [[ "${BASH_SUBSHELL:-0}" -eq 0 ]]; then
        if ! trap -p EXIT | grep -q "temp-cleanup"; then
            # Get existing trap, handling the tracking file cleanup
            local existing_trap
            existing_trap=$(trap -p EXIT | grep -v "__TEMP_TRACKING_FILE" | sed "s/^trap -- '\\(.*\\)' EXIT$/\\1/")

            # Build new trap command
            local new_trap="temp-cleanup; rm -f \"\$__TEMP_TRACKING_FILE\""

            if [[ -n "$existing_trap" ]]; then
                # Preserve existing trap
                new_trap="${existing_trap}; ${new_trap}"
            fi

            trap "$new_trap" EXIT
        fi
    fi
}

# Helper function to get list of tracked resources (for testing)
function __temp-list-resources() {
    : 'List all tracked temporary resources (internal function)

        @stdout
            List of tracked resources, one per line
    '
    if [[ -f "$__TEMP_TRACKING_FILE" ]]; then
        cat "$__TEMP_TRACKING_FILE"
    fi
}