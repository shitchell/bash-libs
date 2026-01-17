#!/usr/bin/env bash
#
# args.sh - Simple argument parsing library
#
# Provides a lightweight alternative to parseargs.sh for common argument parsing
# patterns. Focuses on the most frequently used functionality with minimal complexity.
#
# Usage:
#   source "$(dirname "$0")/../lib/include.sh"
#   include-source 'args.sh'
#
#   # Initialize parser
#   args-init "Script description"
#
#   # Add arguments
#   args-add-flag "-v/--verbose" "Enable verbose output"
#   args-add-option "-f/--file" "FILE" "Input file path"
#   args-add-positional "source" "Source directory"
#
#   # Parse arguments
#   args-parse "$@"
#
# After parsing, values are available in associative arrays:
#   ${ARGS_FLAGS[verbose]} - true/false for flags
#   ${ARGS_OPTIONS[file]} - value for options
#   ${ARGS_POSITIONAL[0]} - first positional argument

# Global variables for argument storage
declare -A ARGS_FLAGS=()
declare -A ARGS_OPTIONS=()
declare -a ARGS_POSITIONAL=()
declare -A ARGS_REMAINING=()

# Internal storage for argument definitions
declare -A __ARGS_FLAG_DEFS=()
declare -A __ARGS_FLAG_SHORTS=()
declare -A __ARGS_OPTION_DEFS=()
declare -A __ARGS_OPTION_SHORTS=()
declare -A __ARGS_OPTION_METAVARS=()
declare -A __ARGS_POSITIONAL_DEFS=()
declare -A __ARGS_POSITIONAL_REQUIRED=()

# Script metadata
declare __ARGS_DESCRIPTION=""
declare __ARGS_PROGRAM_NAME=""
declare __ARGS_USAGE=""

function args-init() {
    : 'Initialize the argument parser

        @arg $1 [string] Script description
        @arg $2 [string] Optional program name (defaults to basename $0)
        @stdout None
        @return 0
    '
    __ARGS_DESCRIPTION="${1:-}"
    __ARGS_PROGRAM_NAME="${2:-$(basename "$0")}"

    # Reset all storage
    ARGS_FLAGS=()
    ARGS_OPTIONS=()
    ARGS_POSITIONAL=()
    ARGS_REMAINING=()
    __ARGS_FLAG_DEFS=()
    __ARGS_FLAG_SHORTS=()
    __ARGS_OPTION_DEFS=()
    __ARGS_OPTION_SHORTS=()
    __ARGS_OPTION_METAVARS=()
    __ARGS_POSITIONAL_DEFS=()
    __ARGS_POSITIONAL_REQUIRED=()

    # Always add help flags
    args-add-flag "-h/--help" "Show this help message"
}

function args-add-flag() {
    : 'Add a boolean flag argument

        @arg $1 [string] Flag spec like "-v/--verbose" or just "--verbose"
        @arg $2 [string] Help text for the flag
        @arg $3 [string] Optional default value (true/false, defaults to false)
        @stdout None
        @return 0 on success, 1 on error
    '
    local spec="$1"
    local help="${2:-}"
    local default="${3:-false}"

    [[ -z "$spec" ]] && { echo "args-add-flag: spec required" >&2; return 1; }

    local short long name

    # Parse spec: -s/--long, --long, or -s
    if [[ "$spec" =~ ^(-[a-zA-Z0-9])/(--.+)$ ]]; then
        short="${BASH_REMATCH[1]}"
        long="${BASH_REMATCH[2]}"
        name="${long#--}"
    elif [[ "$spec" =~ ^--.+ ]]; then
        long="$spec"
        name="${long#--}"
    elif [[ "$spec" =~ ^-[a-zA-Z0-9]$ ]]; then
        short="$spec"
        name="${short#-}"
    else
        echo "args-add-flag: invalid spec: $spec" >&2
        return 1
    fi

    # Convert name to variable-safe format (replace - with _)
    name="${name//-/_}"

    # Store definitions
    __ARGS_FLAG_DEFS["$name"]="$help"
    [[ -n "$short" ]] && __ARGS_FLAG_SHORTS["$short"]="$name"
    [[ -n "$long" ]] && __ARGS_FLAG_DEFS["$long"]="$name"

    # Set default value
    ARGS_FLAGS["$name"]="$default"

    return 0
}

function args-add-option() {
    : 'Add an option that takes a value

        @arg $1 [string] Option spec like "-f/--file" or just "--file"
        @arg $2 [string] Metavar for the value (e.g., "FILE", "DIR")
        @arg $3 [string] Help text for the option
        @arg $4 [string] Optional default value
        @stdout None
        @return 0 on success, 1 on error
    '
    local spec="$1"
    local metavar="$2"
    local help="${3:-}"
    local default="${4:-}"

    [[ -z "$spec" ]] && { echo "args-add-option: spec required" >&2; return 1; }
    [[ -z "$metavar" ]] && { echo "args-add-option: metavar required" >&2; return 1; }

    local short long name

    # Parse spec: -s/--long, --long, or -s
    if [[ "$spec" =~ ^(-[a-zA-Z0-9])/(--.+)$ ]]; then
        short="${BASH_REMATCH[1]}"
        long="${BASH_REMATCH[2]}"
        name="${long#--}"
    elif [[ "$spec" =~ ^--.+ ]]; then
        long="$spec"
        name="${long#--}"
    elif [[ "$spec" =~ ^-[a-zA-Z0-9]$ ]]; then
        short="$spec"
        name="${short#-}"
    else
        echo "args-add-option: invalid spec: $spec" >&2
        return 1
    fi

    # Convert name to variable-safe format
    name="${name//-/_}"

    # Store definitions
    __ARGS_OPTION_DEFS["$name"]="$help"
    __ARGS_OPTION_METAVARS["$name"]="$metavar"
    [[ -n "$short" ]] && __ARGS_OPTION_SHORTS["$short"]="$name"
    [[ -n "$long" ]] && __ARGS_OPTION_DEFS["$long"]="$name"

    # Set default value
    [[ -n "$default" ]] && ARGS_OPTIONS["$name"]="$default"

    return 0
}

function args-add-positional() {
    : 'Add a positional argument

        @arg $1 [string] Name of the positional argument
        @arg $2 [string] Help text for the argument
        @arg $3 [string] Optional "required" or "optional" (defaults to optional)
        @stdout None
        @return 0 on success, 1 on error
    '
    local name="$1"
    local help="${2:-}"
    local required="${3:-optional}"

    [[ -z "$name" ]] && { echo "args-add-positional: name required" >&2; return 1; }

    # Store in order
    local index="${#__ARGS_POSITIONAL_DEFS[@]}"
    __ARGS_POSITIONAL_DEFS["$index"]="$name:$help"

    [[ "$required" == "required" ]] && __ARGS_POSITIONAL_REQUIRED["$name"]="true"

    return 0
}

function args-parse() {
    : 'Parse command line arguments

        @arg $@ Arguments to parse (typically "$@")
        @stdout None (may output help)
        @return 0 on success, 1 on error, 2 on help requested
    '
    local -a remaining=()

    while [[ $# -gt 0 ]]; do
        local arg="$1"

        case "$arg" in
            -h|--help)
                __args-show-help
                return 2
                ;;

            --) # End of options
                shift
                remaining+=("$@")
                break
                ;;

            --no-*)
                # Handle --no- prefix for flags
                local flag_name="${arg#--no-}"
                flag_name="${flag_name//-/_}"

                if [[ -n "${__ARGS_FLAG_DEFS[$flag_name]+x}" ]]; then
                    ARGS_FLAGS["$flag_name"]="false"
                    shift
                else
                    echo "Unknown option: $arg" >&2
                    return 1
                fi
                ;;

            --*=*)
                # Handle --option=value format
                local option="${arg%%=*}"
                local value="${arg#*=}"

                if [[ -n "${__ARGS_OPTION_DEFS[$option]+x}" ]]; then
                    local name="${__ARGS_OPTION_DEFS[$option]}"
                    ARGS_OPTIONS["$name"]="$value"
                    shift
                else
                    echo "Unknown option: $option" >&2
                    return 1
                fi
                ;;

            --*)
                # Long option
                local name="${arg#--}"
                name="${name//-/_}"

                if [[ -n "${__ARGS_FLAG_DEFS[$name]+x}" ]]; then
                    ARGS_FLAGS["$name"]="true"
                    shift
                elif [[ -n "${__ARGS_OPTION_DEFS[$arg]+x}" ]]; then
                    # This is an option that needs a value
                    local opt_name="${__ARGS_OPTION_DEFS[$arg]}"
                    shift
                    if [[ $# -eq 0 || "$1" == -* ]]; then
                        echo "Option $arg requires a value" >&2
                        return 1
                    fi
                    ARGS_OPTIONS["$opt_name"]="$1"
                    shift
                else
                    echo "Unknown option: $arg" >&2
                    return 1
                fi
                ;;

            -*)
                # Short option(s)
                local opts="${arg#-}"
                local i

                for (( i=0; i<${#opts}; i++ )); do
                    local opt="-${opts:$i:1}"

                    if [[ -n "${__ARGS_FLAG_SHORTS[$opt]+x}" ]]; then
                        local name="${__ARGS_FLAG_SHORTS[$opt]}"
                        ARGS_FLAGS["$name"]="true"
                    elif [[ -n "${__ARGS_OPTION_SHORTS[$opt]+x}" ]]; then
                        local name="${__ARGS_OPTION_SHORTS[$opt]}"

                        # If this is not the last character, the rest is the value
                        if [[ $((i + 1)) -lt ${#opts} ]]; then
                            ARGS_OPTIONS["$name"]="${opts:$((i + 1))}"
                            break
                        else
                            # Need next argument as value
                            shift
                            if [[ $# -eq 0 || "$1" == -* ]]; then
                                echo "Option $opt requires a value" >&2
                                return 1
                            fi
                            ARGS_OPTIONS["$name"]="$1"
                        fi
                    else
                        echo "Unknown option: $opt" >&2
                        return 1
                    fi
                done
                shift
                ;;

            *)
                # Positional argument
                ARGS_POSITIONAL+=("$arg")
                shift
                ;;
        esac
    done

    # Add any remaining arguments after --
    ARGS_POSITIONAL+=("${remaining[@]}")

    # Store remaining for compatibility
    ARGS_REMAINING=("${ARGS_POSITIONAL[@]}")

    return 0
}

function args-validate() {
    : 'Validate that required arguments were provided

        @stdout Error messages if validation fails
        @return 0 if valid, 1 if invalid
    '
    local valid=true

    # Check required positional arguments
    local pos_count=0
    for name in "${__ARGS_POSITIONAL_REQUIRED[@]}"; do
        [[ "${__ARGS_POSITIONAL_REQUIRED[$name]}" == "true" ]] && ((pos_count++))
    done

    if [[ ${#ARGS_POSITIONAL[@]} -lt $pos_count ]]; then
        echo "Error: Expected at least $pos_count positional arguments, got ${#ARGS_POSITIONAL[@]}" >&2
        valid=false
    fi

    [[ "$valid" == "true" ]] && return 0 || return 1
}

function __args-show-help() {
    : 'Internal function to display help message

        @stdout Formatted help message
        @return 0
    '
    # Usage line
    echo "Usage: $__ARGS_PROGRAM_NAME [OPTIONS]"

    # Add positional args to usage
    local i
    for (( i=0; i<${#__ARGS_POSITIONAL_DEFS[@]}; i++ )); do
        local def="${__ARGS_POSITIONAL_DEFS[$i]}"
        local name="${def%%:*}"
        local is_required="${__ARGS_POSITIONAL_REQUIRED[$name]:-false}"

        if [[ "$is_required" == "true" ]]; then
            echo -n " <$name>"
        else
            echo -n " [$name]"
        fi
    done
    echo

    # Description
    if [[ -n "$__ARGS_DESCRIPTION" ]]; then
        echo
        echo "$__ARGS_DESCRIPTION"
    fi

    # Options section
    echo
    echo "Options:"

    # Collect all options for formatting
    local -a option_lines=()
    local max_option_width=0

    # Help is always first
    option_lines+=("  -h, --help")
    [[ ${#option_lines[-1]} -gt $max_option_width ]] && max_option_width=${#option_lines[-1]}

    # Process flags
    for name in "${!__ARGS_FLAG_DEFS[@]}"; do
        [[ "$name" == "--"* ]] && continue  # Skip long option entries
        [[ "$name" == "help" ]] && continue  # Skip help, already added

        local short=""
        local long="--${name//_/-}"

        # Find short option
        for s in "${!__ARGS_FLAG_SHORTS[@]}"; do
            [[ "${__ARGS_FLAG_SHORTS[$s]}" == "$name" ]] && short="$s" && break
        done

        local opt_text="  "
        [[ -n "$short" ]] && opt_text+="$short, "
        opt_text+="$long"

        option_lines+=("$opt_text")
        [[ ${#opt_text} -gt $max_option_width ]] && max_option_width=${#opt_text}
    done

    # Process options
    for name in "${!__ARGS_OPTION_DEFS[@]}"; do
        [[ "$name" == "--"* ]] && continue  # Skip long option entries

        local short=""
        local long="--${name//_/-}"
        local metavar="${__ARGS_OPTION_METAVARS[$name]}"

        # Find short option
        for s in "${!__ARGS_OPTION_SHORTS[@]}"; do
            [[ "${__ARGS_OPTION_SHORTS[$s]}" == "$name" ]] && short="$s" && break
        done

        local opt_text="  "
        [[ -n "$short" ]] && opt_text+="$short, "
        opt_text+="$long <$metavar>"

        option_lines+=("$opt_text")
        [[ ${#opt_text} -gt $max_option_width ]] && max_option_width=${#opt_text}
    done

    # Print formatted options
    local idx=0
    for opt_line in "${option_lines[@]}"; do
        printf "%-${max_option_width}s" "$opt_line"

        # Add help text
        if [[ $idx -eq 0 ]]; then
            echo "  Show this help message"
        else
            # Find the corresponding help text
            local opt_name
            if [[ "$opt_line" =~ --([a-z-]+) ]]; then
                opt_name="${BASH_REMATCH[1]//-/_}"
                local help_text="${__ARGS_FLAG_DEFS[$opt_name]:-${__ARGS_OPTION_DEFS[$opt_name]:-}}"
                [[ -n "$help_text" && "$help_text" != "$opt_name" ]] && echo "  $help_text" || echo
            else
                echo
            fi
        fi
        ((idx++))
    done

    # Positional arguments section
    if [[ ${#__ARGS_POSITIONAL_DEFS[@]} -gt 0 ]]; then
        echo
        echo "Positional arguments:"

        for (( i=0; i<${#__ARGS_POSITIONAL_DEFS[@]}; i++ )); do
            local def="${__ARGS_POSITIONAL_DEFS[$i]}"
            local name="${def%%:*}"
            local help="${def#*:}"
            local is_required="${__ARGS_POSITIONAL_REQUIRED[$name]:-false}"

            printf "  %-${max_option_width}s" "$name"
            [[ -n "$help" ]] && echo "  $help"
            [[ "$is_required" == "true" ]] && echo -n " (required)"
            echo
        done
    fi

    return 0
}

# Convenience functions for common patterns

function args-get-flag() {
    : 'Get the value of a flag

        @arg $1 [string] Flag name (without dashes)
        @stdout true or false
        @return 0
    '
    local name="${1//-/_}"
    echo "${ARGS_FLAGS[$name]:-false}"
}

function args-get-option() {
    : 'Get the value of an option

        @arg $1 [string] Option name (without dashes)
        @stdout Option value or empty string
        @return 0 if set, 1 if not set
    '
    local name="${1//-/_}"
    if [[ -n "${ARGS_OPTIONS[$name]+x}" ]]; then
        echo "${ARGS_OPTIONS[$name]}"
        return 0
    else
        return 1
    fi
}

function args-get-positional() {
    : 'Get a positional argument by index

        @arg $1 [int] Zero-based index
        @stdout Argument value or empty string
        @return 0 if exists, 1 if not
    '
    local index="$1"
    if [[ $index -lt ${#ARGS_POSITIONAL[@]} ]]; then
        echo "${ARGS_POSITIONAL[$index]}"
        return 0
    else
        return 1
    fi
}

function args-has-flag() {
    : 'Check if a flag was explicitly set (not just defaulted)

        @arg $1 [string] Flag name (without dashes)
        @return 0 if set, 1 if not
    '
    local name="${1//-/_}"
    [[ "${ARGS_FLAGS[$name]}" == "true" ]]
}

function args-has-option() {
    : 'Check if an option was provided

        @arg $1 [string] Option name (without dashes)
        @return 0 if set, 1 if not
    '
    local name="${1//-/_}"
    [[ -n "${ARGS_OPTIONS[$name]+x}" ]]
}