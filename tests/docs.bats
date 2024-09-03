#!/usr/bin/env bats

load '../docs.sh'

@test "generate-library-docs with valid library" {
    run generate-library-docs test-func-single
    [ "$status" -eq 0 ]
    [[ "$output" =~ "declare -A DOCSTRING" ]]
}

@test "generate-library-docs with empty library name" {
    run generate-library-docs ""
    [ "$status" -eq 2 ]
}

@test "generate-library-docs with non-existent library" {
    run generate-library-docs non_existent_func
    [ "$status" -eq 3 ]
}

@test "generate-function-docstring with valid function" {
    run generate-function-docstring test-func-single
    [ "$status" -eq 0 ]
    [[ "$output" =~ "declare -A DOCSTRING" ]]
}

@test "generate-function-docstring with empty function name" {
    run generate-function-docstring ""
    [ "$status" -eq 1 ]
}

@test "generate-function-docstring with non-existent function" {
    run generate-function-docstring non_existent_func
    [ "$status" -eq 3 ]
}

@test "__uses_subshell with subshell function" {
    run __uses_subshell "$(declare -f test-func-subshell-single)"
    [ "$status" -eq 0 ]
}

@test "__uses_subshell with non-subshell function" {
    run __uses_subshell "$(declare -f test-func-single)"
    [ "$status" -eq 1 ]
}

@test "__extract_redirection with redirection" {
    run __extract_redirection "$(declare -f test-func-single-redirect)"
    [ "$status" -eq 0 ]
    [ "$output" = "2>&1 1>&2" ]
}

@test "__extract_redirection without redirection" {
    run __extract_redirection "$(declare -f test-func-single)"
    [ "$status" -eq 1 ]
}

@test "__extract_docstring with valid docstring" {
    run __extract_docstring "$(declare -f test-func-single)"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "@usage" ]]
}

@test "__extract_docstring without docstring" {
    run __extract_docstring "$(declare -f run)"
    [ "$status" -eq 2 ]
}

@test "__parse_docstring with valid docstring" {
    docstring=$':\n@description This is a test function\n@usage [-h] [--help] <arg1> [<arg2> ...]\n@return 0: success\n@return 1: failure'
    run __parse_docstring "$docstring"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "declare -A DOCSTRING" ]]
}

@test "__parse_docstring without docstring" {
    run __parse_docstring ""
    [ "$status" -eq 1 ]
}
