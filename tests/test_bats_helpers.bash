# Standard bats assertion functions

assert() {
    [[ "$@" ]] || { echo "Assertion failed: $*" >&2; return 1; }
}

assert_success() {
    [[ $status -eq 0 ]] || { echo "Expected success, got status $status" >&2; return 1; }
}

assert_failure() {
    [[ $status -ne 0 ]] || { echo "Expected failure, got success" >&2; return 1; }
}

assert_output() {
    if [[ $# -eq 0 ]]; then
        [[ -n "$output" ]] || { echo "Expected output, got none" >&2; return 1; }
    else
        [[ "$output" == "$1" ]] || { echo "Expected: $1, got: $output" >&2; return 1; }
    fi
}

assert_line() {
    local line_num="${1:-0}"
    local expected="${2:-}"

    if [[ -z "$expected" ]]; then
        expected="$line_num"
        line_num=0
    fi

    local actual_line="${lines[$line_num]}"
    [[ "$actual_line" == "$expected" ]] || { echo "Line $line_num: expected '$expected', got '$actual_line'" >&2; return 1; }
}

fail() {
    echo "$@" >&2
    return 1
}
