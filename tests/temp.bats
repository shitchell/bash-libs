#!/usr/bin/env bats

# Test suite for temp.sh library

# Setup and teardown
setup() {
    # Source the library
    source "$(dirname "$BATS_TEST_DIRNAME")/include.sh" --set-libdir
    include-source 'temp.sh'

    # Store original trap state
    ORIGINAL_TRAP=$(trap -p EXIT)

    # Clear any existing temp resources
    __TEMP_RESOURCES=()
}

teardown() {
    # Ensure cleanup happens
    temp-cleanup 2>/dev/null || true

    # Restore original trap if needed
    if [[ -n "$ORIGINAL_TRAP" ]]; then
        eval "$ORIGINAL_TRAP"
    else
        trap - EXIT
    fi
}

# Helper functions
count_temp_resources() {
    echo "${#__TEMP_RESOURCES[@]}"
}

resource_exists() {
    local resource="$1"
    [[ -e "$resource" ]]
}

# Tests for temp-file
@test "temp-file creates a file" {
    local tmp_file
    tmp_file=$(temp-file)

    [[ -n "$tmp_file" ]]
    [[ -f "$tmp_file" ]]
}

@test "temp-file registers file for cleanup" {
    local count_before count_after
    count_before=$(count_temp_resources)

    local tmp_file
    tmp_file=$(temp-file)

    count_after=$(count_temp_resources)
    [[ $count_after -eq $((count_before + 1)) ]]
}

@test "temp-file with suffix" {
    local tmp_file
    tmp_file=$(temp-file --suffix=.txt)

    [[ -f "$tmp_file" ]]
    [[ "$tmp_file" == *.txt ]]
}

@test "temp-file with template" {
    local tmp_file
    tmp_file=$(temp-file --tmpdir=/tmp test.XXXXXX)

    [[ -f "$tmp_file" ]]
    [[ "$tmp_file" == /tmp/test.* ]]
}

@test "temp-file handles mktemp failure" {
    # Try to create a file in a non-existent directory
    run temp-file --tmpdir=/this/does/not/exist

    [[ $status -ne 0 ]]
    [[ "$output" == *"failed to create temporary file"* ]]
}

# Tests for temp-dir
@test "temp-dir creates a directory" {
    local tmp_dir
    tmp_dir=$(temp-dir)

    [[ -n "$tmp_dir" ]]
    [[ -d "$tmp_dir" ]]
}

@test "temp-dir registers directory for cleanup" {
    local count_before count_after
    count_before=$(count_temp_resources)

    local tmp_dir
    tmp_dir=$(temp-dir)

    count_after=$(count_temp_resources)
    [[ $count_after -eq $((count_before + 1)) ]]
}

@test "temp-dir with suffix" {
    local tmp_dir
    tmp_dir=$(temp-dir --suffix=.build)

    [[ -d "$tmp_dir" ]]
    [[ "$tmp_dir" == *.build ]]
}

@test "temp-dir handles mktemp failure" {
    # Try to create a directory in a non-existent directory
    run temp-dir --tmpdir=/this/does/not/exist

    [[ $status -ne 0 ]]
    [[ "$output" == *"failed to create temporary directory"* ]]
}

# Tests for temp-cleanup
@test "temp-cleanup removes files" {
    local tmp_file1 tmp_file2
    tmp_file1=$(temp-file)
    tmp_file2=$(temp-file)

    # Files should exist
    resource_exists "$tmp_file1"
    resource_exists "$tmp_file2"

    # Clean up
    temp-cleanup

    # Files should be gone
    ! resource_exists "$tmp_file1"
    ! resource_exists "$tmp_file2"

    # Resources array should be empty
    [[ $(count_temp_resources) -eq 0 ]]
}

@test "temp-cleanup removes directories" {
    local tmp_dir1 tmp_dir2
    tmp_dir1=$(temp-dir)
    tmp_dir2=$(temp-dir)

    # Create some files in the directories
    touch "$tmp_dir1/file1.txt"
    mkdir "$tmp_dir2/subdir"
    touch "$tmp_dir2/subdir/file2.txt"

    # Directories should exist
    resource_exists "$tmp_dir1"
    resource_exists "$tmp_dir2"

    # Clean up
    temp-cleanup

    # Directories should be gone
    ! resource_exists "$tmp_dir1"
    ! resource_exists "$tmp_dir2"
}

@test "temp-cleanup handles mixed resources" {
    local tmp_file tmp_dir
    tmp_file=$(temp-file)
    tmp_dir=$(temp-dir)

    touch "$tmp_dir/file.txt"

    temp-cleanup

    ! resource_exists "$tmp_file"
    ! resource_exists "$tmp_dir"
}

@test "temp-cleanup handles already cleaned resources" {
    local tmp_file
    tmp_file=$(temp-file)

    # Manually remove the file
    rm -f "$tmp_file"

    # Cleanup should not fail
    run temp-cleanup
    [[ $status -eq 0 ]]
}

@test "temp-cleanup handles cleanup failures" {
    local tmp_dir
    tmp_dir=$(temp-dir)

    # Create a file and make the directory read-only
    touch "$tmp_dir/file.txt"
    chmod -w "$tmp_dir"

    # Cleanup should report failure
    run temp-cleanup
    [[ $status -ne 0 ]]

    # Restore permissions for teardown
    chmod +w "$tmp_dir"
}

# Tests for with-temp-dir
@test "with-temp-dir executes command in temp directory" {
    local original_pwd="$PWD"
    local captured_pwd

    # Capture the working directory inside with-temp-dir
    captured_pwd=$(with-temp-dir 'pwd')

    # Should be different from original
    [[ "$captured_pwd" != "$original_pwd" ]]

    # Should be in /tmp or similar
    [[ "$captured_pwd" == /tmp/* ]] || [[ "$captured_pwd" == /var/folders/* ]]

    # Should be back in original directory
    [[ "$PWD" == "$original_pwd" ]]
}

@test "with-temp-dir cleans up directory" {
    local temp_path

    # Capture the temp directory path
    temp_path=$(with-temp-dir 'pwd')

    # Directory should not exist anymore
    ! resource_exists "$temp_path"
}

@test "with-temp-dir preserves command exit code" {
    # Success case
    run with-temp-dir 'exit 0'
    [[ $status -eq 0 ]]

    # Failure case
    run with-temp-dir 'exit 42'
    [[ $status -eq 42 ]]
}

@test "with-temp-dir handles empty command" {
    run with-temp-dir ''

    [[ $status -ne 0 ]]
    [[ "$output" == *"no command provided"* ]]
}

@test "with-temp-dir handles multi-line commands" {
    local result
    result=$(with-temp-dir '
        echo "line1" > file.txt
        echo "line2" >> file.txt
        cat file.txt
    ')

    [[ "$result" == $'line1\nline2' ]]
}

@test "with-temp-dir returns to original dir on error" {
    local original_pwd="$PWD"

    # Run a command that fails
    run with-temp-dir 'exit 1'

    # Should be back in original directory
    [[ "$PWD" == "$original_pwd" ]]
}

# Tests for EXIT trap integration
@test "EXIT trap is set after first temp resource" {
    # Initially no temp-cleanup in EXIT trap
    trap -p EXIT | grep -q "temp-cleanup" && return 1

    # Create a temp file
    temp-file >/dev/null

    # Now temp-cleanup should be in EXIT trap
    trap -p EXIT | grep -q "temp-cleanup"
}

@test "EXIT trap preserves existing traps" {
    # Set a custom trap
    trap 'echo "existing trap"' EXIT

    # Create a temp file
    temp-file >/dev/null

    # Both traps should be present
    local exit_trap
    exit_trap=$(trap -p EXIT)
    [[ "$exit_trap" == *"existing trap"* ]]
    [[ "$exit_trap" == *"temp-cleanup"* ]]
}

# Tests for thread safety (basic)
@test "concurrent temp-file creation" {
    local pids=()
    local files=()

    # Create multiple temp files in parallel
    for i in {1..5}; do
        (
            temp-file
        ) &
        pids+=($!)
    done

    # Wait and collect results
    for pid in "${pids[@]}"; do
        wait "$pid"
    done

    # All files should be registered
    [[ $(count_temp_resources) -ge 5 ]]
}

# Tests for resource tracking
@test "resources array grows correctly" {
    local count=0

    [[ $(count_temp_resources) -eq $count ]]

    temp-file >/dev/null
    ((count++))
    [[ $(count_temp_resources) -eq $count ]]

    temp-dir >/dev/null
    ((count++))
    [[ $(count_temp_resources) -eq $count ]]

    temp-file >/dev/null
    ((count++))
    [[ $(count_temp_resources) -eq $count ]]
}

@test "cleanup clears resources array" {
    # Create some resources
    temp-file >/dev/null
    temp-dir >/dev/null
    temp-file >/dev/null

    [[ $(count_temp_resources) -eq 3 ]]

    # Clean up
    temp-cleanup

    # Array should be empty
    [[ $(count_temp_resources) -eq 0 ]]
}