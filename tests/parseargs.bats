#!/usr/bin/env bats

# We need to set up includes before loading the file
# Define a simple debug function for testing
function debug() {
  # No-op for tests
  :
}
export -f debug

setup_file() {
  # Define the basic path for finding libraries
  export LIB_DIR=$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)
  export BASH_LIB_PATH=$LIB_DIR

  # First load include.sh independently
  source "$LIB_DIR/include.sh"

  # Also load the exit-codes.sh file
  source "$LIB_DIR/exit-codes.sh"

  # Create a temporary file without include-source for testing
  temp_file=$(mktemp)
  cat "$LIB_DIR/parseargs.sh" | grep -v "^include-source " > "$temp_file"

  export TEMP_PARSEARGS_FILE="$temp_file"

  # Now source the temp file
  source "$temp_file"
}

teardown_file() {
  # Clean up the temporary file
  rm -f "$TEMP_PARSEARGS_FILE"
}

setup() {
  # Clear all parser state before each test
  parseargs-init
}

teardown() {
  # Nothing needed for teardown
  :
}

# Helper function to check array contents
assert_equal() {
  if [[ "$1" != "$2" ]]; then
    echo "Expected: $1"
    echo "Got:      $2"
    return 1
  fi
}

# Test parseargs-init
@test "parseargs-init initializes parser state" {
  # Verify that the arrays are initialized
  parseargs-init
  assert_equal "0" "${#PARSEARGS_FLAGS[@]}"
  assert_equal "0" "${#PARSEARGS_PARAMETERS[@]}"
  assert_equal "0" "${#PARSEARGS_POSITIONALS[@]}"
  assert_equal "0" "${#PARSEARGS_SUBCOMMANDS[@]}"
  assert_equal "0" "${#PARSEARGS_OPTS[@]}"
  assert_equal "0" "${#PARSEARGS_POSARGS[@]}"
}

# Test parseargs-set-prog-name
@test "parseargs-set-prog-name sets program name" {
  parseargs-set-prog-name "test-program"
  assert_equal "test-program" "${PARSEARGS_PROG_NAME}"
}

# Test parseargs-set-usage
@test "parseargs-set-usage sets usage text" {
  parseargs-set-usage "custom usage text"
  assert_equal "custom usage text" "${PARSEARGS_USAGE}"
}

# Test parseargs-set-epilog
@test "parseargs-set-epilog sets epilog text" {
  parseargs-set-epilog "custom epilog text"
  assert_equal "custom epilog text" "${PARSEARGS_EPILOG}"
}

# Test parseargs-set-help
@test "parseargs-set-help sets help text" {
  parseargs-set-help "custom help text"
  assert_equal "custom help text" "${PARSEARGS_HELP}"
}

# Test parseargs-add-subcommand
@test "parseargs-add-subcommand adds a subcommand" {
  parseargs-add-subcommand "list" --help "List items"
  assert_equal "List items" "${PARSEARGS_SUBCOMMANDS["list:help"]}"
}

# Test parseargs-parse-flag-names
@test "parseargs-parse-flag-names parses short and long names" {
  # Test short and long name
  result=$(parseargs-parse-flag-names "-v/--verbose")
  assert_equal "-v,--verbose" "${result}"

  # Test long name only
  result=$(parseargs-parse-flag-names "--verbose")
  assert_equal ",--verbose" "${result}"

  # Test short name only
  result=$(parseargs-parse-flag-names "-v")
  assert_equal "-v," "${result}"
}

# Test parseargs-add-flag
@test "parseargs-add-flag adds a flag option" {
  parseargs-add-flag "-v/--verbose" --help "Verbose output" --default "false"
  assert_equal "-v" "${PARSEARGS_FLAGS["verbose:short"]}"
  assert_equal "--verbose" "${PARSEARGS_FLAGS["verbose:long"]}"
  assert_equal "false" "${PARSEARGS_FLAGS["verbose:default"]}"
  assert_equal "verbose" "${PARSEARGS_FLAGS["verbose:store"]}"
  assert_equal "Verbose output" "${PARSEARGS_FLAGS["verbose:help"]}"
  assert_equal "false" "${PARSEARGS_FLAGS["verbose:required"]}"
}

@test "parseargs-add-flag with custom store variable" {
  parseargs-add-flag "-v/--verbose" --store "be_verbose" --help "Verbose output"
  assert_equal "be_verbose" "${PARSEARGS_FLAGS["verbose:store"]}"
}

@test "parseargs-add-flag with required flag" {
  parseargs-add-flag "-v/--verbose" --required --help "Verbose output"
  assert_equal "true" "${PARSEARGS_FLAGS["verbose:required"]}"
}

@test "parseargs-add-flag with subcommand" {
  parseargs-add-flag "-v/--verbose" --subcommand "list" --help "Verbose output"
  assert_equal "list" "${PARSEARGS_FLAGS["verbose:subcommand"]}"
}

# Test parseargs-add-parameter
@test "parseargs-add-parameter adds a parameter option" {
  parseargs-add-parameter "-f/--file" --help "Input file" --type "file"
  assert_equal "-f" "${PARSEARGS_PARAMETERS["file:short"]}"
  assert_equal "--file" "${PARSEARGS_PARAMETERS["file:long"]}"
  assert_equal "file" "${PARSEARGS_PARAMETERS["file:store"]}"
  assert_equal "Input file" "${PARSEARGS_PARAMETERS["file:help"]}"
  assert_equal "file" "${PARSEARGS_PARAMETERS["file:type"]}"
  assert_equal "false" "${PARSEARGS_PARAMETERS["file:required"]}"
  assert_equal "1" "${PARSEARGS_PARAMETERS["file:nargs"]}"
}

@test "parseargs-add-parameter with custom store variable" {
  parseargs-add-parameter "-f/--file" --store "input_file" --help "Input file"
  assert_equal "input_file" "${PARSEARGS_PARAMETERS["file:store"]}"
}

@test "parseargs-add-parameter with required parameter" {
  parseargs-add-parameter "-f/--file" --required --help "Input file"
  assert_equal "true" "${PARSEARGS_PARAMETERS["file:required"]}"
}

@test "parseargs-add-parameter with choices" {
  parseargs-add-parameter "-m/--mode" --choices "read,write,append" --help "File mode"
  assert_equal "read,write,append" "${PARSEARGS_PARAMETERS["mode:choices"]}"
}

@test "parseargs-add-parameter with nargs" {
  parseargs-add-parameter "-f/--file" --nargs "+" --help "Input files"
  assert_equal "+" "${PARSEARGS_PARAMETERS["file:nargs"]}"
}

# Test parseargs-add-positional
@test "parseargs-add-positional adds a positional argument" {
  parseargs-add-positional "filename" --help "Input filename"
  assert_equal "filename" "${PARSEARGS_POSITIONALS["0:name"]}"
  assert_equal "Input filename" "${PARSEARGS_POSITIONALS["0:help"]}"
  assert_equal "true" "${PARSEARGS_POSITIONALS["0:required"]}"
  assert_equal "1" "${PARSEARGS_POSITIONALS["0:nargs"]}"
  assert_equal "string" "${PARSEARGS_POSITIONALS["0:type"]}"
}

@test "parseargs-add-positional with optional argument" {
  parseargs-add-positional "filename" --default "default.txt" --help "Input filename"
  assert_equal "false" "${PARSEARGS_POSITIONALS["0:required"]}"
  assert_equal "default.txt" "${PARSEARGS_POSITIONALS["0:default"]}"
}

@test "parseargs-add-positional with follows separator" {
  parseargs-add-positional "filenames" --follows "--" --help "Input filenames"
  assert_equal "--" "${PARSEARGS_POSITIONALS["0:follows"]}"
}

# Test parseargs-validate-type
@test "parseargs-validate-type validates integer type" {
  run parseargs-validate-type "123" "int"
  assert_equal "0" "$status"

  run parseargs-validate-type "abc" "int"
  assert_equal "21" "$status"  # E_NOT_A_NUMBER
}

@test "parseargs-validate-type validates float type" {
  run parseargs-validate-type "123.45" "float"
  assert_equal "0" "$status"

  run parseargs-validate-type "abc" "float"
  assert_equal "21" "$status"  # E_NOT_A_NUMBER
}

@test "parseargs-validate-type validates boolean type" {
  run parseargs-validate-type "true" "bool"
  assert_equal "0" "$status"

  run parseargs-validate-type "false" "bool"
  assert_equal "0" "$status"

  run parseargs-validate-type "1" "bool"
  assert_equal "0" "$status"

  run parseargs-validate-type "0" "bool"
  assert_equal "0" "$status"

  run parseargs-validate-type "yes" "bool"
  assert_equal "16" "$status"  # E_INVALID_VALUE
}

@test "parseargs-validate-type validates file type" {
  # Create a test file
  touch "/tmp/test-file.txt"

  run parseargs-validate-type "/tmp/test-file.txt" "file"
  assert_equal "0" "$status"

  run parseargs-validate-type "/tmp/nonexistent-file.txt" "file"
  assert_equal "26" "$status"  # E_NOT_A_FILE

  # Clean up
  rm -f "/tmp/test-file.txt"
}

# Test parseargs-validate-choices
@test "parseargs-validate-choices validates choices" {
  run parseargs-validate-choices "red" "red,green,blue"
  assert_equal "0" "$status"

  run parseargs-validate-choices "yellow" "red,green,blue"
  assert_equal "16" "$status"  # E_INVALID_VALUE

  # Empty choices should always pass
  run parseargs-validate-choices "anything" ""
  assert_equal "0" "$status"
}

# Test parseargs-parse with simple flags
@test "parseargs-parse handles flags" {
  parseargs-add-flag "-v/--verbose" --help "Verbose output"
  parseargs-add-flag "-q/--quiet" --help "Quiet output"

  parseargs-parse "--verbose"
  assert_equal "true" "${PARSEARGS_OPTS["verbose"]}"

  parseargs-init
  parseargs-add-flag "-v/--verbose" --help "Verbose output"
  parseargs-add-flag "-q/--quiet" --help "Quiet output"

  parseargs-parse "--no-verbose"
  assert_equal "false" "${PARSEARGS_OPTS["verbose"]}"
}

# Test parseargs-parse with parameters
@test "parseargs-parse handles parameters" {
  parseargs-add-parameter "-f/--file" --help "Input file"

  parseargs-parse "--file" "test.txt"
  assert_equal "test.txt" "${PARSEARGS_OPTS["file"]}"

  # Short option
  parseargs-init
  parseargs-add-parameter "-f/--file" --help "Input file"

  parseargs-parse "-f" "test.txt"
  assert_equal "test.txt" "${PARSEARGS_OPTS["file"]}"
}

# Test parseargs-parse with positional args
@test "parseargs-parse handles positional arguments" {
  parseargs-add-positional "filename" --help "Input filename"

  parseargs-parse "test.txt"
  assert_equal "test.txt" "${PARSEARGS_POSARGS[0]}"

  # Multiple positional arguments
  parseargs-init
  parseargs-add-positional "src" --help "Source file"
  parseargs-add-positional "dest" --help "Destination file"

  parseargs-parse "input.txt" "output.txt"
  assert_equal "input.txt" "${PARSEARGS_POSARGS[0]}"
  assert_equal "output.txt" "${PARSEARGS_POSARGS[1]}"
}

# Test parseargs-parse with a mix of options
@test "parseargs-parse handles mix of options and positional args" {
  parseargs-add-flag "-v/--verbose" --help "Verbose output"
  parseargs-add-parameter "-f/--file" --help "Input file"
  parseargs-add-positional "output" --help "Output file"

  parseargs-parse "--verbose" "--file" "input.txt" "output.txt"
  assert_equal "true" "${PARSEARGS_OPTS["verbose"]}"
  assert_equal "input.txt" "${PARSEARGS_OPTS["file"]}"
  assert_equal "output.txt" "${PARSEARGS_POSARGS[0]}"
}

# Test parseargs-parse with subcommands
@test "parseargs-parse handles subcommands" {
  parseargs-add-subcommand "list" --help "List items"
  parseargs-add-flag "-a/--all" --subcommand "list" --help "List all items"

  parseargs-parse "list" "--all"
  assert_equal "list" "${PARSEARGS_ACTIVE_SUBCOMMAND}"
  assert_equal "true" "${PARSEARGS_OPTS["all"]}"
}

# Test parseargs-parse with required args
@test "parseargs-parse fails with missing required parameter" {
  parseargs-add-parameter "-f/--file" --required --help "Input file"

  run parseargs-parse
  assert_equal "14" "$status"  # E_MISSING_OPTION
}

@test "parseargs-parse fails with missing required positional arg" {
  parseargs-add-positional "filename" --help "Input filename"

  run parseargs-parse
  assert_equal "11" "$status"  # E_MISSING_ARGUMENT
}

# Test parseargs-parse with option type validation
@test "parseargs-parse fails with invalid type" {
  parseargs-add-parameter "-n/--number" --type "int" --help "A number"

  run parseargs-parse "--number" "abc"
  assert_equal "16" "$status"  # E_INVALID_VALUE
}

# Test parseargs-parse with option choices validation
@test "parseargs-parse fails with invalid choice" {
  parseargs-add-parameter "-c/--color" --choices "red,green,blue" --help "Color"

  run parseargs-parse "--color" "yellow"
  assert_equal "16" "$status"  # E_INVALID_VALUE
}

# Test parseargs-parse with default values
@test "parseargs-parse sets default values" {
  parseargs-add-flag "-v/--verbose" --default "true" --help "Verbose output"
  parseargs-add-parameter "-f/--file" --default "default.txt" --help "Input file"

  parseargs-parse
  assert_equal "true" "${PARSEARGS_OPTS["verbose"]}"
  assert_equal "default.txt" "${PARSEARGS_OPTS["file"]}"
}

# Test parseargs-parse with -- separator
@test "parseargs-parse handles -- separator" {
  parseargs-add-flag "-v/--verbose" --help "Verbose output"

  parseargs-parse "-v" "--" "--not-an-option"
  assert_equal "true" "${PARSEARGS_OPTS["verbose"]}"
  assert_equal "--not-an-option" "${PARSEARGS_POSARGS[0]}"
}

# Test parseargs-parse with follows separator
@test "parseargs-parse handles follows separator" {
  parseargs-add-positional "filenames" --follows "--files" --help "Input filenames"

  parseargs-parse "--files" "file1.txt" "file2.txt"
  assert_equal "file1.txt" "${PARSEARGS_POSARGS[0]}"
  assert_equal "file2.txt" "${PARSEARGS_POSARGS[1]}"
}