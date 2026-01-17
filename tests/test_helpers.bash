#!/usr/bin/env bash
# test_helpers.bash - Test framework helpers for shell library tests
#
# This file provides reusable test helpers including assertion functions,
# mock utilities, and data generators for use in bats test files.

#------------------------------------------------------------------------------
# Core Functions
#------------------------------------------------------------------------------

fail() {
    : 'Fail with a message

        Causes the test to fail with the given message.

        @arg $1 The failure message

        @usage
            fail "Expected foo but got bar"
    '
    echo "$@" >&2
    return 1
}

#------------------------------------------------------------------------------
# Assertion Functions
#------------------------------------------------------------------------------

assert_empty() {
    : 'Assert that a value is empty

        Tests if the given value is empty (zero length string).

        @arg $1 The value to test
        @arg $2 (optional) Custom failure message

        @usage
            assert_empty "$var"
            assert_empty "$var" "Variable should be empty"

        @example
            local empty_var=""
            assert_empty "$empty_var"  # passes

            local non_empty="hello"
            assert_empty "$non_empty"  # fails with: Expected empty, got: hello
    '
    if [[ -n "$1" ]]; then
        local message="${2:-Expected empty, got: $1}"
        fail "$message"
    fi
}

assert_not_empty() {
    : 'Assert that a value is not empty

        Tests if the given value is not empty (has length > 0).

        @arg $1 The value to test
        @arg $2 (optional) Custom failure message

        @usage
            assert_not_empty "$var"
            assert_not_empty "$var" "Variable should have a value"

        @example
            local var="hello"
            assert_not_empty "$var"  # passes

            local empty=""
            assert_not_empty "$empty"  # fails with: Expected non-empty value
    '
    if [[ -z "$1" ]]; then
        local message="${2:-Expected non-empty value}"
        fail "$message"
    fi
}

assert_contains() {
    : 'Assert that a string contains a substring

        Tests if the first string contains the second string as a substring.

        @arg $1 The string to search in
        @arg $2 The substring to search for
        @arg $3 (optional) Custom failure message

        @usage
            assert_contains "$output" "expected"
            assert_contains "$output" "error" "Should contain error message"

        @example
            local text="Hello, World!"
            assert_contains "$text" "World"  # passes
            assert_contains "$text" "Goodbye"  # fails
    '
    if [[ "$1" != *"$2"* ]]; then
        local message="${3:-$1 does not contain $2}"
        fail "$message"
    fi
}

assert_not_contains() {
    : 'Assert that a string does not contain a substring

        Tests if the first string does not contain the second string.

        @arg $1 The string to search in
        @arg $2 The substring that should not be present
        @arg $3 (optional) Custom failure message

        @usage
            assert_not_contains "$output" "error"
            assert_not_contains "$output" "debug" "Should not have debug output"

        @example
            local text="Hello, World!"
            assert_not_contains "$text" "Goodbye"  # passes
            assert_not_contains "$text" "World"  # fails
    '
    if [[ "$1" == *"$2"* ]]; then
        local message="${3:-$1 should not contain $2}"
        fail "$message"
    fi
}

assert_matches() {
    : 'Assert that a string matches a regex pattern

        Tests if the string matches the given regular expression.

        @arg $1 The string to test
        @arg $2 The regex pattern to match
        @arg $3 (optional) Custom failure message

        @usage
            assert_matches "$output" "^[0-9]+$"
            assert_matches "$email" ".*@.*\..*" "Should be valid email"

        @example
            local version="v1.2.3"
            assert_matches "$version" "^v[0-9]+\.[0-9]+\.[0-9]+$"  # passes

            local text="hello"
            assert_matches "$text" "^[0-9]+$"  # fails (not numeric)
    '
    if ! [[ "$1" =~ $2 ]]; then
        local message="${3:-$1 does not match regex $2}"
        fail "$message"
    fi
}

assert_not_matches() {
    : 'Assert that a string does not match a regex pattern

        Tests if the string does not match the given regular expression.

        @arg $1 The string to test
        @arg $2 The regex pattern that should not match
        @arg $3 (optional) Custom failure message

        @usage
            assert_not_matches "$output" "ERROR|FAIL"
            assert_not_matches "$path" "^/tmp" "Should not be in /tmp"

        @example
            local text="hello"
            assert_not_matches "$text" "^[0-9]+$"  # passes (not numeric)

            local number="12345"
            assert_not_matches "$number" "^[0-9]+$"  # fails
    '
    if [[ "$1" =~ $2 ]]; then
        local message="${3:-$1 should not match regex $2}"
        fail "$message"
    fi
}

assert_equals() {
    : 'Assert that two values are equal

        Tests if two values are exactly equal using string comparison.

        @arg $1 The actual value
        @arg $2 The expected value
        @arg $3 (optional) Custom failure message

        @usage
            assert_equals "$result" "expected"
            assert_equals "$count" "5" "Count should be 5"

        @example
            local result="success"
            assert_equals "$result" "success"  # passes
            assert_equals "$result" "failure"  # fails
    '
    if [[ "$1" != "$2" ]]; then
        local message="${3:-Expected '$2' but got '$1'}"
        fail "$message"
    fi
}

assert_not_equals() {
    : 'Assert that two values are not equal

        Tests if two values are different.

        @arg $1 The actual value
        @arg $2 The value that should be different
        @arg $3 (optional) Custom failure message

        @usage
            assert_not_equals "$result" "error"
            assert_not_equals "$status" "0" "Should have non-zero status"

        @example
            local result="success"
            assert_not_equals "$result" "failure"  # passes
            assert_not_equals "$result" "success"  # fails
    '
    if [[ "$1" == "$2" ]]; then
        local message="${3:-Expected values to be different, but both are '$1'}"
        fail "$message"
    fi
}

assert_file_exists() {
    : 'Assert that a file exists

        Tests if the given file path exists.

        @arg $1 The file path to check
        @arg $2 (optional) Custom failure message

        @usage
            assert_file_exists "/tmp/test.txt"
            assert_file_exists "$output_file" "Output file should be created"

        @example
            touch /tmp/myfile
            assert_file_exists "/tmp/myfile"  # passes
            assert_file_exists "/tmp/nonexistent"  # fails
    '
    if [[ ! -f "$1" ]]; then
        local message="${2:-File does not exist: $1}"
        fail "$message"
    fi
}

assert_file_not_exists() {
    : 'Assert that a file does not exist

        Tests if the given file path does not exist.

        @arg $1 The file path to check
        @arg $2 (optional) Custom failure message

        @usage
            assert_file_not_exists "/tmp/test.txt"
            assert_file_not_exists "$temp_file" "Temp file should be cleaned up"

        @example
            assert_file_not_exists "/tmp/nonexistent"  # passes

            touch /tmp/myfile
            assert_file_not_exists "/tmp/myfile"  # fails
    '
    if [[ -f "$1" ]]; then
        local message="${2:-File should not exist: $1}"
        fail "$message"
    fi
}

assert_directory_exists() {
    : 'Assert that a directory exists

        Tests if the given directory path exists.

        @arg $1 The directory path to check
        @arg $2 (optional) Custom failure message

        @usage
            assert_directory_exists "/tmp"
            assert_directory_exists "$work_dir" "Work directory should exist"

        @example
            mkdir -p /tmp/mydir
            assert_directory_exists "/tmp/mydir"  # passes
            assert_directory_exists "/tmp/nonexistent"  # fails
    '
    if [[ ! -d "$1" ]]; then
        local message="${2:-Directory does not exist: $1}"
        fail "$message"
    fi
}

#------------------------------------------------------------------------------
# Mock/Stub Functions
#------------------------------------------------------------------------------

mock_command() {
    : 'Create a mock function that replaces a command

        Creates a bash function that overrides a command and logs its calls.
        The mock prints "MOCK: <command> <args>" to stderr when called.

        @arg $1 The command name to mock
        @arg $2 (optional) Return value for the mock (default: 0)
        @arg $3 (optional) Output to print to stdout

        @usage
            mock_command "git"
            mock_command "curl" 1  # mock that returns error
            mock_command "cat" 0 "mocked file content"

        @example
            # Mock git command
            mock_command "git"
            git status  # prints "MOCK: git status" to stderr

            # Mock with custom output
            mock_command "date" 0 "2024-01-01"
            result=$(date)  # result is "2024-01-01"

        @see restore_command() to remove the mock
    '
    local cmd="$1"
    local return_code="${2:-0}"
    local output="${3:-}"

    eval "
    $cmd() {
        echo 'MOCK: $cmd \$*' >&2
        [[ -n '$output' ]] && echo '$output'
        return $return_code
    }"
}

restore_command() {
    : 'Remove a mock function and restore original command

        Removes a function created by mock_command, allowing the original
        command to be used again.

        @arg $1 The command name to restore

        @usage
            restore_command "git"

        @example
            mock_command "date"
            date  # uses mock

            restore_command "date"
            date  # uses real date command
    '
    unset -f "$1"
}

mock_function() {
    : 'Create a mock function with custom behavior

        Creates a mock function that can track calls and provide custom responses.
        More flexible than mock_command for complex mocking scenarios.

        @arg $1 The function name to mock
        @arg $2 The mock implementation as a string

        @usage
            mock_function "my_func" 'echo "mocked"; return 0'
            mock_function "complex_func" 'echo "$1" | tr a-z A-Z'

        @example
            # Simple mock
            mock_function "get_user" 'echo "test_user"'
            user=$(get_user)  # user is "test_user"

            # Mock with argument handling
            mock_function "process" '[[ "$1" == "fail" ]] && return 1 || return 0'
            process "ok"  # returns 0
            process "fail"  # returns 1
    '
    local func="$1"
    local implementation="$2"

    eval "$func() { $implementation; }"
}

stub_command() {
    : 'Create a stub command that does nothing

        Creates a function that replaces a command but does nothing except
        return the specified exit code. Useful for preventing side effects.

        @arg $1 The command name to stub
        @arg $2 (optional) Return code (default: 0)

        @usage
            stub_command "rm"  # prevent file deletion in tests
            stub_command "exit" 1  # stub that always fails

        @example
            stub_command "sendmail"
            sendmail user@example.com < email.txt  # does nothing

            stub_command "false" 0  # make false return true
            false && echo "This prints!"
    '
    local cmd="$1"
    local return_code="${2:-0}"

    eval "$cmd() { return $return_code; }"
}

#------------------------------------------------------------------------------
# Test Data Generators
#------------------------------------------------------------------------------

generate_temp_file() {
    : 'Generate a temporary file for testing

        Creates a temporary file in the BATS test directory that will be
        automatically cleaned up after the test.

        @arg $1 (optional) Suffix for the temp file
        @arg $2 (optional) Content to write to the file

        @stdout The path to the created temporary file

        @usage
            local temp=$(generate_temp_file)
            local config=$(generate_temp_file ".conf")
            local data=$(generate_temp_file ".txt" "test content")

        @example
            # Create empty temp file
            local temp=$(generate_temp_file)
            echo "data" > "$temp"

            # Create temp file with content
            local config=$(generate_temp_file ".json" '{"key": "value"}')

            # File is automatically cleaned after test
    '
    local suffix="${1:-}"
    local content="${2:-}"
    local template="test.XXXXXX${suffix}"

    local temp_file
    if [[ -n "${BATS_TEST_TMPDIR:-}" ]]; then
        temp_file=$(mktemp "${BATS_TEST_TMPDIR}/${template}")
    else
        temp_file=$(mktemp "/tmp/${template}")
    fi

    if [[ -n "$content" ]]; then
        echo "$content" > "$temp_file"
    fi

    echo "$temp_file"
}

generate_temp_dir() {
    : 'Generate a temporary directory for testing

        Creates a temporary directory in the BATS test directory that will be
        automatically cleaned up after the test.

        @arg $1 (optional) Suffix for the directory name

        @stdout The path to the created temporary directory

        @usage
            local tempdir=$(generate_temp_dir)
            local workdir=$(generate_temp_dir ".work")

        @example
            local dir=$(generate_temp_dir)
            touch "$dir/file1.txt"
            mkdir "$dir/subdir"

            # Directory is automatically cleaned after test
    '
    local suffix="${1:-}"
    local template="testdir.XXXXXX${suffix}"

    if [[ -n "${BATS_TEST_TMPDIR:-}" ]]; then
        mktemp -d "${BATS_TEST_TMPDIR}/${template}"
    else
        mktemp -d "/tmp/${template}"
    fi
}

generate_csv_data() {
    : 'Generate sample CSV data for testing

        Creates CSV data with the specified number of rows and columns.
        Useful for testing CSV parsing functions.

        @arg $1 (optional) Number of rows (default: 5)
        @arg $2 (optional) Number of columns (default: 3)
        @arg $3 (optional) Include header row (default: true)

        @stdout The generated CSV data

        @usage
            generate_csv_data > data.csv
            generate_csv_data 10 4 > large.csv
            generate_csv_data 3 2 false > no_header.csv

        @example
            # Generate default CSV (5 rows, 3 columns, with header)
            local csv=$(generate_csv_data)
            # Output:
            # header1,header2,header3
            # row1_col1,row1_col2,row1_col3
            # row2_col1,row2_col2,row2_col3
            # ...

            # Generate without header
            local data=$(generate_csv_data 2 2 false)
            # Output:
            # row1_col1,row1_col2
            # row2_col1,row2_col2
    '
    local rows="${1:-5}"
    local cols="${2:-3}"
    local include_header="${3:-true}"

    # Generate header if requested
    if [[ "$include_header" == "true" ]]; then
        local header=""
        for ((c=1; c<=cols; c++)); do
            [[ -n "$header" ]] && header+=","
            header+="header${c}"
        done
        echo "$header"
    fi

    # Generate data rows
    for ((r=1; r<=rows; r++)); do
        local row=""
        for ((c=1; c<=cols; c++)); do
            [[ -n "$row" ]] && row+=","
            row+="row${r}_col${c}"
        done
        echo "$row"
    done
}

generate_json_data() {
    : 'Generate sample JSON data for testing

        Creates JSON data with various types of values for testing JSON
        parsing and manipulation functions.

        @arg $1 (optional) Type of JSON to generate: simple, nested, array

        @stdout The generated JSON data

        @usage
            generate_json_data > data.json
            generate_json_data "nested" > complex.json
            generate_json_data "array" > list.json

        @example
            # Generate simple JSON
            local json=$(generate_json_data)
            # Output: {"name":"test","value":123,"active":true}

            # Generate nested JSON
            local nested=$(generate_json_data "nested")
            # Output: {"user":{"name":"test","age":25},"settings":{"theme":"dark"}}

            # Generate array JSON
            local array=$(generate_json_data "array")
            # Output: [{"id":1,"name":"item1"},{"id":2,"name":"item2"}]
    '
    local type="${1:-simple}"

    case "$type" in
        simple)
            echo '{"name":"test","value":123,"active":true,"tags":["tag1","tag2"]}'
            ;;
        nested)
            echo '{"user":{"name":"test","age":25,"email":"test@example.com"},"settings":{"theme":"dark","notifications":true},"meta":{"created":"2024-01-01","updated":"2024-01-02"}}'
            ;;
        array)
            echo '[{"id":1,"name":"item1","status":"active"},{"id":2,"name":"item2","status":"inactive"},{"id":3,"name":"item3","status":"active"}]'
            ;;
        *)
            echo '{"error":"Unknown type: '"$type"'"}'
            ;;
    esac
}

generate_random_string() {
    : 'Generate a random string for testing

        Creates a random string of specified length using alphanumeric characters.

        @arg $1 (optional) Length of string (default: 10)
        @arg $2 (optional) Character set: alnum, alpha, lower, upper, digit

        @stdout The generated random string

        @usage
            local random=$(generate_random_string)
            local long_random=$(generate_random_string 32)
            local numbers=$(generate_random_string 6 "digit")

        @example
            # Generate 10-character alphanumeric string
            local code=$(generate_random_string)
            # Output: x7Kp9mN2Qr

            # Generate 8-digit number string
            local pin=$(generate_random_string 8 "digit")
            # Output: 58239461

            # Generate uppercase string
            local key=$(generate_random_string 16 "upper")
            # Output: XKQMNPRTUVWXYZAB
    '
    local length="${1:-10}"
    local charset="${2:-alnum}"

    local chars
    case "$charset" in
        alnum)  chars='a-zA-Z0-9' ;;
        alpha)  chars='a-zA-Z' ;;
        lower)  chars='a-z' ;;
        upper)  chars='A-Z' ;;
        digit)  chars='0-9' ;;
        *)      chars='a-zA-Z0-9' ;;
    esac

    tr -dc "$chars" < /dev/urandom | head -c "$length" || true
    echo
}

generate_test_script() {
    : 'Generate a test shell script with specific content

        Creates a shell script for testing script execution, argument parsing, etc.

        @arg $1 (optional) Script content (default: simple echo script)
        @arg $2 (optional) Make executable (default: true)

        @stdout The path to the created script

        @usage
            local script=$(generate_test_script)
            local custom=$(generate_test_script 'echo "$@"')
            local noexec=$(generate_test_script 'exit 1' false)

        @example
            # Generate basic test script
            local script=$(generate_test_script)
            "$script"  # outputs: "Hello from test script"

            # Generate script with custom content
            local counter=$(generate_test_script 'echo $((COUNTER++))')

            # Script is automatically cleaned after test
    '
    local content="${1:-echo 'Hello from test script'}"
    local make_executable="${2:-true}"

    local script=$(generate_temp_file ".sh")

    cat > "$script" << EOF
#!/usr/bin/env bash
$content
EOF

    if [[ "$make_executable" == "true" ]]; then
        chmod +x "$script"
    fi

    echo "$script"
}

#------------------------------------------------------------------------------
# Test Environment Helpers
#------------------------------------------------------------------------------

save_function() {
    : 'Save a function definition for later restoration

        Saves the current definition of a function so it can be restored later.
        Useful when you need to temporarily override a function in tests.

        @arg $1 The function name to save

        @usage
            save_function "original_func"
            mock_function "original_func" 'echo "mocked"'
            # ... run tests ...
            restore_function "original_func"

        @example
            # Save original function
            save_function "get_date"

            # Override it
            get_date() { echo "2024-01-01"; }

            # Use mock in test
            result=$(get_date)  # returns "2024-01-01"

            # Restore original
            eval "$SAVED_FUNC_get_date"
    '
    local func="$1"
    local saved_var="SAVED_FUNC_${func}"

    # Save function definition
    eval "$saved_var=\"\$(declare -f $func)\""
}

with_env() {
    : 'Run a command with temporary environment variables

        Executes a command with specified environment variables set, then
        restores the original environment.

        @arg $1 Variable assignments (space-separated)
        @arg $2+ Command and arguments to run

        @usage
            with_env "FOO=bar BAZ=qux" some_command
            with_env "PATH=/custom/path:$PATH" which mycommand

        @example
            # Run with temporary variables
            with_env "DEBUG=1 VERBOSE=true" ./script.sh

            # Original environment is restored after execution
            echo "$DEBUG"  # original value or empty
    '
    local env_vars="$1"
    shift

    # Execute with temporary environment
    env $env_vars "$@"
}

#------------------------------------------------------------------------------
# Utility Functions
#------------------------------------------------------------------------------

skip_if_missing() {
    : 'Skip test if a required command is missing

        Checks if a command exists and skips the test if not found.
        Useful for tests that depend on optional tools.

        @arg $1 The command to check for
        @arg $2 (optional) Skip message

        @usage
            skip_if_missing "jq"
            skip_if_missing "docker" "Docker is required for this test"

        @example
            @test "parse JSON with jq" {
                skip_if_missing "jq"

                result=$(echo '{"key":"value"}' | jq -r .key)
                assert_equals "$result" "value"
            }
    '
    local cmd="$1"
    local message="${2:-$cmd is required for this test}"

    if ! command -v "$cmd" &>/dev/null; then
        skip "$message"
    fi
}

setup_test_repo() {
    : 'Set up a temporary git repository for testing

        Creates a temporary git repository with initial commit for testing
        git-related functions.

        @arg $1 (optional) Repository name

        @stdout The path to the created repository

        @usage
            local repo=$(setup_test_repo)
            local named_repo=$(setup_test_repo "my-test-repo")

        @example
            local repo=$(setup_test_repo)
            cd "$repo"

            # Repo has initial commit
            git log --oneline  # shows "Initial commit"

            # Add more commits for testing
            echo "test" > file.txt
            git add file.txt
            git commit -m "Add test file"
    '
    local repo_name="${1:-test-repo}"
    local repo_dir=$(generate_temp_dir ".$repo_name")

    cd "$repo_dir"
    git init --quiet
    git config user.email "test@example.com"
    git config user.name "Test User"

    # Create initial commit
    echo "# $repo_name" > README.md
    git add README.md
    git commit --quiet -m "Initial commit"

    echo "$repo_dir"
}

# Export all functions for use in test files
export -f assert_empty assert_not_empty assert_contains assert_not_contains
export -f assert_matches assert_not_matches assert_equals assert_not_equals
export -f assert_file_exists assert_file_not_exists assert_directory_exists
export -f mock_command restore_command mock_function stub_command
export -f generate_temp_file generate_temp_dir generate_csv_data
export -f generate_json_data generate_random_string generate_test_script
export -f save_function with_env skip_if_missing setup_test_repo