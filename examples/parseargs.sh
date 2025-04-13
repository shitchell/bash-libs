#!/usr/bin/env bash
#
# Example script demonstrating the parseargs.sh library capabilities
#

# Set up the library path
export LIB_DIR="$(dirname "$0")/.."
export BASH_LIB_PATH="${LIB_DIR}"

# Load parseargs.sh through include-source
include-source "parseargs"

# Show a message and exit
show_message() {
    echo "$1"
    exit 0
}

# Function to demonstrate basic command with flag and parameter
basic_demo() {
    echo "Running basic demo with flags and parameters"
    echo "--------------------------------------------"
    echo "Verbose mode: ${PARSEARGS_OPTS[verbose]}"
    echo "Output file: ${PARSEARGS_OPTS[output]}"
    echo "Count: ${PARSEARGS_OPTS[count]}"
    echo "Force: ${PARSEARGS_OPTS[force]}"
    echo
}

# Function to demonstrate positional arguments
positional_demo() {
    echo "Positional arguments demo"
    echo "------------------------"
    echo "Number of positional args: ${#PARSEARGS_POSARGS[@]}"
    for (( i=0; i<${#PARSEARGS_POSARGS[@]}; i++ )); do
        echo "Argument $i: ${PARSEARGS_POSARGS[$i]}"
    done
    echo
}

# Function to demonstrate subcommand handling
subcommand_demo() {
    echo "Subcommand demo"
    echo "--------------"
    echo "Active subcommand: ${PARSEARGS_ACTIVE_SUBCOMMAND}"

    case "${PARSEARGS_ACTIVE_SUBCOMMAND}" in
        list)
            echo "Listing items..."
            echo "All items: ${PARSEARGS_OPTS[all]}"
            echo "Format: ${PARSEARGS_OPTS[format]}"
            ;;
        create)
            echo "Creating item..."
            echo "Name: ${PARSEARGS_OPTS[name]}"
            echo "Type: ${PARSEARGS_OPTS[type]}"
            ;;
        delete)
            echo "Deleting item..."
            echo "Force: ${PARSEARGS_OPTS[force]}"
            echo "Item ID: ${PARSEARGS_POSARGS[0]}"
            ;;
        *)
            echo "No subcommand or unknown subcommand specified"
            ;;
    esac
    echo
}

# Function to demonstrate using choices
choices_demo() {
    echo "Choices demo"
    echo "-----------"
    echo "Selected color: ${PARSEARGS_OPTS[color]}"
    echo "Selected size: ${PARSEARGS_OPTS[size]}"
    echo
}

# Function to demonstrate type validation
types_demo() {
    echo "Types demo"
    echo "----------"
    echo "Integer value: ${PARSEARGS_OPTS[integer]}"
    echo "Float value: ${PARSEARGS_OPTS[float]}"
    echo "Boolean value: ${PARSEARGS_OPTS[boolean]}"
    echo "File path: ${PARSEARGS_OPTS[file]}"
    echo
}

# Main function to parse args and run the demo
main() {
    # Set program name and usage text
    parseargs-set-prog-name "example"
    parseargs-set-usage "usage: example [options] [positional_args...]"
    parseargs-set-help "This is an example script demonstrating the parseargs.sh library."
    parseargs-set-epilog "For more information, see the parseargs.sh documentation."

    # Basic options
    parseargs-add-flag "-v/--verbose" --default "false" --help "Enable verbose output"
    parseargs-add-flag "-f/--force" --default "false" --help "Force operation"
    parseargs-add-parameter "-o/--output" --default "output.txt" --help "Output file"
    parseargs-add-parameter "-c/--count" --type "int" --default "1" --help "Number of iterations"

    # Add subcommands
    parseargs-add-subcommand "list" --help "List items"
    parseargs-add-subcommand "create" --help "Create an item"
    parseargs-add-subcommand "delete" --help "Delete an item"

    # Add subcommand-specific options
    parseargs-add-flag "-a/--all" --subcommand "list" --default "false" --help "List all items"
    parseargs-add-parameter "--format" --subcommand "list" --default "text" --choices "text,json,csv" --help "Output format"

    parseargs-add-parameter "-n/--name" --subcommand "create" --required --help "Item name"
    parseargs-add-parameter "-t/--type" --subcommand "create" --default "default" --help "Item type"

    parseargs-add-flag "-f/--force" --subcommand "delete" --default "false" --help "Force delete without confirmation"
    parseargs-add-positional "id" --subcommand "delete" --help "Item ID to delete"

    # Add options with choices
    parseargs-add-parameter "--color" --choices "red,green,blue,yellow" --default "blue" --help "Select a color"
    parseargs-add-parameter "--size" --choices "small,medium,large" --default "medium" --help "Select a size"

    # Add options with type validation
    parseargs-add-parameter "--integer" --type "int" --default "42" --help "An integer value"
    parseargs-add-parameter "--float" --type "float" --default "3.14" --help "A floating point value"
    parseargs-add-parameter "--boolean" --type "bool" --default "true" --help "A boolean value"
    parseargs-add-parameter "--file" --type "file" --help "A file path"

    # Add positional arguments
    parseargs-add-positional "input" --help "Input file" --required
    parseargs-add-positional "output" --help "Output file" --default "output.txt"

    # Parse command line arguments
    parseargs-parse "$@"

    # Check for return code - help requested?
    if [[ $? -eq 3 ]]; then
        exit 0
    fi

    # Run the demos
    basic_demo
    positional_demo
    subcommand_demo
    choices_demo
    types_demo
}

# Run the main function with all arguments
main "$@"
