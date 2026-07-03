#!/usr/bin/env bats

# Tests for silence-output / restore-output in shell.sh

function debug() { :; }
export -f debug

setup_file() {
  export LIB_DIR=$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)
  export BASH_LIB_PATH=$LIB_DIR
  source "$LIB_DIR/include.sh"
}

setup() {
  source "$LIB_DIR/shell.sh"
  function debug() { :; }
  function debug-vars() { :; }
}

assert_equal() {
  if [[ "$1" != "$2" ]]; then
    echo "Expected: $1"
    echo "Got:      $2"
    return 1
  fi
}

@test "silence-output suppresses stdout and stderr" {
  wrapper() {
    silence-output
    echo "to stdout"
    echo "to stderr" >&2
  }
  run wrapper
  assert_equal "" "$output"
}

@test "restore-output brings stdout and stderr back (non-tty safe)" {
  # The old template guarded restore with [[ -t 3 ]], which silently fails
  # to restore when the script's output is not a terminal (files, pipes,
  # bats). The lib version must restore regardless of tty-ness.
  wrapper() {
    silence-output
    echo "hidden"
    restore-output
    echo "visible"
    echo "visible on stderr" >&2
  }
  run wrapper
  assert_equal "visible
visible on stderr" "$output"
}

@test "restore-output without a prior silence-output does not error" {
  wrapper() {
    restore-output
    echo "still here"
  }
  run wrapper
  assert_equal 0 "$status"
  assert_equal "still here" "$output"
}
