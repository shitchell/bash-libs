#!/usr/bin/env bash
: '
Standardized help system for shell scripts

This library provides functions to create consistent help output across all scripts.
It supports option documentation, usage examples, and error messages with help hints.
'

# Global variables to store help information
declare -g __HELP_SCRIPT_NAME=""
declare -g __HELP_SCRIPT_DESC=""
declare -g __HELP_USAGE_LINE=""
declare -ga __HELP_OPTIONS=()
declare -ga __HELP_EXAMPLES=()
declare -g __HELP_EPILOGUE=""

function help-init() {
    : 'Initialize the help system with script information

        @arg $1 Script name (defaults to basename of $0)
        @arg $2 Brief description of the script
        @arg $3 Usage line (defaults to "$script_name [options]")

        @example
            help-init "my-script" "Does something useful" "my-script [options] <file>"
            help-init "" "Does something useful"  # Uses basename of $0
    '
    local script_name="${1:-$(basename "${0}")}"
    local description="${2}"
    local usage_line="${3:-${script_name} [options]}"

    # Validate inputs
    if [[ -z "${description}" ]]; then
        echo "error: help-init requires a description" >&2
        return 1
    fi

    # Store values
    __HELP_SCRIPT_NAME="${script_name}"
    __HELP_SCRIPT_DESC="${description}"
    __HELP_USAGE_LINE="${usage_line}"

    # Reset arrays
    __HELP_OPTIONS=()
    __HELP_EXAMPLES=()
    __HELP_EPILOGUE=""
}

function help-add-option() {
    : 'Add an option to the help documentation

        @arg $1 Short option (e.g., "-h")
        @arg $2 Long option (e.g., "--help")
        @arg $3 Description of the option
        @arg $4 Optional value placeholder (e.g., "<file>")

        @example
            help-add-option "-h" "--help" "Show this help message"
            help-add-option "-f" "--file" "Input file to process" "<file>"
            help-add-option "-v" "--verbose" "Enable verbose output"
    '
    local short_opt="${1}"
    local long_opt="${2}"
    local description="${3}"
    local value_placeholder="${4}"

    # Validate inputs
    if [[ -z "${short_opt}" ]] && [[ -z "${long_opt}" ]]; then
        echo "error: help-add-option requires at least one option flag" >&2
        return 1
    fi

    if [[ -z "${description}" ]]; then
        echo "error: help-add-option requires a description" >&2
        return 1
    fi

    # Build option string
    local option_str=""
    if [[ -n "${short_opt}" ]] && [[ -n "${long_opt}" ]]; then
        option_str="${short_opt}, ${long_opt}"
    elif [[ -n "${short_opt}" ]]; then
        option_str="${short_opt}"
    else
        option_str="    ${long_opt}"
    fi

    # Add value placeholder if provided
    if [[ -n "${value_placeholder}" ]]; then
        option_str="${option_str} ${value_placeholder}"
    fi

    # Store the option
    __HELP_OPTIONS+=("${option_str}|${description}")
}

function help-add-example() {
    : 'Add a usage example to the help documentation

        @arg $1 Example command
        @arg $2 Description of what the example does

        @example
            help-add-example "my-script -f input.txt" "Process input.txt"
            help-add-example "my-script -v --output result.txt" "Verbose mode with output file"
    '
    local example="${1}"
    local description="${2}"

    # Validate inputs
    if [[ -z "${example}" ]]; then
        echo "error: help-add-example requires an example command" >&2
        return 1
    fi

    # Store the example
    if [[ -n "${description}" ]]; then
        __HELP_EXAMPLES+=("${example}|${description}")
    else
        __HELP_EXAMPLES+=("${example}|")
    fi
}

function help-set-epilogue() {
    : 'Set additional information to display at the end of help

        @arg $1 Epilogue text

        @example
            help-set-epilogue "For more information, see: https://example.com"
    '
    __HELP_EPILOGUE="${1}"
}

function help-show() {
    : 'Display the formatted help message

        @stdout The complete help message

        @example
            help-show
    '

    # Check if help system was initialized
    if [[ -z "${__HELP_SCRIPT_NAME}" ]]; then
        echo "error: help system not initialized. Call help-init first." >&2
        return 1
    fi

    # Usage line
    echo "Usage: ${__HELP_USAGE_LINE}"

    # Description
    if [[ -n "${__HELP_SCRIPT_DESC}" ]]; then
        echo
        echo "${__HELP_SCRIPT_DESC}"
    fi

    # Options
    if [[ ${#__HELP_OPTIONS[@]} -gt 0 ]]; then
        echo
        echo "Options:"

        # Calculate column width for alignment
        local max_width=0
        local option_str
        for option_entry in "${__HELP_OPTIONS[@]}"; do
            option_str="${option_entry%%|*}"
            if [[ ${#option_str} -gt ${max_width} ]]; then
                max_width=${#option_str}
            fi
        done

        # Add padding
        max_width=$((max_width + 2))

        # Print options with aligned descriptions
        for option_entry in "${__HELP_OPTIONS[@]}"; do
            option_str="${option_entry%%|*}"
            description="${option_entry#*|}"
            printf "  %-${max_width}s %s\n" "${option_str}" "${description}"
        done
    fi

    # Examples
    if [[ ${#__HELP_EXAMPLES[@]} -gt 0 ]]; then
        echo
        echo "Examples:"

        for example_entry in "${__HELP_EXAMPLES[@]}"; do
            example="${example_entry%%|*}"
            description="${example_entry#*|}"

            echo "  ${example}"
            if [[ -n "${description}" ]] && [[ "${description}" != "${example}" ]]; then
                echo "    ${description}"
            fi
        done
    fi

    # Epilogue
    if [[ -n "${__HELP_EPILOGUE}" ]]; then
        echo
        echo "${__HELP_EPILOGUE}"
    fi
}

function help-error() {
    : 'Show an error message with a usage hint

        @arg $1 Error message
        @arg $2 Exit code (defaults to 1)

        @stdout Error message and usage hint to stderr

        @example
            help-error "Invalid option: --foo"
            help-error "Missing required argument" 2
    '
    local error_msg="${1}"
    local exit_code="${2:-1}"

    if [[ -z "${error_msg}" ]]; then
        echo "error: help-error requires an error message" >&2
        return 1
    fi

    # Print error message
    echo "error: ${error_msg}" >&2

    # Print usage hint if help system is initialized
    if [[ -n "${__HELP_SCRIPT_NAME}" ]]; then
        echo "Try '${__HELP_SCRIPT_NAME} --help' for more information." >&2
    fi

    # Exit with specified code if not in a subshell
    if [[ $BASH_SUBSHELL -eq 0 ]]; then
        exit "${exit_code}"
    else
        return "${exit_code}"
    fi
}

function help-usage() {
    : 'Display just the usage line

        @stdout The usage line

        @example
            help-usage
    '
    if [[ -z "${__HELP_USAGE_LINE}" ]]; then
        echo "error: help system not initialized. Call help-init first." >&2
        return 1
    fi

    echo "Usage: ${__HELP_USAGE_LINE}"
}