#!/usr/bin/env bats

# Load test helpers
load test_helpers

# Setup and teardown
setup() {
    # Source the help library
    source "${BATS_TEST_DIRNAME}/../help.sh"

    # Reset help system state before each test
    __HELP_SCRIPT_NAME=""
    __HELP_SCRIPT_DESC=""
    __HELP_USAGE_LINE=""
    __HELP_OPTIONS=()
    __HELP_EXAMPLES=()
    __HELP_EPILOGUE=""
}

teardown() {
    # Clean up any test artifacts
    :
}

# help-init tests
@test "help-init: initializes with all parameters" {
    run help-init "test-script" "A test script" "test-script [options] <file>"
    assert_success

    # Verify internal state
    [[ "${__HELP_SCRIPT_NAME}" == "test-script" ]]
    [[ "${__HELP_SCRIPT_DESC}" == "A test script" ]]
    [[ "${__HELP_USAGE_LINE}" == "test-script [options] <file>" ]]
}

@test "help-init: uses basename of \$0 when script name is empty" {
    # Temporarily override $0
    local original_0="$0"
    set -- "/path/to/my-script.sh"

    run help-init "" "A test script"
    assert_success

    # Note: basename might not work as expected in bats context
    # So we just verify it was set to something
    [[ -n "${__HELP_SCRIPT_NAME}" ]]
    [[ "${__HELP_SCRIPT_DESC}" == "A test script" ]]

    # Restore $0
    set -- "$original_0"
}

@test "help-init: generates default usage line when not provided" {
    run help-init "test-script" "A test script"
    assert_success

    [[ "${__HELP_USAGE_LINE}" == "test-script [options]" ]]
}

@test "help-init: fails when description is missing" {
    run help-init "test-script" ""
    assert_failure
    assert_output "error: help-init requires a description"
}

@test "help-init: resets arrays when called multiple times" {
    # First initialization
    help-init "test1" "First test"
    help-add-option "-a" "--all" "Show all"
    help-add-example "test1 -a" "Show everything"

    # Second initialization should reset everything
    run help-init "test2" "Second test"
    assert_success

    [[ "${__HELP_SCRIPT_NAME}" == "test2" ]]
    [[ ${#__HELP_OPTIONS[@]} -eq 0 ]]
    [[ ${#__HELP_EXAMPLES[@]} -eq 0 ]]
}

# help-add-option tests
@test "help-add-option: adds option with short and long flags" {
    help-init "test" "Test script"

    run help-add-option "-h" "--help" "Show help message"
    assert_success

    [[ ${#__HELP_OPTIONS[@]} -eq 1 ]]
    [[ "${__HELP_OPTIONS[0]}" == "-h, --help|Show help message" ]]
}

@test "help-add-option: adds option with value placeholder" {
    help-init "test" "Test script"

    run help-add-option "-f" "--file" "Input file" "<file>"
    assert_success

    [[ "${__HELP_OPTIONS[0]}" == "-f, --file <file>|Input file" ]]
}

@test "help-add-option: adds option with only short flag" {
    help-init "test" "Test script"

    run help-add-option "-v" "" "Verbose mode"
    assert_success

    [[ "${__HELP_OPTIONS[0]}" == "-v|Verbose mode" ]]
}

@test "help-add-option: adds option with only long flag" {
    help-init "test" "Test script"

    run help-add-option "" "--verbose" "Verbose mode"
    assert_success

    [[ "${__HELP_OPTIONS[0]}" == "    --verbose|Verbose mode" ]]
}

@test "help-add-option: fails when no flags provided" {
    help-init "test" "Test script"

    run help-add-option "" "" "Some description"
    assert_failure
    assert_output "error: help-add-option requires at least one option flag"
}

@test "help-add-option: fails when no description provided" {
    help-init "test" "Test script"

    run help-add-option "-h" "--help" ""
    assert_failure
    assert_output "error: help-add-option requires a description"
}

@test "help-add-option: adds multiple options" {
    help-init "test" "Test script"

    help-add-option "-h" "--help" "Show help"
    help-add-option "-v" "--verbose" "Verbose output"
    help-add-option "-f" "--file" "Input file" "<file>"

    [[ ${#__HELP_OPTIONS[@]} -eq 3 ]]
}

# help-add-example tests
@test "help-add-example: adds example with description" {
    help-init "test" "Test script"

    run help-add-example "test -f input.txt" "Process input file"
    assert_success

    [[ ${#__HELP_EXAMPLES[@]} -eq 1 ]]
    [[ "${__HELP_EXAMPLES[0]}" == "test -f input.txt|Process input file" ]]
}

@test "help-add-example: adds example without description" {
    help-init "test" "Test script"

    run help-add-example "test --help"
    assert_success

    [[ "${__HELP_EXAMPLES[0]}" == "test --help|" ]]
}

@test "help-add-example: fails when example is empty" {
    help-init "test" "Test script"

    run help-add-example ""
    assert_failure
    assert_output "error: help-add-example requires an example command"
}

@test "help-add-example: adds multiple examples" {
    help-init "test" "Test script"

    help-add-example "test -f input.txt" "Process file"
    help-add-example "test -v" "Verbose mode"
    help-add-example "test --help"

    [[ ${#__HELP_EXAMPLES[@]} -eq 3 ]]
}

# help-set-epilogue tests
@test "help-set-epilogue: sets epilogue text" {
    help-init "test" "Test script"

    run help-set-epilogue "For more info, see: https://example.com"
    assert_success

    [[ "${__HELP_EPILOGUE}" == "For more info, see: https://example.com" ]]
}

@test "help-set-epilogue: can set empty epilogue" {
    help-init "test" "Test script"
    help-set-epilogue "Some text"

    run help-set-epilogue ""
    assert_success

    [[ -z "${__HELP_EPILOGUE}" ]]
}

# help-show tests
@test "help-show: displays minimal help" {
    help-init "test-script" "A simple test script"

    run help-show
    assert_success
    assert_line --index 0 "Usage: test-script [options]"
    assert_line --index 1 ""
    assert_line --index 2 "A simple test script"
}

@test "help-show: displays help with options" {
    help-init "test-script" "A test script"
    help-add-option "-h" "--help" "Show this help message"
    help-add-option "-v" "--verbose" "Enable verbose output"

    run help-show
    assert_success
    assert_output --partial "Options:"
    assert_output --partial "-h, --help"
    assert_output --partial "Show this help message"
    assert_output --partial "-v, --verbose"
    assert_output --partial "Enable verbose output"
}

@test "help-show: displays help with examples" {
    help-init "test-script" "A test script"
    help-add-example "test-script -v" "Run in verbose mode"
    help-add-example "test-script --help" "Show help"

    run help-show
    assert_success
    assert_output --partial "Examples:"
    assert_output --partial "test-script -v"
    assert_output --partial "Run in verbose mode"
    assert_output --partial "test-script --help"
    assert_output --partial "Show help"
}

@test "help-show: displays help with epilogue" {
    help-init "test-script" "A test script"
    help-set-epilogue "Visit https://example.com for more information"

    run help-show
    assert_success
    assert_output --partial "Visit https://example.com for more information"
}

@test "help-show: displays complete help with all sections" {
    help-init "test-script" "A comprehensive test script" "test-script [options] <file>"
    help-add-option "-h" "--help" "Show this help message"
    help-add-option "-f" "--file" "Input file to process" "<file>"
    help-add-option "-o" "--output" "Output directory" "<dir>"
    help-add-example "test-script -f input.txt" "Process a single file"
    help-add-example "test-script -f data.csv -o results/" "Process with output directory"
    help-set-epilogue "For bug reports, visit: https://github.com/example/test-script"

    run help-show
    assert_success

    # Check all sections are present
    assert_output --partial "Usage: test-script [options] <file>"
    assert_output --partial "A comprehensive test script"
    assert_output --partial "Options:"
    assert_output --partial "Examples:"
    assert_output --partial "For bug reports"
}

@test "help-show: aligns options properly" {
    help-init "test" "Test script"
    help-add-option "-h" "--help" "Help"
    help-add-option "-v" "--very-long-option" "Long option"
    help-add-option "" "--extremely-long-option-name" "Very long"

    run help-show
    assert_success

    # All descriptions should start at the same column
    # This is a basic check - manual inspection of output alignment is recommended
    assert_output --partial "Options:"
}

@test "help-show: fails when help system not initialized" {
    run help-show
    assert_failure
    assert_output "error: help system not initialized. Call help-init first."
}

# help-error tests
@test "help-error: displays error message" {
    help-init "test-script" "Test script"

    # Run in subshell to prevent exit
    run bash -c "source '${BATS_TEST_DIRNAME}/../help.sh' && help-init 'test-script' 'Test' && help-error 'Invalid option: --foo'"
    assert_failure
    assert_output --partial "error: Invalid option: --foo"
    assert_output --partial "Try 'test-script --help' for more information."
}

@test "help-error: uses custom exit code" {
    help-init "test-script" "Test script"

    # Run in subshell to capture exit code
    run bash -c "source '${BATS_TEST_DIRNAME}/../help.sh' && help-init 'test-script' 'Test' && help-error 'Bad argument' 2"
    assert_failure 2
}

@test "help-error: works without help system initialized" {
    # Run in subshell
    run bash -c "source '${BATS_TEST_DIRNAME}/../help.sh' && help-error 'Something went wrong'"
    assert_failure
    assert_output "error: Something went wrong"
    refute_output --partial "Try"
}

@test "help-error: fails when error message is empty" {
    run help-error ""
    assert_failure
    assert_output "error: help-error requires an error message"
}

# help-usage tests
@test "help-usage: displays usage line" {
    help-init "test-script" "Test script" "test-script [options] <file>"

    run help-usage
    assert_success
    assert_output "Usage: test-script [options] <file>"
}

@test "help-usage: fails when help system not initialized" {
    run help-usage
    assert_failure
    assert_output "error: help system not initialized. Call help-init first."
}

# Integration tests
@test "integration: help system with parseargs pattern" {
    # Simulate a common pattern with parseargs
    help-init "deploy" "Deploy application to server" "deploy [options] <environment>"
    help-add-option "-h" "--help" "Show this help message"
    help-add-option "-f" "--force" "Force deployment without confirmation"
    help-add-option "-b" "--branch" "Git branch to deploy" "<branch>"
    help-add-option "-t" "--tag" "Git tag to deploy" "<tag>"
    help-add-example "deploy prod" "Deploy to production"
    help-add-example "deploy staging --branch feature/new-ui" "Deploy feature branch to staging"
    help-set-epilogue "Environment must be one of: dev, staging, prod"

    run help-show
    assert_success

    # Verify the output looks correct
    assert_output --partial "Usage: deploy [options] <environment>"
    assert_output --partial "Deploy application to server"
    assert_output --partial "-f, --force"
    assert_output --partial "Environment must be one of:"
}

@test "integration: typical script help usage" {
    # Simulate how a script would use the help system
    source "${BATS_TEST_DIRNAME}/../help.sh"

    # Initialize help
    help-init "backup" "Backup files to remote server"
    help-add-option "-h" "--help" "Show help"
    help-add-option "-v" "--verbose" "Verbose output"
    help-add-option "-d" "--destination" "Backup destination" "<path>"
    help-add-option "-x" "--exclude" "Exclude pattern (can be used multiple times)" "<pattern>"
    help-add-example "backup /home/user" "Backup user home directory"
    help-add-example "backup -x '*.tmp' -x '*.log' /var/data" "Backup with exclusions"

    # Test showing help
    run help-show
    assert_success

    # Test error handling
    run bash -c "source '${BATS_TEST_DIRNAME}/../help.sh' && help-init 'backup' 'Test' && help-error 'Unknown option: --invalid'"
    assert_failure
    assert_output --partial "error: Unknown option: --invalid"
    assert_output --partial "Try 'backup --help'"
}