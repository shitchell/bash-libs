#!/usr/bin/env bats

# Tests for parseargs built-in options, protections, presets
# (parseargs-include), --count flags, parseargs-parse-or-exit, and
# show-help ordering/marker fixes.

function debug() { :; }
export -f debug

setup_file() {
  export LIB_DIR=$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)
  export BASH_LIB_PATH=$LIB_DIR
  source "$LIB_DIR/include.sh"
  source "$LIB_DIR/exit-codes.sh"
}

setup() {
  source "$LIB_DIR/shell.sh"
  source "$LIB_DIR/colors.sh"
  source "$LIB_DIR/parseargs.sh"
  # The real debug.sh (pulled in transitively via include-source) breaks
  # under bats; neutralize it after all sourcing is done
  function debug() { :; }
  function debug-vars() { :; }
  parseargs-init
  parseargs-set-prog-name "testprog"
}

assert_equal() {
  if [[ "$1" != "$2" ]]; then
    echo "Expected: $1"
    echo "Got:      $2"
    return 1
  fi
}


## -h/--help protection ########################################################

@test "defining -h errors as reserved" {
  run parseargs-add-flag "-h/--halt"
  assert_equal "$E_INVALID_OPTION" "$status"
  [[ "$output" == *reserved* ]]
}

@test "defining --help errors as reserved" {
  run parseargs-add-parameter "--help"
  assert_equal "$E_INVALID_OPTION" "$status"
  [[ "$output" == *reserved* ]]
}


## duplicate detection #########################################################

@test "defining the same option name twice errors" {
  parseargs-add-flag "--force"
  run parseargs-add-flag "-f/--force"
  assert_equal "$E_INVALID_OPTION" "$status"
  [[ "$output" == *"already defined"* ]]
}


## built-in -s/--silent and -v/--verbose #######################################

@test "built-in -s sets DO_SILENT without any registration" {
  parseargs-parse -s
  assert_equal "true" "${PARSEARGS_OPTS[DO_SILENT]}"
}

@test "built-in -v is counted into VERBOSE" {
  parseargs-parse -v -v -v
  assert_equal "3" "${PARSEARGS_OPTS[VERBOSE]}"
}

@test "built-ins appear in generated help" {
  run parseargs-show-help
  [[ "$output" == *"--silent"* ]]
  [[ "$output" == *"--verbose"* ]]
}

@test "user option claiming -s drops the whole silent built-in" {
  parseargs-add-parameter "-s/--sort" --store SORT
  parseargs-parse -s name
  assert_equal "name" "${PARSEARGS_OPTS[SORT]}"
  # --silent must be gone entirely, not half-orphaned
  run parseargs-parse --silent
  assert_equal "$E_UNKNOWN_OPTION" "$status"
}

@test "user option claiming --verbose drops the whole verbose built-in" {
  parseargs-add-flag "--verbose" --store MY_VERBOSE
  parseargs-parse --verbose
  assert_equal "true" "${PARSEARGS_OPTS[MY_VERBOSE]}"
  run parseargs-parse -v
  assert_equal "$E_UNKNOWN_OPTION" "$status"
}

@test "built-ins do not leak into a re-initialized parser's user options" {
  parseargs-parse -s
  parseargs-init
  parseargs-add-parameter "-s/--sort" --store SORT
  parseargs-parse -s date
  assert_equal "date" "${PARSEARGS_OPTS[SORT]}"
}


## --count flags ###############################################################

@test "add-flag --count counts repeated flags" {
  parseargs-add-flag "-x/--extra" --count
  parseargs-parse -x -x
  assert_equal "2" "${PARSEARGS_OPTS[extra]}"
}

@test "count flags default to 0 when absent" {
  parseargs-add-flag "-x/--extra" --count
  parseargs-parse
  assert_equal "0" "${PARSEARGS_OPTS[extra]}"
}


## parseargs-parse-or-exit #####################################################

@test "parse-or-exit exits 0 on -h and prints help" {
  wrapper() {
    parseargs-set-help "test description"
    parseargs-parse-or-exit -h
    echo "UNREACHABLE"
  }
  run wrapper
  assert_equal 0 "$status"
  [[ "$output" == *"test description"* ]]
  [[ "$output" != *UNREACHABLE* ]]
}

@test "parse-or-exit exits with the granular code on unknown option" {
  wrapper() {
    parseargs-parse-or-exit -z
    echo "UNREACHABLE"
  }
  run wrapper
  assert_equal "$E_UNKNOWN_OPTION" "$status"
  [[ "$output" != *UNREACHABLE* ]]
}

@test "parse-or-exit returns 0 on success and sets standard globals" {
  parseargs-parse-or-exit -v -v
  assert_equal "2" "$VERBOSE"
  assert_equal "false" "$DO_SILENT"
}

@test "parse-or-exit -s silences remaining output" {
  wrapper() {
    parseargs-parse-or-exit -s
    echo "should not appear"
  }
  run wrapper
  assert_equal "" "$output"
}


## colors preset ###############################################################

@test "colors preset registers -c/--color" {
  parseargs-include colors
  parseargs-parse -c always
  assert_equal "always" "${PARSEARGS_OPTS[COLOR]}"
}

@test "colors preset: always sets DO_COLOR=true and populates color vars" {
  parseargs-include colors
  parseargs-parse -c always
  assert_equal "true" "$DO_COLOR"
  [[ -n "$C_RED" ]]
}

@test "colors preset: never sets DO_COLOR=false and empties color vars" {
  parseargs-include colors
  parseargs-parse -c never
  assert_equal "false" "$DO_COLOR"
  assert_equal "" "$C_RED"
}

@test "colors preset: auto resolves false when stdout is not a tty" {
  parseargs-include colors
  parseargs-parse
  assert_equal "false" "$DO_COLOR"
}

@test "colors preset: invalid mode fails with E_INVALID_VALUE" {
  parseargs-include colors
  run parseargs-parse -c bogus
  assert_equal "$E_INVALID_VALUE" "$status"
}

@test "colors preset: user-defined -c afterwards errors as already defined" {
  parseargs-include colors
  run parseargs-add-parameter "-c/--count-things"
  assert_equal "$E_INVALID_OPTION" "$status"
  [[ "$output" == *"already defined"* ]]
}


## config preset ###############################################################

@test "config preset: --config-file is sourced and beats --default" {
  export HOME="$BATS_TEST_TMPDIR"
  printf 'FORMAT="from config"\n' > "$BATS_TEST_TMPDIR/my.conf"
  parseargs-include config
  parseargs-add-parameter "-f/--format" --store FORMAT --default "from default"
  parseargs-parse --config-file "$BATS_TEST_TMPDIR/my.conf"
  assert_equal "from config" "${PARSEARGS_OPTS[FORMAT]}"
}

@test "config preset: CLI beats config" {
  export HOME="$BATS_TEST_TMPDIR"
  printf 'FORMAT="from config"\n' > "$BATS_TEST_TMPDIR/my.conf"
  parseargs-include config
  parseargs-add-parameter "-f/--format" --store FORMAT --default "from default"
  parseargs-parse --config-file "$BATS_TEST_TMPDIR/my.conf" -f "from cli"
  assert_equal "from cli" "${PARSEARGS_OPTS[FORMAT]}"
}

@test "config preset: default path is ~/.<prog>.conf" {
  export HOME="$BATS_TEST_TMPDIR"
  printf 'FORMAT="from home conf"\n' > "$BATS_TEST_TMPDIR/.testprog.conf"
  parseargs-include config
  parseargs-add-parameter "-f/--format" --store FORMAT --default "from default"
  parseargs-parse
  assert_equal "from home conf" "${PARSEARGS_OPTS[FORMAT]}"
}

@test "config preset: without a config file, --default applies" {
  export HOME="$BATS_TEST_TMPDIR"
  parseargs-include config
  parseargs-add-parameter "-f/--format" --store FORMAT --default "from default"
  parseargs-parse
  assert_equal "from default" "${PARSEARGS_OPTS[FORMAT]}"
}

@test "config preset: environment variable beats --default" {
  export HOME="$BATS_TEST_TMPDIR"
  parseargs-include config
  parseargs-add-parameter "-f/--format" --store FORMAT --default "from default"
  FORMAT="from env" parseargs-parse
  assert_equal "from env" "${PARSEARGS_OPTS[FORMAT]}"
}

@test "without the config preset, environment variables are NOT consulted" {
  parseargs-add-parameter "-f/--format" --store FORMAT --default "from default"
  FORMAT="from env" parseargs-parse
  assert_equal "from default" "${PARSEARGS_OPTS[FORMAT]}"
}


## show-help fixes #############################################################

@test "non-required positionals are not marked with *" {
  parseargs-add-positional "FILE" --optional
  run parseargs-show-help
  [[ "$output" == *"  FILE "* ]]
  [[ "$output" != *"FILE*"* ]]
}

@test "required positionals are marked with *" {
  parseargs-add-positional "FILE" --required
  run parseargs-show-help
  [[ "$output" == *"FILE*"* ]]
}

@test "options are listed in declaration order" {
  parseargs-add-parameter "-z/--zeta" --help "z option"
  parseargs-add-flag "-a/--alpha" --help "a option"
  parseargs-add-parameter "-m/--middle" --help "m option"
  run parseargs-show-help
  local zeta_line alpha_line middle_line
  zeta_line=$(grep -n -- '--zeta' <<< "$output" | cut -d: -f1)
  alpha_line=$(grep -n -- '--alpha' <<< "$output" | cut -d: -f1)
  middle_line=$(grep -n -- '--middle' <<< "$output" | cut -d: -f1)
  (( zeta_line < alpha_line && alpha_line < middle_line ))
}
