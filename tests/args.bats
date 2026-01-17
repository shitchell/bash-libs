#!/usr/bin/env bats

# Test for args.sh library

setup() {
    # Source the library
    source "${BATS_TEST_DIRNAME}/../args.sh"
}

teardown() {
    # Clean up global variables
    unset ARGS_FLAGS ARGS_OPTIONS ARGS_POSITIONAL ARGS_REMAINING
    unset __ARGS_FLAG_DEFS __ARGS_FLAG_SHORTS __ARGS_OPTION_DEFS
    unset __ARGS_OPTION_SHORTS __ARGS_OPTION_METAVARS __ARGS_POSITIONAL_DEFS
    unset __ARGS_POSITIONAL_REQUIRED __ARGS_DESCRIPTION __ARGS_PROGRAM_NAME
}

# args-init tests

@test "args-init: initializes with description" {
    args-init "Test script"

    [[ "$__ARGS_DESCRIPTION" == "Test script" ]]
    [[ "$__ARGS_PROGRAM_NAME" == "bats-exec-test" ]]
}

@test "args-init: initializes with custom program name" {
    args-init "Test script" "myprogram"

    [[ "$__ARGS_DESCRIPTION" == "Test script" ]]
    [[ "$__ARGS_PROGRAM_NAME" == "myprogram" ]]
}

@test "args-init: resets all storage" {
    # Add some data first
    ARGS_FLAGS[test]="true"
    ARGS_OPTIONS[file]="/tmp/test"
    ARGS_POSITIONAL=("arg1" "arg2")

    args-init "New test"

    [[ ${#ARGS_FLAGS[@]} -eq 1 ]] # Only help flag
    [[ ${#ARGS_OPTIONS[@]} -eq 0 ]]
    [[ ${#ARGS_POSITIONAL[@]} -eq 0 ]]
}

@test "args-init: automatically adds help flag" {
    args-init "Test"

    [[ -n "${__ARGS_FLAG_DEFS[help]}" ]]
    [[ "${__ARGS_FLAG_SHORTS[-h]}" == "help" ]]
}

# args-add-flag tests

@test "args-add-flag: adds flag with short and long form" {
    args-init "Test"
    args-add-flag "-v/--verbose" "Enable verbose output"

    [[ "${__ARGS_FLAG_DEFS[verbose]}" == "Enable verbose output" ]]
    [[ "${__ARGS_FLAG_SHORTS[-v]}" == "verbose" ]]
    [[ "${__ARGS_FLAG_DEFS[--verbose]}" == "verbose" ]]
    [[ "${ARGS_FLAGS[verbose]}" == "false" ]]
}

@test "args-add-flag: adds flag with only long form" {
    args-init "Test"
    args-add-flag "--force" "Force operation"

    [[ "${__ARGS_FLAG_DEFS[force]}" == "Force operation" ]]
    [[ "${__ARGS_FLAG_DEFS[--force]}" == "force" ]]
    [[ "${ARGS_FLAGS[force]}" == "false" ]]
}

@test "args-add-flag: adds flag with only short form" {
    args-init "Test"
    args-add-flag "-q" "Quiet mode"

    [[ "${__ARGS_FLAG_DEFS[q]}" == "Quiet mode" ]]
    [[ "${__ARGS_FLAG_SHORTS[-q]}" == "q" ]]
    [[ "${ARGS_FLAGS[q]}" == "false" ]]
}

@test "args-add-flag: handles default value" {
    args-init "Test"
    args-add-flag "--debug" "Debug mode" "true"

    [[ "${ARGS_FLAGS[debug]}" == "true" ]]
}

@test "args-add-flag: converts dashes to underscores in names" {
    args-init "Test"
    args-add-flag "--dry-run" "Dry run mode"

    [[ "${__ARGS_FLAG_DEFS[dry_run]}" == "Dry run mode" ]]
    [[ "${ARGS_FLAGS[dry_run]}" == "false" ]]
}

@test "args-add-flag: rejects invalid spec" {
    args-init "Test"
    run args-add-flag "invalid" "Bad spec"

    [[ "$status" -eq 1 ]]
    [[ "$output" =~ "invalid spec" ]]
}

@test "args-add-flag: requires spec parameter" {
    args-init "Test"
    run args-add-flag "" "Empty spec"

    [[ "$status" -eq 1 ]]
    [[ "$output" =~ "spec required" ]]
}

# args-add-option tests

@test "args-add-option: adds option with short and long form" {
    args-init "Test"
    args-add-option "-f/--file" "FILE" "Input file"

    [[ "${__ARGS_OPTION_DEFS[file]}" == "Input file" ]]
    [[ "${__ARGS_OPTION_SHORTS[-f]}" == "file" ]]
    [[ "${__ARGS_OPTION_DEFS[--file]}" == "file" ]]
    [[ "${__ARGS_OPTION_METAVARS[file]}" == "FILE" ]]
}

@test "args-add-option: adds option with default value" {
    args-init "Test"
    args-add-option "--config" "PATH" "Config file" "/etc/config"

    [[ "${ARGS_OPTIONS[config]}" == "/etc/config" ]]
}

@test "args-add-option: requires metavar" {
    args-init "Test"
    run args-add-option "--file" "" "Input file"

    [[ "$status" -eq 1 ]]
    [[ "$output" =~ "metavar required" ]]
}

# args-add-positional tests

@test "args-add-positional: adds positional argument" {
    args-init "Test"
    args-add-positional "source" "Source file"

    [[ "${__ARGS_POSITIONAL_DEFS[0]}" == "source:Source file" ]]
}

@test "args-add-positional: adds required positional" {
    args-init "Test"
    args-add-positional "source" "Source file" "required"

    [[ "${__ARGS_POSITIONAL_DEFS[0]}" == "source:Source file" ]]
    [[ "${__ARGS_POSITIONAL_REQUIRED[source]}" == "true" ]]
}

@test "args-add-positional: adds multiple positionals in order" {
    args-init "Test"
    args-add-positional "source" "Source file"
    args-add-positional "dest" "Destination"
    args-add-positional "extra" "Extra args"

    [[ "${__ARGS_POSITIONAL_DEFS[0]}" == "source:Source file" ]]
    [[ "${__ARGS_POSITIONAL_DEFS[1]}" == "dest:Destination" ]]
    [[ "${__ARGS_POSITIONAL_DEFS[2]}" == "extra:Extra args" ]]
}

# args-parse tests

@test "args-parse: parses simple flags" {
    args-init "Test"
    args-add-flag "-v/--verbose" "Verbose"
    args-add-flag "-d/--debug" "Debug"

    args-parse -v --debug

    [[ "${ARGS_FLAGS[verbose]}" == "true" ]]
    [[ "${ARGS_FLAGS[debug]}" == "true" ]]
}

@test "args-parse: parses --no- prefix for flags" {
    args-init "Test"
    args-add-flag "--color" "Enable colors" "true"

    args-parse --no-color

    [[ "${ARGS_FLAGS[color]}" == "false" ]]
}

@test "args-parse: parses options with values" {
    args-init "Test"
    args-add-option "-f/--file" "FILE" "Input file"
    args-add-option "--output" "DIR" "Output directory"

    args-parse -f input.txt --output /tmp/out

    [[ "${ARGS_OPTIONS[file]}" == "input.txt" ]]
    [[ "${ARGS_OPTIONS[output]}" == "/tmp/out" ]]
}

@test "args-parse: parses option with = syntax" {
    args-init "Test"
    args-add-option "--file" "FILE" "Input file"

    args-parse --file=/path/to/file.txt

    [[ "${ARGS_OPTIONS[file]}" == "/path/to/file.txt" ]]
}

@test "args-parse: parses combined short flags" {
    args-init "Test"
    args-add-flag "-v" "Verbose"
    args-add-flag "-d" "Debug"
    args-add-flag "-q" "Quiet"

    args-parse -vdq

    [[ "${ARGS_FLAGS[v]}" == "true" ]]
    [[ "${ARGS_FLAGS[d]}" == "true" ]]
    [[ "${ARGS_FLAGS[q]}" == "true" ]]
}

@test "args-parse: parses short option with value attached" {
    args-init "Test"
    args-add-option "-f" "FILE" "File"

    args-parse -finput.txt

    [[ "${ARGS_OPTIONS[f]}" == "input.txt" ]]
}

@test "args-parse: parses positional arguments" {
    args-init "Test"
    args-add-positional "source" "Source"
    args-add-positional "dest" "Dest"

    args-parse file1.txt file2.txt

    [[ "${ARGS_POSITIONAL[0]}" == "file1.txt" ]]
    [[ "${ARGS_POSITIONAL[1]}" == "file2.txt" ]]
}

@test "args-parse: handles -- separator" {
    args-init "Test"
    args-add-flag "-v" "Verbose"

    args-parse -v -- -file-with-dash.txt

    [[ "${ARGS_FLAGS[v]}" == "true" ]]
    [[ "${ARGS_POSITIONAL[0]}" == "-file-with-dash.txt" ]]
}

@test "args-parse: returns error for unknown option" {
    args-init "Test"

    run args-parse --unknown

    [[ "$status" -eq 1 ]]
    [[ "$output" =~ "Unknown option" ]]
}

@test "args-parse: returns error when option missing value" {
    args-init "Test"
    args-add-option "-f" "FILE" "File"

    run args-parse -f

    [[ "$status" -eq 1 ]]
    [[ "$output" =~ "requires a value" ]]
}

@test "args-parse: returns 2 for help flag" {
    args-init "Test"

    run args-parse --help

    [[ "$status" -eq 2 ]]
}

@test "args-parse: mixed arguments parsing" {
    args-init "Test"
    args-add-flag "-v/--verbose" "Verbose"
    args-add-option "-f/--file" "FILE" "Input"
    args-add-option "-o" "OUT" "Output"
    args-add-positional "command" "Command to run"

    args-parse -v -f input.txt pos1 -ooutput.txt pos2

    [[ "${ARGS_FLAGS[verbose]}" == "true" ]]
    [[ "${ARGS_OPTIONS[file]}" == "input.txt" ]]
    [[ "${ARGS_OPTIONS[o]}" == "output.txt" ]]
    [[ "${ARGS_POSITIONAL[0]}" == "pos1" ]]
    [[ "${ARGS_POSITIONAL[1]}" == "pos2" ]]
}

# args-validate tests

@test "args-validate: passes when no required args" {
    args-init "Test"
    args-add-positional "optional" "Optional arg"

    args-parse
    run args-validate

    [[ "$status" -eq 0 ]]
}

@test "args-validate: fails when required positional missing" {
    args-init "Test"
    args-add-positional "required" "Required arg" "required"

    args-parse
    run args-validate

    [[ "$status" -eq 1 ]]
    [[ "$output" =~ "Expected at least 1 positional" ]]
}

@test "args-validate: passes when required positionals provided" {
    args-init "Test"
    args-add-positional "src" "Source" "required"
    args-add-positional "dst" "Dest" "required"

    args-parse file1 file2
    run args-validate

    [[ "$status" -eq 0 ]]
}

# Helper function tests

@test "args-get-flag: returns flag value" {
    args-init "Test"
    args-add-flag "--verbose" "Verbose"
    args-parse --verbose

    result=$(args-get-flag "verbose")
    [[ "$result" == "true" ]]
}

@test "args-get-flag: returns false for unset flag" {
    args-init "Test"
    args-add-flag "--verbose" "Verbose"
    args-parse

    result=$(args-get-flag "verbose")
    [[ "$result" == "false" ]]
}

@test "args-get-flag: handles dash conversion" {
    args-init "Test"
    args-add-flag "--dry-run" "Dry run"
    args-parse --dry-run

    result=$(args-get-flag "dry-run")
    [[ "$result" == "true" ]]
}

@test "args-get-option: returns option value" {
    args-init "Test"
    args-add-option "--file" "FILE" "File"
    args-parse --file test.txt

    result=$(args-get-option "file")
    [[ "$result" == "test.txt" ]]
}

@test "args-get-option: returns error for unset option" {
    args-init "Test"
    args-add-option "--file" "FILE" "File"
    args-parse

    run args-get-option "file"
    [[ "$status" -eq 1 ]]
}

@test "args-get-positional: returns positional by index" {
    args-init "Test"
    args-parse arg1 arg2 arg3

    result=$(args-get-positional 0)
    [[ "$result" == "arg1" ]]

    result=$(args-get-positional 2)
    [[ "$result" == "arg3" ]]
}

@test "args-get-positional: returns error for invalid index" {
    args-init "Test"
    args-parse arg1

    run args-get-positional 5
    [[ "$status" -eq 1 ]]
}

@test "args-has-flag: detects set flag" {
    args-init "Test"
    args-add-flag "--verbose" "Verbose"
    args-parse --verbose

    args-has-flag "verbose"
    [[ "$?" -eq 0 ]]
}

@test "args-has-flag: detects unset flag" {
    args-init "Test"
    args-add-flag "--verbose" "Verbose"
    args-parse

    args-has-flag "verbose"
    [[ "$?" -eq 1 ]]
}

@test "args-has-option: detects set option" {
    args-init "Test"
    args-add-option "--file" "FILE" "File"
    args-parse --file test.txt

    args-has-option "file"
    [[ "$?" -eq 0 ]]
}

@test "args-has-option: detects unset option" {
    args-init "Test"
    args-add-option "--file" "FILE" "File"
    args-parse

    args-has-option "file"
    [[ "$?" -eq 1 ]]
}

# Help display tests

@test "__args-show-help: displays basic help" {
    args-init "Test script description"
    args-add-flag "-v/--verbose" "Enable verbose output"
    args-add-option "-f/--file" "FILE" "Input file path"
    args-add-positional "source" "Source directory"

    run __args-show-help

    [[ "$status" -eq 0 ]]
    [[ "$output" =~ "Usage: bats-exec-test" ]]
    [[ "$output" =~ "Test script description" ]]
    [[ "$output" =~ "-h, --help" ]]
    [[ "$output" =~ "-v, --verbose" ]]
    [[ "$output" =~ "-f, --file <FILE>" ]]
    [[ "$output" =~ "source" ]]
}

@test "__args-show-help: shows required vs optional positionals" {
    args-init "Test"
    args-add-positional "required" "Required arg" "required"
    args-add-positional "optional" "Optional arg"

    run __args-show-help

    [[ "$output" =~ "<required>" ]]
    [[ "$output" =~ "\[optional\]" ]]
}

# Edge cases and error handling

@test "args-parse: handles empty arguments" {
    args-init "Test"
    run args-parse

    [[ "$status" -eq 0 ]]
    [[ ${#ARGS_POSITIONAL[@]} -eq 0 ]]
}

@test "args-parse: handles special characters in values" {
    args-init "Test"
    args-add-option "--msg" "MSG" "Message"

    args-parse --msg "Hello, world! \$test \"quoted\""

    [[ "${ARGS_OPTIONS[msg]}" == "Hello, world! \$test \"quoted\"" ]]
}

@test "args-parse: handles paths with spaces" {
    args-init "Test"
    args-add-option "--path" "PATH" "File path"

    args-parse --path "/path with spaces/file.txt"

    [[ "${ARGS_OPTIONS[path]}" == "/path with spaces/file.txt" ]]
}

@test "ARGS_REMAINING compatibility" {
    args-init "Test"
    args-parse arg1 arg2 arg3

    [[ "${ARGS_REMAINING[0]}" == "arg1" ]]
    [[ "${ARGS_REMAINING[1]}" == "arg2" ]]
    [[ "${ARGS_REMAINING[2]}" == "arg3" ]]
}