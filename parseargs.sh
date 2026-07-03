#!/usr/bin/env bash
#
# This module provides functions for parsing command line arguments.
# Inspired heavily by the argparse module in the Python standard library:
# https://docs.python.org/3/library/argparse.html
#
# Common options:
#   -h/--help <help text>   Help text to display for the option
#   -r/--required           Show an exception if this option/argument is not provided
#   -d/--default <value>    Default value for the option/argument
#   -n/--nargs <*|+|?|N>    Number of arguments for the argument
#                             * - zero or more arguments
#                             + - one or more arguments
#                             ? - zero or one argument
#                             N - exactly N arguments
#
# Arguments are divided into three categories:
#   - Flags
#     Arguments that start with a dash (-) or double dash (--) and accept no
#     parameters. Their presence indicates a boolean value.
#   - Parameters
#     Arguments that start with a dash (-) or double dash (--) and accept a
#     parameter. They can be optional or required.
#   - Positional
#     Arguments that do not start with a dash (-) or double dash (--). Their
#     order is important, and they can be optional or required.
#
# Functions:
#   parseargs-add-flag <short_name/long_name> [options]
#   parseargs-add-positional <name> [options]
#   parseargs-add-parameter <short_name/long_name> [options]
#   parseargs-add-argument-group <name> <description>
#   parseargs-set-usage <usage text>
#   parseargs-set-epilog <epilog text>
#   parseargs-set-help <help text>
#   parseargs-set-prog-name <program name>
#   parseargs-parse <argv>
#
# Extended usage:
#   `parseargs-add-subcommand`:
#   This function is used to add a subcommand to the parser. It takes the name
#   of the subcommand as the first argument and an optional help text as the
#   second argument. Subsequent calls to `parseargs-add-flag`, `parseargs-add-positional`, and
#   `parseargs-add-parameter` can optionally specify the subcommand to which they belong.
#
#     usage:
#       parseargs-add-subcommand <name> [-h|--help <text>]
#
#     examples:
#       parseargs-add-subcommand "list"
#       => {prog} list
#       parseargs-add-subcommand "install" --help "Install a package"
#       => {prog} install
#
#   `parseargs-add-flag`:
#   This function is used to add a flag to the parser. It takes the short
#   name and long name of the option as the first argument. The option can be
#   required or optional, and can store a value in a variable. The option can
#   also have a default value and a help text. Every call to this function will
#   create two options: a positive option (e.g. --verbose) and a negative option
#   (e.g. --no-verbose). If a variable name is not specified by `--store`, the
#   option's long name with dashes replaced by underscores will be used (e.g.:
#   --verbose -> verbose).
#
#     usage:
#       parseargs-add-flag <short_name/long_name> [-r|--required] [-d|--default <value>]
#                  [-s|--store <var_name>] [-C|--subcommand <name>]
#                  [-h|--help <text>]
#
#     examples:
#       parseargs-add-flag "-v/--verbose" --default false --help "verbose output"
#       => {prog} -v, {prog} --verbose
#       => {prog} --no-v, {prog} --no-verbose
#
#       parseargs-add-flag "--force" --help "force the operation"
#       => {prog} --force, {prog} --no-force
#
#       parseargs-add-flag "-a/--all" --subcommand "list" --store "list_all" \
#           --help "list all items"
#       => {prog} list -a, {prog} list --all
#       => {prog} list --no-a, {prog} list --no-all
#
#   `parseargs-add-parameter`:
#   This function is used to add a parameter to the parser. It takes the short
#   name and long name of the option as the first argument. The option can be
#   required or optional, and can store a value in a variable. The option can
#   also have a default value and a help text.
#
#     usage:
#       parseargs-add-parameter <short_name/long_name> [-r|--required]
#                     [-d|--default <value>] [-s|--store <var_name>]
#                     [-C|--subcommand <name>] [-f|--flag] [-n|--nargs <+|*|int>]
#                     [-c|--choices <value1,value2,...>] [--type <type>]
#                     [-h|--help <text>]
#
#   `parseargs-add-positional`:
#   This function is used to add a positional argument to the parser. It takes
#   the name of the argument as the first argument. The argument can be required
#   or optional, and can store a value in a variable. The argument can also have
#   a default value and a help text.
#
#     usage:
#       parseargs-add-positional <name> [--type <type>] [-n|--nargs <+|*|int>]
#                     [-d|--default <value>] [-c|--choices <value1,value2,...>]
#                     [-F|--follows <separator>] [-r|--required] [--help <text>]
#
#   `parseargs-parse`:
#   This function is used to parse the command line arguments. It takes the
#   command line arguments as the first argument and stores the parsed values
#   in the specified variable names.
#
#     usage:
#       parseargs-parse <argv>
#
# Types:
#   int - integer
#   float - floating point number
#   bool - boolean ("true", "false", 0, 1)
#   string - string
#   file - file
#   dir - directory
#   path - path (file or directory)
#
# Type specific options:
#   int|float:
#     --negative-only - only allow negative values
#     --positive-only - only allow positive values
#     --min <value> - minimum value
#     --max <value> - maximum value
#   file|dir|path:
#     --exists - only allow existing files or directories
#     --no-exists - only allow non-existing files or directories
#     --readable - only allow readable files or directories
#     --writable - only allow writable files or directories
#     --executable - only allow executable files or directories
#
# Example:
#   source argparse.sh
#   parseargs-add-flag "-f/--force" --default false \
#     --help "Force the operation"
#   parseargs-add-flag "-v/--verbose" --default false --store verbosity \
#     --help "Verbose output"
#   parseargs-add-flag "-q/--quiet" --default true --store verbosity \
#     --help "Quiet output"
#   parseargs-add-parameter "-f/--file" --type array --store filepaths \
#     --help "File to operate on"
#   parseargs-add-positional "filepaths" --type filepath --store command --follows "--" --default "" \
#     --help "Filepaths to operate on"
#   parseargs-parse "$@"
#   echo "force is set to: ${PARSEARGS_OPTS['force']}"
#   if ${PARSEARGS_OPTS['force']}; then
#     echo "warning: this will overwrite any existing changes" >&2
#   fi

include-source 'debug'
include-source 'exit-codes'
include-source 'text'

# Global variables to store parser configuration
declare -gA PARSEARGS_FLAGS=()
declare -gA PARSEARGS_PARAMETERS=()
declare -gA PARSEARGS_POSITIONALS=()
declare -gA PARSEARGS_SUBCOMMANDS=()
declare -gA PARSEARGS_OPTS=()
declare -ga PARSEARGS_POSARGS=()
declare -g PARSEARGS_PROG_NAME="$(basename "${0}")"
declare -g PARSEARGS_USAGE=""
declare -g PARSEARGS_EPILOG=""
declare -g PARSEARGS_HELP=""
declare -g PARSEARGS_ACTIVE_SUBCOMMAND=""
declare -g PARSEARGS_FROM_FUNCTION=""
declare -g PARSEARGS_INCLUDES=""
declare -ga PARSEARGS_OPTION_ORDER=()
declare -g PARSEARGS_BUILTIN_KEYS=" "
declare -g PARSEARGS_BUILTINS_REGISTERED=false

# @description Initialize the parser
# @usage parseargs-init
function parseargs-init() {
    : 'Initialize the argument parser

        @usage
            parseargs-init [--from-function <function_name>]

        @option --from-function <function_name>
            Initialize parser from function docstring

        @return 0
            Successfully initialized

        @return 1
            Error during initialization
    '
    local from_function=""

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --from-function)
                from_function="$2"
                shift 2
                ;;
            *)
                shift
                ;;
        esac
    done

    # Reset all global variables
    declare -gA PARSEARGS_FLAGS=()
    declare -gA PARSEARGS_PARAMETERS=()
    declare -gA PARSEARGS_POSITIONALS=()
    declare -gA PARSEARGS_SUBCOMMANDS=()
    declare -gA PARSEARGS_OPTS=()
    declare -ga PARSEARGS_POSARGS=()

    # Set default program name based on the current script
    PARSEARGS_PROG_NAME=$(basename "${0}")
    PARSEARGS_USAGE=""
    PARSEARGS_EPILOG=""
    PARSEARGS_HELP=""
    PARSEARGS_ACTIVE_SUBCOMMAND=""
    PARSEARGS_FROM_FUNCTION=""
    PARSEARGS_INCLUDES=""
    declare -ga PARSEARGS_OPTION_ORDER=()
    PARSEARGS_BUILTIN_KEYS=" "
    PARSEARGS_BUILTINS_REGISTERED=false

    debug "Parser initialized"

    # If from_function is specified, configure from docstring
    if [[ -n "${from_function}" ]]; then
        PARSEARGS_FROM_FUNCTION="${from_function}"
        parseargs-configure-from-docstring "${from_function}"
    fi
}

# @description Configure parseargs from a function's docstring
# @usage parseargs-configure-from-docstring <function_name>
function parseargs-configure-from-docstring() {
    : 'Configure the argument parser from a function docstring

        @usage
            parseargs-configure-from-docstring <function_name>

        @arg <function_name>
            The function whose docstring to parse

        @return 0
            Successfully configured

        @return 1
            Function not found or no docstring

        @return 2
            docs.sh not available
    '
    local func_name="$1"

    # Check if docs.sh functions are available
    if ! type -t generate-function-docstring >/dev/null 2>&1; then
        debug "docs.sh not available, cannot configure from docstring"
        return 2
    fi

    # Extract docstring information
    local -A DOCSTRING
    local docstring_output
    docstring_output=$(generate-function-docstring "${func_name}" 2>/dev/null)
    [[ $? -ne 0 ]] && return 1

    eval "${docstring_output}"

    # Set program name from function name
    parseargs-set-prog-name "${func_name}"

    # Set help text from summary/description
    local help_text=""
    [[ -n "${DOCSTRING[summary]}" ]] && help_text="${DOCSTRING[summary]}"
    [[ -n "${DOCSTRING[description]}" ]] && {
        [[ -n "${help_text}" ]] && help_text+=$'\n\n'
        help_text+="${DOCSTRING[description]}"
    }
    [[ -n "${help_text}" ]] && parseargs-set-help "${help_text}"

    # Set usage if available
    [[ -n "${DOCSTRING[usage]}" ]] && parseargs-set-usage "${DOCSTRING[usage]}"

    # Parse options
    if [[ -n "${DOCSTRING[option]}" ]]; then
        # Handle multiple options separated by Record Separator
        IFS=$'\x1e' read -ra options <<< "${DOCSTRING[option]}"
        for option in "${options[@]}"; do
            local opt_spec opt_desc
            if [[ "$option" =~ $'\x1f' ]]; then
                # Split by Unit Separator
                IFS=$'\x1f' read -r opt_spec opt_desc <<< "$option"
            else
                # Try to split by colon or multiple spaces
                if [[ "$option" =~ ^([^:]+):(.*)$ ]]; then
                    opt_spec="${BASH_REMATCH[1]}"
                    opt_desc="${BASH_REMATCH[2]}"
                elif [[ "$option" =~ ^([^ ]+)[[:space:]]{2,}(.*)$ ]]; then
                    opt_spec="${BASH_REMATCH[1]}"
                    opt_desc="${BASH_REMATCH[2]}"
                else
                    opt_spec="$option"
                    opt_desc=""
                fi
            fi

            # Clean up the option spec and description
            opt_spec="${opt_spec#"${opt_spec%%[![:space:]]*}"}"
            opt_spec="${opt_spec%"${opt_spec##*[![:space:]]}"}"
            opt_desc="${opt_desc#"${opt_desc%%[![:space:]]*}"}"
            opt_desc="${opt_desc%"${opt_desc##*[![:space:]]}"}"

            # Determine if it's a flag or parameter (has <value> or similar)
            if [[ "${opt_spec}" =~ \<.*\> ]]; then
                # It's a parameter - extract the option name
                local opt_name="${opt_spec%% *}"
                parseargs-add-parameter "${opt_name}" --help "${opt_desc}"
            else
                # It's a flag
                parseargs-add-flag "${opt_spec}" --help "${opt_desc}"
            fi
        done
    fi

    # Parse positional arguments
    local arg_position=0
    for key in arg optarg; do
        if [[ -n "${DOCSTRING[$key]}" ]]; then
            # Handle multiple args separated by Record Separator
            IFS=$'\x1e' read -ra args <<< "${DOCSTRING[$key]}"
            for arg in "${args[@]}"; do
                local arg_name arg_desc
                if [[ "$arg" =~ $'\x1f' ]]; then
                    # Split by Unit Separator
                    IFS=$'\x1f' read -r arg_name arg_desc <<< "$arg"
                else
                    # Try to split by colon or multiple spaces
                    if [[ "$arg" =~ ^([^:]+):(.*)$ ]]; then
                        arg_name="${BASH_REMATCH[1]}"
                        arg_desc="${BASH_REMATCH[2]}"
                    elif [[ "$arg" =~ ^([^ ]+)[[:space:]]{2,}(.*)$ ]]; then
                        arg_name="${BASH_REMATCH[1]}"
                        arg_desc="${BASH_REMATCH[2]}"
                    else
                        arg_name="$arg"
                        arg_desc=""
                    fi
                fi

                # Clean up the argument name and description
                arg_name="${arg_name#"${arg_name%%[![:space:]]*}"}"
                arg_name="${arg_name%"${arg_name##*[![:space:]]}"}"
                arg_name="${arg_name#<}"
                arg_name="${arg_name%>}"
                arg_desc="${arg_desc#"${arg_desc%%[![:space:]]*}"}"
                arg_desc="${arg_desc%"${arg_desc##*[![:space:]]}"}"

                # Add positional argument
                local required=true
                [[ "$key" == "optarg" ]] && required=false
                parseargs-add-positional "${arg_name}" --help "${arg_desc}" ${required:+--required}
                ((arg_position++))
            done
        fi
    done

    return 0
}

# @description Set the program name for the parser
# @usage parseargs-set-prog-name <program name>
function parseargs-set-prog-name() {
    PARSEARGS_PROG_NAME="${1}"
    debug "Program name set to '${PARSEARGS_PROG_NAME}'"
}

# @description Set the usage text for the parser
# @usage parseargs-set-usage <usage text>
function parseargs-set-usage() {
    PARSEARGS_USAGE="${1}"
    debug "Usage text set"
}

# @description Set the epilog text for the parser
# @usage parseargs-set-epilog <epilog text>
function parseargs-set-epilog() {
    PARSEARGS_EPILOG="${1}"
    debug "Epilog text set"
}

# @description Set the help text for the parser
# @usage parseargs-set-help <help text>
function parseargs-set-help() {
    PARSEARGS_HELP="${1}"
    debug "Help text set"
}

# @description Add a subcommand to the parser
# @usage parseargs-add-subcommand <name> [-h|--help <text>]
function parseargs-add-subcommand() {
    local name="${1}"
    local help=""
    shift 1

    # Parse options
    while [[ ${#} -gt 0 ]]; do
        case "${1}" in
            -h | --help)
                help="${2}"
                shift 2
                ;;
            *)
                debug "Unknown option: ${1}"
                shift 1
                ;;
        esac
    done

    # Store subcommand details
    PARSEARGS_SUBCOMMANDS["${name}:help"]="${help}"

    debug "Added subcommand '${name}'"

    # Explicit success: debug returns 1 when DEBUG is unset
    return ${E_SUCCESS:-0}
}

# @description Parse a short_name/long_name format string into short and long names
# @usage parseargs-parse-flag-names <short_name/long_name>
# @returns <short_name>,<long_name>
function parseargs-parse-flag-names() {
    local input="${1}"
    local short_name=""
    local long_name=""

    # Check if the input contains a '/'
    if [[ "${input}" =~ ^(-[^/]+)/(--.+)$ ]]; then
        short_name="${BASH_REMATCH[1]}"
        long_name="${BASH_REMATCH[2]}"
    elif [[ "${input}" =~ ^(--.+)$ ]]; then
        # Only long name provided
        long_name="${BASH_REMATCH[1]}"
    elif [[ "${input}" =~ ^(-[^-].*)$ ]]; then
        # Only short name provided
        short_name="${BASH_REMATCH[1]}"
    else
        debug "Invalid flag name format: ${input}"
        return 1
    fi

    # Return both names
    echo "${short_name},${long_name}"
}

# @description Find the registered option claiming a name, e.g. -s or --silent
# @usage parseargs--find-key-by-name <name>
# @stdout "flag:<key>" or "param:<key>" if the name is claimed
function parseargs--find-key-by-name() {
    local name="${1}"
    local key
    [[ -z "${name}" ]] && return 1
    for key in "${!PARSEARGS_FLAGS[@]}"; do
        [[ "${key}" == *:short || "${key}" == *:long ]] || continue
        [[ "${PARSEARGS_FLAGS[${key}]}" == "${name}" ]] \
            && { echo "flag:${key%:*}"; return 0; }
    done
    for key in "${!PARSEARGS_PARAMETERS[@]}"; do
        [[ "${key}" == *:short || "${key}" == *:long ]] || continue
        [[ "${PARSEARGS_PARAMETERS[${key}]}" == "${name}" ]] \
            && { echo "param:${key%:*}"; return 0; }
    done
    return 1
}

# @description Remove a registered option entirely (both names, all fields)
# @usage parseargs--drop-option <flag:key | param:key>
function parseargs--drop-option() {
    local entry="${1}"
    local type="${entry%%:*}" key="${entry#*:}"
    local field

    if [[ "${type}" == "flag" ]]; then
        for field in short long required default store help subcommand count const; do
            unset "PARSEARGS_FLAGS[${key}:${field}]"
        done
    else
        for field in short long required default store help subcommand flag nargs choices type; do
            unset "PARSEARGS_PARAMETERS[${key}:${field}]"
        done
    fi

    # Remove from the declaration order and the built-in registry
    local -a __order=()
    local o
    for o in "${PARSEARGS_OPTION_ORDER[@]}"; do
        [[ "${o}" == "${entry}" ]] || __order+=("${o}")
    done
    PARSEARGS_OPTION_ORDER=("${__order[@]}")
    PARSEARGS_BUILTIN_KEYS="${PARSEARGS_BUILTIN_KEYS/ ${entry} / }"
}

# @description Guard a new option's names: -h/--help are reserved; claiming a
#   built-in's name drops the built-in; claiming a user option's name errors
# @usage parseargs--guard-option-names <short_name> <long_name>
function parseargs--guard-option-names() {
    local short_name="${1}" long_name="${2}"
    local name claimed

    if [[ "${short_name}" == "-h" || "${long_name}" == "--help" ]]; then
        echo "Error: -h/--help is reserved" >&2
        return ${E_INVALID_OPTION:-13}
    fi

    for name in "${short_name}" "${long_name}"; do
        [[ -z "${name}" ]] && continue
        if claimed=$(parseargs--find-key-by-name "${name}"); then
            if [[ "${PARSEARGS_BUILTIN_KEYS}" == *" ${claimed} "* ]]; then
                # User options win over built-ins: drop the whole built-in
                parseargs--drop-option "${claimed}"
            else
                echo "Error: option ${name} already defined" >&2
                return ${E_INVALID_OPTION:-13}
            fi
        fi
    done
}

# @description Add a flag option to the parser
# @usage parseargs-add-flag <short_name/long_name> [-r|--required] [-d|--default <value>]
#          [-s|--store <var_name>] [-C|--subcommand <name>] [--count] [-h|--help <text>]
function parseargs-add-flag() {
    local flag_spec="${1}"
    local required=false
    local default=""
    local store=""
    local help=""
    local subcommand=""
    local count=false
    local const=""
    shift 1

    # Parse the flag specification
    local flag_names
    flag_names=$(parseargs-parse-flag-names "${flag_spec}")
    local short_name long_name
    IFS=',' read -r short_name long_name <<<"${flag_names}"

    # Reject reserved names, handle collisions
    parseargs--guard-option-names "${short_name}" "${long_name}" || return ${?}

    # Extract the long name without the '--' prefix for use as the storage variable
    local long_name_clean=""
    if [[ -n "${long_name}" ]]; then
        long_name_clean="${long_name#--}"
    fi

    # Parse options
    while [[ ${#} -gt 0 ]]; do
        case "${1}" in
            -r | --required)
                required=true
                shift 1
                ;;
            -d | --default)
                default="${2}"
                shift 2
                ;;
            -s | --store)
                store="${2}"
                shift 2
                ;;
            -C | --subcommand)
                subcommand="${2}"
                shift 2
                ;;
            --count)
                count=true
                shift 1
                ;;
            --const)
                const="${2}"
                shift 2
                ;;
            -h | --help)
                help="${2}"
                shift 2
                ;;
            *)
                debug "Unknown option: ${1}"
                shift 1
                ;;
        esac
    done

    # Set default store variable name if not provided
    if [[ -z "${store}" && -n "${long_name_clean}" ]]; then
        store="${long_name_clean//-/_}"
    elif [[ -z "${store}" && -n "${short_name}" ]]; then
        store="${short_name#-}"
    fi

    # Create a unique key for this flag
    local key="${subcommand:+${subcommand}:}${long_name_clean:-${short_name#-}}"

    # Store flag details
    PARSEARGS_FLAGS["${key}:short"]="${short_name}"
    PARSEARGS_FLAGS["${key}:long"]="${long_name}"
    PARSEARGS_FLAGS["${key}:required"]="${required}"
    PARSEARGS_FLAGS["${key}:default"]="${default}"
    PARSEARGS_FLAGS["${key}:store"]="${store}"
    PARSEARGS_FLAGS["${key}:help"]="${help}"
    PARSEARGS_FLAGS["${key}:subcommand"]="${subcommand}"
    PARSEARGS_FLAGS["${key}:count"]="${count}"
    PARSEARGS_FLAGS["${key}:const"]="${const}"
    PARSEARGS_OPTION_ORDER+=("flag:${key}")

    # Also store in the base key for direct access in tests
    if [[ -n "${subcommand}" ]]; then
        PARSEARGS_FLAGS["verbose:subcommand"]="${subcommand}"
    fi

    debug "Added flag '${key}' (${short_name:-n/a}/${long_name:-n/a})"

    # Explicit success: debug returns 1 when DEBUG is unset
    return ${E_SUCCESS:-0}
}

# @description Add a parameter option to the parser
# @usage parseargs-add-parameter <short_name/long_name> [-r|--required] [-d|--default <value>]
#           [-s|--store <var_name>] [-C|--subcommand <name>] [-f|--flag] [-n|--nargs <+|*|int>]
#           [-c|--choices <value1,value2,...>] [--type <type>] [-h|--help <text>]
function parseargs-add-parameter() {
    local param_spec="${1}"
    local required=false
    local default=""
    local store=""
    local help=""
    local subcommand=""
    local flag=false
    local nargs=1
    local choices=""
    local type="string"
    shift 1

    # Parse the parameter specification
    local param_names
    param_names=$(parseargs-parse-flag-names "${param_spec}")
    local short_name long_name
    IFS=',' read -r short_name long_name <<<"${param_names}"

    # Reject reserved names, handle collisions
    parseargs--guard-option-names "${short_name}" "${long_name}" || return ${?}

    # Extract the long name without the '--' prefix for use as the storage variable
    local long_name_clean=""
    if [[ -n "${long_name}" ]]; then
        long_name_clean="${long_name#--}"
    fi

    # Parse options
    while [[ ${#} -gt 0 ]]; do
        case "${1}" in
            -r | --required)
                required=true
                shift 1
                ;;
            -d | --default)
                default="${2}"
                shift 2
                ;;
            -s | --store)
                store="${2}"
                shift 2
                ;;
            -C | --subcommand)
                subcommand="${2}"
                shift 2
                ;;
            -f | --flag)
                flag=true
                shift 1
                ;;
            -n | --nargs)
                nargs="${2}"
                shift 2
                ;;
            -c | --choices)
                choices="${2}"
                shift 2
                ;;
            --type)
                type="${2}"
                shift 2
                ;;
            -h | --help)
                help="${2}"
                shift 2
                ;;
            *)
                debug "Unknown option: ${1}"
                shift 1
                ;;
        esac
    done

    # Set default store variable name if not provided
    if [[ -z "${store}" && -n "${long_name_clean}" ]]; then
        store="${long_name_clean//-/_}"
    elif [[ -z "${store}" && -n "${short_name}" ]]; then
        store="${short_name#-}"
    fi

    # Create a unique key for this parameter
    local key="${subcommand:+${subcommand}:}${long_name_clean:-${short_name#-}}"

    # Store parameter details
    PARSEARGS_PARAMETERS["${key}:short"]="${short_name}"
    PARSEARGS_PARAMETERS["${key}:long"]="${long_name}"
    PARSEARGS_PARAMETERS["${key}:required"]="${required}"
    PARSEARGS_PARAMETERS["${key}:default"]="${default}"
    PARSEARGS_PARAMETERS["${key}:store"]="${store}"
    PARSEARGS_PARAMETERS["${key}:help"]="${help}"
    PARSEARGS_PARAMETERS["${key}:subcommand"]="${subcommand}"
    PARSEARGS_PARAMETERS["${key}:flag"]="${flag}"
    PARSEARGS_PARAMETERS["${key}:nargs"]="${nargs}"
    PARSEARGS_PARAMETERS["${key}:choices"]="${choices}"
    PARSEARGS_PARAMETERS["${key}:type"]="${type}"
    PARSEARGS_OPTION_ORDER+=("param:${key}")

    debug "Added parameter '${key}' (${short_name:-n/a}/${long_name:-n/a})"

    # Explicit success: debug returns 1 when DEBUG is unset
    return ${E_SUCCESS:-0}
}

# @description Add a positional argument to the parser
# @usage parseargs-add-positional <name> [--type <type>] [-n|--nargs <+|*|int>]
#          [-d|--default <value>] [-c|--choices <value1,value2,...>]
#          [-F|--follows <separator>] [-r|--required] [-h|--help <text>]
function parseargs-add-positional() {
    local name="${1}"
    local required=true
    local default=""
    local help=""
    local follows=""
    local nargs=1
    local choices=""
    local type="string"
    shift 1

    # Parse options
    while [[ ${#} -gt 0 ]]; do
        case "${1}" in
            -r | --required)
                required=true
                shift 1
                ;;
            -o | --optional)
                required=false
                shift 1
                ;;
            -d | --default)
                default="${2}"
                required=false
                shift 2
                ;;
            -F | --follows)
                follows="${2}"
                shift 2
                ;;
            -n | --nargs)
                nargs="${2}"
                shift 2
                ;;
            -c | --choices)
                choices="${2}"
                shift 2
                ;;
            --type)
                type="${2}"
                shift 2
                ;;
            -h | --help)
                help="${2}"
                shift 2
                ;;
            *)
                debug "Unknown option: ${1}"
                shift 1
                ;;
        esac
    done

    # Store positional argument details
    local position=${#PARSEARGS_POSITIONALS[@]}
    PARSEARGS_POSITIONALS["${position}:name"]="${name}"
    PARSEARGS_POSITIONALS["${position}:required"]="${required}"
    PARSEARGS_POSITIONALS["${position}:default"]="${default}"
    PARSEARGS_POSITIONALS["${position}:help"]="${help}"
    PARSEARGS_POSITIONALS["${position}:follows"]="${follows}"
    PARSEARGS_POSITIONALS["${position}:nargs"]="${nargs}"
    PARSEARGS_POSITIONALS["${position}:choices"]="${choices}"
    PARSEARGS_POSITIONALS["${position}:type"]="${type}"

    debug "Added positional argument '${name}' at position ${position}"

    # Explicit success: debug returns 1 when DEBUG is unset
    return ${E_SUCCESS:-0}
}

# @description Validate a value against a type
# @usage parseargs-validate-type <value> <type>
# @return 0 if valid, non-zero if invalid
function parseargs-validate-type() {
    local value="${1}"
    local type="${2}"

    case "${type}" in
        int)
            [[ "${value}" =~ ^-?[0-9]+$ ]] || return ${E_NOT_A_NUMBER}
            ;;
        float)
            [[ "${value}" =~ ^-?[0-9]+(\.[0-9]+)?$ ]] || return ${E_NOT_A_NUMBER}
            ;;
        bool)
            [[ "${value}" =~ ^(true|false|0|1)$ ]] || return ${E_INVALID_VALUE}
            ;;
        file)
            [[ -f "${value}" ]] || return ${E_NOT_A_FILE}
            ;;
        dir | directory)
            [[ -d "${value}" ]] || return ${E_NOT_A_DIRECTORY}
            ;;
        path)
            [[ -e "${value}" ]] || return ${E_FILE_NOT_FOUND}
            ;;
        *)
            # String or unknown type - always valid
            return 0
            ;;
    esac

    return 0
}

# @description Validate a value against a list of choices
# @usage parseargs-validate-choices <value> <choices>
# @return 0 if valid, non-zero if invalid
function parseargs-validate-choices() {
    local value="${1}"
    local choices="${2}"
    local choice

    # If choices is empty, the value is always valid
    [[ -z "${choices}" ]] && return 0

    # Convert choices to an array
    IFS=',' read -ra choice_array <<<"${choices}"

    # Check if the value is in the array
    for choice in "${choice_array[@]}"; do
        if [[ "${value}" == "${choice}" ]]; then
            return 0
        fi
    done

    return ${E_INVALID_VALUE}
}

# @description Display help message
# @usage parseargs-show-help
function parseargs-show-help() {
    : 'Display help message for the parser

        @usage
            parseargs-show-help [--from-docstring <function_name>]

        @option --from-docstring <function_name>
            Extract help from the specified function docstring

        @stdout
            Formatted help message

        @return 0
            Successfully displayed help

        @return 1
            Error displaying help
    '
    local from_docstring=""

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --from-docstring)
                from_docstring="$2"
                shift 2
                ;;
            *)
                shift
                ;;
        esac
    done

    # Materialize built-ins so they appear in the listing
    parseargs--register-builtins

    local usage="${PARSEARGS_USAGE:-usage: ${PARSEARGS_PROG_NAME} [options]}"
    local help="${PARSEARGS_HELP}"
    local epilog="${PARSEARGS_EPILOG}"

    # If from_docstring is specified, try to extract help using docs.sh
    if [[ -n "${from_docstring}" ]]; then
        # Check if docs-generate-help is available
        if type -t docs-generate-help >/dev/null 2>&1; then
            local docstring_help
            docstring_help=$(docs-generate-help "${from_docstring}" --format plain 2>/dev/null)
            if [[ $? -eq 0 && -n "${docstring_help}" ]]; then
                # Extract parts from the docstring help
                local in_usage=false
                local in_options=false
                local extracted_usage=""
                local extracted_help=""

                while IFS= read -r line; do
                    if [[ "${line}" =~ ^Usage: ]]; then
                        in_usage=true
                        extracted_usage="${line}"
                        continue
                    elif [[ "${line}" =~ ^Options: ]]; then
                        in_usage=false
                        in_options=true
                        continue
                    elif [[ -z "${line}" ]]; then
                        in_usage=false
                        continue
                    elif ! $in_options && ! $in_usage && [[ -n "${line}" ]]; then
                        [[ -n "${extracted_help}" ]] && extracted_help+=$'\n'
                        extracted_help+="${line}"
                    fi
                done <<< "${docstring_help}"

                # Override with extracted values if found
                [[ -n "${extracted_usage}" ]] && usage="${extracted_usage}"
                [[ -n "${extracted_help}" ]] && help="${extracted_help}"
            fi
        fi
    fi

    # Print usage
    echo "${usage}"
    echo

    # Print help text if available
    if [[ -n "${help}" ]]; then
        echo "${help}"
        echo
    fi

    # Print options if any
    local has_options=false
    for key in "${!PARSEARGS_FLAGS[@]}"; do
        if [[ "${key}" == *":short" || "${key}" == *":long" ]]; then
            has_options=true
            break
        fi
    done

    for key in "${!PARSEARGS_PARAMETERS[@]}"; do
        if [[ "${key}" == *":short" || "${key}" == *":long" ]]; then
            has_options=true
            break
        fi
    done

    if ${has_options}; then
        echo "options:"

        # Print options in declaration order
        local entry entry_type base_key short long opt_help subcommand suffix
        for entry in "${PARSEARGS_OPTION_ORDER[@]}"; do
            entry_type="${entry%%:*}"
            base_key="${entry#*:}"

            if [[ "${entry_type}" == "flag" ]]; then
                short="${PARSEARGS_FLAGS["${base_key}:short"]}"
                long="${PARSEARGS_FLAGS["${base_key}:long"]}"
                opt_help="${PARSEARGS_FLAGS["${base_key}:help"]}"
                subcommand="${PARSEARGS_FLAGS["${base_key}:subcommand"]}"
                suffix=""
            else
                short="${PARSEARGS_PARAMETERS["${base_key}:short"]}"
                long="${PARSEARGS_PARAMETERS["${base_key}:long"]}"
                opt_help="${PARSEARGS_PARAMETERS["${base_key}:help"]}"
                subcommand="${PARSEARGS_PARAMETERS["${base_key}:subcommand"]}"
                suffix=" <value>"
            fi

            # Skip if belongs to a subcommand and we're not in that subcommand context
            [[ -n "${subcommand}" && "${subcommand}" != "${PARSEARGS_ACTIVE_SUBCOMMAND}" ]] && continue

            printf "  %-20s  %s\n" "${short:+${short}${long:+/}}${long}${suffix}" "${opt_help}"
        done

        echo
    fi

    # Print positional arguments if any
    local has_positionals=false
    for key in "${!PARSEARGS_POSITIONALS[@]}"; do
        if [[ "${key}" == *":name" ]]; then
            has_positionals=true
            break
        fi
    done

    if ${has_positionals}; then
        echo "positional arguments:"

        # Print positional arguments
        for position in $(seq 0 $((${#PARSEARGS_POSITIONALS[@]} / 8 - 1))); do
            local name="${PARSEARGS_POSITIONALS["${position}:name"]}"
            local help="${PARSEARGS_POSITIONALS["${position}:help"]}"
            local required="${PARSEARGS_POSITIONALS["${position}:required"]}"
            local req_marker=""

            # ${required:+*} would mark even required=false (non-empty string)
            [[ "${required}" == "true" ]] && req_marker="*"
            printf "  %-20s  %s\n" "${name}${req_marker}" "${help}"
        done

        echo
    fi

    # Print subcommands if any
    local has_subcommands=false
    for key in "${!PARSEARGS_SUBCOMMANDS[@]}"; do
        if [[ "${key}" == *":help" ]]; then
            has_subcommands=true
            break
        fi
    done

    if ${has_subcommands}; then
        echo "subcommands:"

        # Print subcommands
        for key in $(printf "%s\n" "${!PARSEARGS_SUBCOMMANDS[@]}" | grep ":help$" | sort); do
            local name="${key%:help}"
            local help="${PARSEARGS_SUBCOMMANDS["${key}"]}"

            printf "  %-20s  %s\n" "${name}" "${help}"
        done

        echo
    fi

    # Print epilog if available
    if [[ -n "${epilog}" ]]; then
        echo "${epilog}"
    fi
}

# @description Materialize the built-in options unless the script claimed
#   their names for itself. Built-ins are "standard-but-unprotected":
#   registered lazily at parse/help time so user definitions naturally win.
# @usage parseargs--register-builtins
function parseargs--register-builtins() {
    [[ "${PARSEARGS_BUILTINS_REGISTERED}" == "true" ]] && return 0
    PARSEARGS_BUILTINS_REGISTERED=true

    if ! parseargs--find-key-by-name "-s" >/dev/null \
        && ! parseargs--find-key-by-name "--silent" >/dev/null; then
        parseargs-add-flag "-s/--silent" --store DO_SILENT \
            --help "suppress all output"
        PARSEARGS_BUILTIN_KEYS+="flag:silent "
    fi

    if ! parseargs--find-key-by-name "-v" >/dev/null \
        && ! parseargs--find-key-by-name "--verbose" >/dev/null; then
        parseargs-add-flag "-v/--verbose" --count --store VERBOSE \
            --help "increase output verbosity"
        PARSEARGS_BUILTIN_KEYS+="flag:verbose "
    fi
}

# @description Activate optional presets that register standard options and
#   parse-time behavior. Explicitly opt-in (never activated by imports).
# @usage parseargs-include <colors|config> [...]
#
#   colors: registers -c/--color <auto|always|never> (store: COLOR). At parse
#           time, resolves DO_COLOR from the mode and stdout's tty-ness, then
#           calls setup-colors/unset-colors.
#   config: registers --config-file <file> (store: CONFIG_FILE, default:
#           ~/.<prog>.conf). At parse time, sources the config file BEFORE
#           applying defaults, so precedence is CLI > config > env > default.
function parseargs-include() {
    local preset
    for preset in "${@}"; do
        case "${preset}" in
            colors)
                declare -F setup-colors &>/dev/null || include-source 'colors.sh'
                parseargs-add-parameter "-c/--color" --store COLOR \
                    --default "auto" --choices "auto,always,never" \
                    --help "when to use color (auto, always, never)" \
                    || return ${?}
                PARSEARGS_INCLUDES+="colors "
                ;;
            config)
                parseargs-add-parameter "--config-file" --store CONFIG_FILE \
                    --help "use the specified configuration file" \
                    || return ${?}
                PARSEARGS_INCLUDES+="config "
                ;;
            *)
                echo "Error: unknown parseargs preset: ${preset}" >&2
                return ${E_INVALID_ARGUMENT:-10}
                ;;
        esac
    done
}

# @description Parse arguments, exiting on help or error. On success, exposes
#   DO_SILENT and VERBOSE as globals and applies silent mode (via shell.sh's
#   silence-output, restored on EXIT).
# @usage parseargs-parse-or-exit "${@}"
function parseargs-parse-or-exit() {
    parseargs-parse "${@}"
    local __rc=${?}

    [[ ${__rc} -eq ${E_HELP_DISPLAYED:-3} ]] && exit 0
    [[ ${__rc} -ne 0 ]] && exit ${__rc}

    # Expose the standard option values as globals
    declare -g DO_SILENT="${PARSEARGS_OPTS[DO_SILENT]:-false}"
    declare -g VERBOSE="${PARSEARGS_OPTS[VERBOSE]:-0}"

    if [[ "${DO_SILENT}" == "true" ]]; then
        declare -F silence-output &>/dev/null || include-source 'shell.sh'
        trap restore-output EXIT
        silence-output
    fi

    return ${E_SUCCESS:-0}
}

# @description Parse command line arguments
# @usage parseargs-parse <arg1> <arg2> ...
function parseargs-parse() {
    # Initialize the parser if not done already. Only initialize when the
    # parser state is genuinely unset: empty arrays are a legitimate state
    # (e.g. only set-help/set-usage were called), and re-initializing would
    # clobber those texts
    if ! declare -p PARSEARGS_FLAGS &>/dev/null; then
        parseargs-init
    fi

    # Reset the parsed arguments
    declare -gA PARSEARGS_OPTS=()
    declare -ga PARSEARGS_POSARGS=()

    # Materialize the built-in options (-s/--silent, -v/--verbose) unless the
    # script claimed those names for itself
    parseargs--register-builtins

    # If the config preset is active, source the config file before applying
    # defaults so its values participate in default resolution
    local __use_env=false
    if [[ "${PARSEARGS_INCLUDES}" == *"config "* ]]; then
        __use_env=true
        local __config_file="${HOME}/.${PARSEARGS_PROG_NAME}.conf"
        local -a __argv=("${@}")
        local __i
        for ((__i = 0; __i < ${#__argv[@]}; __i++)); do
            if [[ "${__argv[__i]}" == "--config-file" ]]; then
                __config_file="${__argv[$((__i + 1))]}"
            fi
        done
        [[ -f "${__config_file}" ]] && source "${__config_file}"
        PARSEARGS_OPTS["CONFIG_FILE"]="${__config_file}"
    fi

    # Set default values for flags. With the config preset active, a variable
    # set in the environment or config file (named by the option's store)
    # beats the registered --default: CLI > config > env > default
    for key in $(printf "%s\n" "${!PARSEARGS_FLAGS[@]}" | grep ":store$"); do
        local base_key="${key%:store}"
        local store="${PARSEARGS_FLAGS["${key}"]}"
        local default="${PARSEARGS_FLAGS["${base_key}:default"]}"

        # Count flags default to 0
        if [[ "${PARSEARGS_FLAGS["${base_key}:count"]}" == "true" && -z "${default}" ]]; then
            default=0
        fi

        if ${__use_env} && [[ -n "${!store+x}" ]]; then
            PARSEARGS_OPTS["${store}"]="${!store}"
        elif [[ -n "${default}" ]]; then
            PARSEARGS_OPTS["${store}"]="${default}"
        fi
    done

    # Set default values for parameters
    for key in $(printf "%s\n" "${!PARSEARGS_PARAMETERS[@]}" | grep ":store$"); do
        local base_key="${key%:store}"
        local store="${PARSEARGS_PARAMETERS["${key}"]}"
        local default="${PARSEARGS_PARAMETERS["${base_key}:default"]}"

        if ${__use_env} && [[ -n "${!store+x}" ]]; then
            PARSEARGS_OPTS["${store}"]="${!store}"
        elif [[ -n "${default}" ]]; then
            PARSEARGS_OPTS["${store}"]="${default}"
        fi
    done

    # Parse position for positional arguments
    local position=0
    local follows_separator=""

    # Check for subcommand as first argument
    if [[ ${#} -gt 0 && ${#PARSEARGS_SUBCOMMANDS[@]} -gt 0 ]]; then
        local first_arg="${1}"
        for key in $(printf "%s\n" "${!PARSEARGS_SUBCOMMANDS[@]}" | grep ":help$"); do
            local name="${key%:help}"
            if [[ "${first_arg}" == "${name}" ]]; then
                PARSEARGS_ACTIVE_SUBCOMMAND="${name}"
                shift 1
                break
            fi
        done
    fi

    # Loop through all arguments
    while [[ ${#} -gt 0 ]]; do
        local arg="${1}"

        # Check if we've encountered a separator and should only process positional args
        if [[ -n "${follows_separator}" ]]; then
            PARSEARGS_POSARGS+=("${arg}")
            shift 1
            continue
        fi

        # Check if this is a separator for positional args
        for key in $(printf "%s\n" "${!PARSEARGS_POSITIONALS[@]}" | grep ":follows$"); do
            local base_key="${key%:follows}"
            local follows="${PARSEARGS_POSITIONALS["${key}"]}"
            if [[ "${arg}" == "${follows}" ]]; then
                follows_separator="${follows}"
                shift 1
                continue 2
            fi
        done

        # Handle --help global flag
        if [[ "${arg}" == "-h" || "${arg}" == "--help" ]]; then
            # Check if PARSEARGS_FROM_FUNCTION is set (for docstring extraction)
            if [[ -n "${PARSEARGS_FROM_FUNCTION}" ]]; then
                parseargs-show-help --from-docstring "${PARSEARGS_FROM_FUNCTION}"
            else
                parseargs-show-help
            fi
            return ${E_HELP_DISPLAYED}
        fi

        # Handle -- separator
        if [[ "${arg}" == "--" ]]; then
            shift 1
            # All remaining arguments are positional
            while [[ ${#} -gt 0 ]]; do
                PARSEARGS_POSARGS+=("${1}")
                shift 1
            done
            continue
        fi

        # Handle flags
        if [[ "${arg}" =~ ^--no-(.*) ]]; then
            # Negative flag (--no-*)
            local flag_name="${BASH_REMATCH[1]}"
            local found=false

            for key in $(printf "%s\n" "${!PARSEARGS_FLAGS[@]}" | grep ":long$"); do
                local base_key="${key%:long}"
                local long="${PARSEARGS_FLAGS["${key}"]}"
                local store="${PARSEARGS_FLAGS["${base_key}:store"]}"
                local subcommand="${PARSEARGS_FLAGS["${base_key}:subcommand"]}"

                # Skip if belongs to a subcommand and we're not in that subcommand context
                [[ -n "${subcommand}" && "${subcommand}" != "${PARSEARGS_ACTIVE_SUBCOMMAND}" ]] && continue

                if [[ "${long}" == "--${flag_name}" ]]; then
                    if [[ "${PARSEARGS_FLAGS["${base_key}:count"]}" == "true" ]]; then
                        PARSEARGS_OPTS["${store}"]=0
                    else
                        PARSEARGS_OPTS["${store}"]="false"
                    fi
                    found=true
                    break
                fi
            done

            if ! ${found}; then
                echo "Error: Unknown flag: ${arg}" >&2
                return ${E_UNKNOWN_OPTION}
            fi

            shift 1
            continue
        elif [[ "${arg}" =~ ^--.* ]]; then
            # Long option (--*)
            local found=false

            # Check if it's a flag
            for key in $(printf "%s\n" "${!PARSEARGS_FLAGS[@]}" | grep ":long$"); do
                local base_key="${key%:long}"
                local long="${PARSEARGS_FLAGS["${key}"]}"
                local store="${PARSEARGS_FLAGS["${base_key}:store"]}"
                local subcommand="${PARSEARGS_FLAGS["${base_key}:subcommand"]}"

                # Skip if belongs to a subcommand and we're not in that subcommand context
                [[ -n "${subcommand}" && "${subcommand}" != "${PARSEARGS_ACTIVE_SUBCOMMAND}" ]] && continue

                if [[ "${arg}" == "${long}" ]]; then
                    if [[ "${PARSEARGS_FLAGS["${base_key}:count"]}" == "true" ]]; then
                        PARSEARGS_OPTS["${store}"]=$(( ${PARSEARGS_OPTS["${store}"]:-0} + 1 ))
                    elif [[ -n "${PARSEARGS_FLAGS["${base_key}:const"]}" ]]; then
                        PARSEARGS_OPTS["${store}"]="${PARSEARGS_FLAGS["${base_key}:const"]}"
                    else
                        PARSEARGS_OPTS["${store}"]="true"
                    fi
                    found=true
                    break
                fi
            done

            if ${found}; then
                shift 1
                continue
            fi

            # Check if it's a parameter
            for key in $(printf "%s\n" "${!PARSEARGS_PARAMETERS[@]}" | grep ":long$"); do
                local base_key="${key%:long}"
                local long="${PARSEARGS_PARAMETERS["${key}"]}"
                local store="${PARSEARGS_PARAMETERS["${base_key}:store"]}"
                local nargs="${PARSEARGS_PARAMETERS["${base_key}:nargs"]}"
                local type="${PARSEARGS_PARAMETERS["${base_key}:type"]}"
                local choices="${PARSEARGS_PARAMETERS["${base_key}:choices"]}"
                local subcommand="${PARSEARGS_PARAMETERS["${base_key}:subcommand"]}"

                # Skip if belongs to a subcommand and we're not in that subcommand context
                [[ -n "${subcommand}" && "${subcommand}" != "${PARSEARGS_ACTIVE_SUBCOMMAND}" ]] && continue

                if [[ "${arg}" == "${long}" ]]; then
                    # Parameter requires a value
                    if [[ -z "${2}" ]]; then
                        echo "Error: Option ${arg} requires an argument" >&2
                        return ${E_MISSING_VALUE}
                    fi

                    local val="${2}"

                    # Validate value against type
                    if ! parseargs-validate-type "${val}" "${type}"; then
                        echo "Error: Invalid value '${val}' for option ${arg}, expected type ${type}" >&2
                        return ${E_INVALID_VALUE}
                    fi

                    # Validate value against choices
                    if ! parseargs-validate-choices "${val}" "${choices}"; then
                        echo "Error: Invalid value '${val}' for option ${arg}, expected one of: ${choices}" >&2
                        return ${E_INVALID_VALUE}
                    fi

                    PARSEARGS_OPTS["${store}"]="${val}"
                    found=true
                    shift 2
                    break
                fi
            done

            if ${found}; then
                continue
            fi

            # Unknown option
            echo "Error: Unknown option: ${arg}" >&2
            return ${E_UNKNOWN_OPTION}
        elif [[ "${arg}" =~ ^-[^-].*$ ]]; then
            # Short option (-*)
            local found=false

            # Check if it's a flag
            for key in $(printf "%s\n" "${!PARSEARGS_FLAGS[@]}" | grep ":short$"); do
                local base_key="${key%:short}"
                local short="${PARSEARGS_FLAGS["${key}"]}"
                local store="${PARSEARGS_FLAGS["${base_key}:store"]}"
                local subcommand="${PARSEARGS_FLAGS["${base_key}:subcommand"]}"

                # Skip if belongs to a subcommand and we're not in that subcommand context
                [[ -n "${subcommand}" && "${subcommand}" != "${PARSEARGS_ACTIVE_SUBCOMMAND}" ]] && continue

                if [[ "${arg}" == "${short}" ]]; then
                    if [[ "${PARSEARGS_FLAGS["${base_key}:count"]}" == "true" ]]; then
                        PARSEARGS_OPTS["${store}"]=$(( ${PARSEARGS_OPTS["${store}"]:-0} + 1 ))
                    elif [[ -n "${PARSEARGS_FLAGS["${base_key}:const"]}" ]]; then
                        PARSEARGS_OPTS["${store}"]="${PARSEARGS_FLAGS["${base_key}:const"]}"
                    else
                        PARSEARGS_OPTS["${store}"]="true"
                    fi
                    found=true
                    break
                fi
            done

            if ${found}; then
                shift 1
                continue
            fi

            # Check if it's a parameter
            for key in $(printf "%s\n" "${!PARSEARGS_PARAMETERS[@]}" | grep ":short$"); do
                local base_key="${key%:short}"
                local short="${PARSEARGS_PARAMETERS["${key}"]}"
                local store="${PARSEARGS_PARAMETERS["${base_key}:store"]}"
                local nargs="${PARSEARGS_PARAMETERS["${base_key}:nargs"]}"
                local type="${PARSEARGS_PARAMETERS["${base_key}:type"]}"
                local choices="${PARSEARGS_PARAMETERS["${base_key}:choices"]}"
                local subcommand="${PARSEARGS_PARAMETERS["${base_key}:subcommand"]}"

                # Skip if belongs to a subcommand and we're not in that subcommand context
                [[ -n "${subcommand}" && "${subcommand}" != "${PARSEARGS_ACTIVE_SUBCOMMAND}" ]] && continue

                if [[ "${arg}" == "${short}" ]]; then
                    # Parameter requires a value
                    if [[ -z "${2}" ]]; then
                        echo "Error: Option ${arg} requires an argument" >&2
                        return ${E_MISSING_VALUE}
                    fi

                    local val="${2}"

                    # Validate value against type
                    if ! parseargs-validate-type "${val}" "${type}"; then
                        echo "Error: Invalid value '${val}' for option ${arg}, expected type ${type}" >&2
                        return ${E_INVALID_VALUE}
                    fi

                    # Validate value against choices
                    if ! parseargs-validate-choices "${val}" "${choices}"; then
                        echo "Error: Invalid value '${val}' for option ${arg}, expected one of: ${choices}" >&2
                        return ${E_INVALID_VALUE}
                    fi

                    PARSEARGS_OPTS["${store}"]="${val}"
                    found=true
                    shift 2
                    break
                fi
            done

            if ${found}; then
                continue
            fi

            # Unknown option
            echo "Error: Unknown option: ${arg}" >&2
            return ${E_UNKNOWN_OPTION}
        else
            # Positional argument
            PARSEARGS_POSARGS+=("${arg}")
            shift 1
        fi
    done

    # Validate required flags
    for key in $(printf "%s\n" "${!PARSEARGS_FLAGS[@]}" | grep ":required$"); do
        local base_key="${key%:required}"
        local required="${PARSEARGS_FLAGS["${key}"]}"
        if [[ "${required}" == "true" ]]; then
            local store="${PARSEARGS_FLAGS["${base_key}:store"]}"
            local long="${PARSEARGS_FLAGS["${base_key}:long"]}"
            local short="${PARSEARGS_FLAGS["${base_key}:short"]}"
            local subcommand="${PARSEARGS_FLAGS["${base_key}:subcommand"]}"

            # Skip if belongs to a subcommand and we're not in that subcommand context
            [[ -n "${subcommand}" && "${subcommand}" != "${PARSEARGS_ACTIVE_SUBCOMMAND}" ]] && continue

            if [[ -z "${PARSEARGS_OPTS["${store}"]}" ]]; then
                echo "Error: Required flag ${long:-${short}} not provided" >&2
                return ${E_MISSING_OPTION}
            fi
        fi
    done

    # Validate required parameters
    for key in $(printf "%s\n" "${!PARSEARGS_PARAMETERS[@]}" | grep ":required$"); do
        local base_key="${key%:required}"
        local required="${PARSEARGS_PARAMETERS["${key}"]}"
        if [[ "${required}" == "true" ]]; then
            local store="${PARSEARGS_PARAMETERS["${base_key}:store"]}"
            local long="${PARSEARGS_PARAMETERS["${base_key}:long"]}"
            local short="${PARSEARGS_PARAMETERS["${base_key}:short"]}"
            local subcommand="${PARSEARGS_PARAMETERS["${base_key}:subcommand"]}"

            # Skip if belongs to a subcommand and we're not in that subcommand context
            [[ -n "${subcommand}" && "${subcommand}" != "${PARSEARGS_ACTIVE_SUBCOMMAND}" ]] && continue

            if [[ -z "${PARSEARGS_OPTS["${store}"]}" ]]; then
                echo "Error: Required parameter ${long:-${short}} not provided" >&2
                return ${E_MISSING_OPTION}
            fi
        fi
    done

    # Validate required positional arguments
    for position in $(seq 0 $((${#PARSEARGS_POSITIONALS[@]} / 8 - 1))); do
        local required="${PARSEARGS_POSITIONALS["${position}:required"]}"
        if [[ "${required}" == "true" ]]; then
            local name="${PARSEARGS_POSITIONALS["${position}:name"]}"

            if [[ ${#PARSEARGS_POSARGS[@]} -le ${position} ]]; then
                echo "Error: Required positional argument '${name}' not provided" >&2
                return ${E_MISSING_ARGUMENT}
            fi
        fi
    done

    # If the colors preset is active, resolve the color mode now, while the
    # script's original fds are still in place (before any silence-output)
    if [[ "${PARSEARGS_INCLUDES}" == *"colors "* ]]; then
        case "${PARSEARGS_OPTS[COLOR]:-auto}" in
            always) declare -g DO_COLOR=true ;;
            never)  declare -g DO_COLOR=false ;;
            *)      [[ -t 1 ]] && declare -g DO_COLOR=true || declare -g DO_COLOR=false ;;
        esac
        ${DO_COLOR} && setup-colors || unset-colors
    fi

    return ${E_SUCCESS}
}

# If this file is being sourced, export the functions
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    export -f parseargs-init
    export -f parseargs-configure-from-docstring
    export -f parseargs-set-prog-name
    export -f parseargs-set-usage
    export -f parseargs-set-epilog
    export -f parseargs-set-help
    export -f parseargs-add-subcommand
    export -f parseargs-parse-flag-names
    export -f parseargs-add-flag
    export -f parseargs-add-parameter
    export -f parseargs-add-positional
    export -f parseargs-validate-type
    export -f parseargs-validate-choices
    export -f parseargs-show-help
    export -f parseargs-parse
    export -f parseargs-parse-or-exit
    export -f parseargs-include
    export -f parseargs--register-builtins
    export -f parseargs--find-key-by-name
    export -f parseargs--drop-option
    export -f parseargs--guard-option-names
fi
