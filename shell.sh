: '
Shell related functions
'

include-source debug

# returns the name of the current shell
function get-shell() {
    basename "$(ps -p "$$" -o args= | awk '{print $1}' | sed 's/^-//')" \
        | tr '[:upper:]' '[:lower:]'
}

# cross-shell function for returning the calling function name
function functionname() {
    # echo "${FUNCNAME[@]@Q}" >&2
    # echo "${BASH_SOURCE[@]@Q}" >&2
    local shell=$(get-shell)
    local index=${1:- -1}
    case $shell in
        bash)
            echo ${FUNCNAME[${index}]}
            ;;
        zsh)
            echo ${funcstack[${index}]}
            ;;
        *)
            echo "unknown shell: $shell" >&2
            return 1
            ;;
    esac
}

# @deprecated
# Checks if an item is in an array.
# usage: in-array <item> "${array[@]}"
# returns 0 if the item is in the array, 1 otherwise
function in-array() {
    local item=${1}
    shift

    local arg
    local subarg
    for arg in "${@}"; do
        for subarg in ${arg}; do
            if [ "${subarg}" == "${item}" ]; then
                return 0
            fi
        done
    done
    return 1
}

# Check if an item is in any of the given arguments or arrays
# usage: is-in <item> <arg1> <arg2> ... <argN>
# returns 0 if the item is in any of the arguments or arrays, 1 otherwise
function is-in() {
    local item="${1}"
    shift
    local arg
    for arg in "${@}"; do
        if [ "${#arg[@]}" -gt 0 ]; then
            for subarg in "${arg[@]}"; do
                if [ "${subarg}" = "${item}" ]; then
                    return 0
                fi
            done
        else
            if [ "${arg}" = "${item}" ]; then
                return 0
            fi
        fi
    done
    return 1
}

# Get the index of an item in an array.
# usage: index-of <item> "${array[@]}"
# echoes the index of the item in the array. returns 0 if found, 1 otherwise
function index-of() {
    local item=${1}
    shift
    local array=("${@}")

    local e
    local index=0
    local found=false
    for e in "${!array[@]}"; do
        if [[ "${array[$e]}" == "${item}" ]]; then
            found=true
            break
        fi
        index=$((index + 1))
    done

    echo ${index}
    ${found} && return 0 || return 1
}

# runs a command and stores stderr and stdout in specified variables
# usage: catch stdout_var stderr_var command [args...]
function catch() {
    eval "$({
    __2="$(
        { __1="$("${@:3}")"; } 2>&1;
        ret=$?;
        printf '%q=%q\n' "$1" "$__1" >&2;
        exit $ret
    )";
    ret="$?";
    printf '%s=%q\n' "$2" "$__2" >&2;
    printf '( exit %q )' "$ret" >&2;
    } 2>&1 )";
}

# finds all functions in the given file(s). If "-" is passed as a filename, read
# from stdin.
function grep-functions() {
    # loop through all of the passed in arguments
    for filepath in "${@}"; do
        # get the contents of the file
        local contents
        if [ "${filepath}" = "-" ]; then
            contents=$(cat)
        else
            contents=$(cat "${filepath}")
        fi

        echo "${contents}" \
            | grep -Pazo '(?s)[a-zA-Z0-9_\-]+\s*(\(\s*\))?\s*{' \
            | tr '\0' '\n' \
            | grep --color=never -Eo '[a-zA-Z0-9_\-]+'
    done
}

# v1.0.0
# find all the functions in the given file(s) and echo their source to stdout.
# If "-" is passed as a filename, read from stdin.
# TODO: use regex to extract the function source without sourcing the file
function extract-functions() {
    # loop through all of the passed in arguments
    for filepath in "${@}"; do
        # get all of the functions in the file
        local functions=$(grep-functions "${filepath}")

        # source the file in a subshell and then use `type` to get the source
        # of each function
        ( source "${filepath}" >/dev/null 2>&1 && for function in ${functions}; do
            echo "function ${function}() {"
            type ${function} | sed '1,3d;$d'
            echo "}"
        done )
    done
}

# Search for a function body in the specified file(s). If "-" is passed as a
# filename, read from stdin.
function find-function() {
    # get the function name
    local function_name="${1}"
    shift

    # loop through all of the passed in arguments
    for filepath in "${@}"; do
        # get the contents of the file
        local contents
        if [ "${filepath}" = "-" ]; then
            contents=$(cat)
        else
            contents=$(cat "${filepath}")
        fi

        # use awk to find the function body from the first to the closing brace.
        # keep track of how many braces we've seen. every time we see an opening
        # brace, increment the count. every time we see a closing brace, decrement
        # the count. if the count is 0, once the count is at 0, print the
        # function body.
        # TODO: handle case where there are extra closing braces on the last
        #       line
        function_pattern="^(function)?\s*${function_name}\s*(\(\s*\))?\s*{"
        echo "${contents}" | tr '\n' '\0' | awk \
            -v fname="${function_name}" \
            -v fbody="" \
            -v brace_count=0 \
            -v in_function=0 \
            '{
                if ($0 ~ fname) {
                    in_function = 1
                }
                if (brace_count == 0) {
                    fbody = ""
                }
                if ($0 ~ "{") {
                    brace_count += gsub("{", "");
                }
                if ($0 == "}") {
                    brace_count -= gsub("}", "");
                }
                if (brace_count == 0) {
                    fbody = fbody $0 "\n"
                }
                if (brace_count == 0 && $0 ~ /^function\s+'"${function_name}"'/) {
                    print fbody
                }
            }'
    done
}

# Search for a file in the PATH or optionally specified PATH style variable
# and return the full path to the file.
function search-path() {
    local filepath="${1}"
    local path="${2:-${PATH}}"
    local found_path

    # loop through all of the paths in the PATH variable
    while IFS=':' read -d: -r pathdir || [ -n "${pathdir}" ]; do
        # if the file exists in the path, set the found_path variable and break
        # out of the loop
        if [ -f "${pathdir}/${filepath}" ]; then
            found_path="${pathdir}/${filepath}"
            break
        fi
    done <<< "${path}"

    # if we found the file, echo the full path to the file
    if [ -n "${found_path}" ]; then
        echo "${found_path}"
        return 0
    fi

    # if we didn't find the file, return 1
    return 1
}

# Search for and attempt to return the original path to a command in the PATH
# rather than an alias, function, or wrapper script.
function which-original() {
    local command="${1}"
    local executables=()
    local mimetype
    local mimetypes=()

    # use `which` to get the paths to all executables matching the command name
    executables=($(which -a "${command}"))

    # if no executables were found, return 1
    if [ ${#executables[@]} -eq 0 ]; then
        return 1
    fi

    # loop through all of the executables and collect their mime types
    for executable in "${executables[@]}"; do
        mimetype=$(file --mime-type -b "${executable}" 2>/dev/null)
        mimetypes+=("${mimetype}")
    done

    # determine if any of the executables is an application
    local i=0
    for mimetype in "${mimetypes[@]}"; do
        if [ "${mimetype}" = "application/x-executable" ]; then
            echo "${executables[${i}]}"
            return 0
        fi
        let i++
    done

    # if none of the executables is an application, check to see if any of the
    # executables is installed in a system directory
    for executable in "${executables[@]}"; do
        local directory=$(dirname "${executable}")
        # use a case statement to check if the directory is a system directory
        case "${directory}" in
            /bin|/sbin|/usr/bin|/usr/sbin|/usr/local/bin|/usr/local/sbin)
                echo "${executable}"
                return 0
                ;;
        esac
    done

    return 1
}

# Return the first non-empty string from the given arguments.
function first-value() {
    for arg in "${@}"; do
        if [ -n "${arg}" ]; then
            echo "${arg}"
            return 0
        fi
    done
    return 1
}

# Returns 0 if the given argument is in the specified path, 1 otherwise.
function dir-in-path() {
    local dir="${1}"
    local path="${2:-${PATH}}"

    [[ ":${PATH}:" == *":${dir}:"* ]]
}

# Add the given arguments to the PATH environment variable if they are not
# already in the PATH
function add-paths() {
    local usage="usage: $(functionname) [-h|--help] [-P|--path-var PATH_VARIABLE] [-a|--append] [-p|--prepend]"

    # default values
    local path_name="PATH"
    local do_append=0
    local paths=()

    while [[ ${#} -gt 0 ]]; do
        local arg="$1"
        case "$arg" in
            -h|--help)
                echo ${usage}
                return 0
                ;;
            -P|--path-var)
                path_name="$2"
                shift
                ;;
            -a|--append)
                do_append=1
                shift
                ;;
            -p|--prepend)
                do_append=0
                shift
                ;;
            -*)
                echo "include-source: invalid option '$arg'" >&2
                exit 1
                ;;
            *)
                paths+=("$arg")
                shift
                ;;
        esac
    done

    # if no paths were specified, return 1
    if [ ${#paths[@]} -eq 0 ]; then
        echo "${usage}" >&2
        return 1
    fi

    # Get the current value of the specified PATH variable.
    local path_value=${!path_name}

    # loop through all of the paths and add them to the PATH if they are not
    # already in the PATH
    for path in "${paths[@]}"; do
        if ! dir-in-path "${path}" "${path_value}"; then
            if [ ${do_append} -eq 1 ]; then
                path_value="${path_value}:${path}"
            else
                path_value="${path}:${path_value}"
            fi
        fi
    done

    # Store the updated path_value in the specified PATH variable.
    export "${path_name}"="${path_value}"
}

# @description: Sorts the given array or list of arguments
# @positional+: an unsorted list of strings
# @returns: the input array, sorted
function sort-array() {
    local array=("${@}")
    local sorted_array=()

    if [ -z "${array[*]}" ]; then
        return 1
    fi

    # sort the array
    sorted_array=($(printf '%s\0' "${array[@]}" | sort -z | xargs -0))

    # print the sorted array
    printf '%s' "${sorted_array[@]}"
}

# @description: Determines if the current shell is interactive
# @usage: is-interactive
# @example: is-interactive && echo "interactive" || echo "not interactive"
# @returns: 0 if the shell is interactive
# @returns: 1 if the shell is attached to a pipe
# @returns: 2 if the shell is attached to a redirection
function is-interactive() {
    # STDOUT is attached to a tty
    [[ -t 1 ]] && return 0

    # STDOUT is attached to a pipe
    [[ -p /dev/stdout ]] && return 1

    # STDOUT is attached to a redirection
    [[ ! -t 1 && ! -p /dev/stdout ]] && return 2
}

# @description: Loop over each argument or multiline string with a given command
# @usage: for-each <command> [--log <filepath>] [--quiet] -- <args...>
# @example: for-each echo -- a b c $'hello\nworld'
# @example: for-each echo --log /tmp/log.txt -- a b c $'hello\nworld'
# @returns: 0 if the command succeeds for all arguments
# @returns: 1 if the command fails for any argument
# @returns: 2 if the command fails for all arguments
# @returns: 3 if the command is not found
function for-each() {
    local any_success=0
    local any_failure=0
    local quiet=0
    local cmd=()
    local args=()
    local log_filepath=""

    # parse the command and arguments
    while [[ ${#} -gt 0 ]]; do
        case "${1}" in
            --log)
                log_filepath="${2}"
                shift 1
                ;;
            --quiet)
                quiet=1
                ;;
            --)
                shift
                args=("${@}")
                break
                ;;
            *)
                cmd+=("${1}")
                ;;
        esac
        shift
    done

    # check if command is found
    if ! type "${cmd[0]}" 2>&1 1>/dev/null; then
        echo "for-each: command not found: ${cmd[0]}" >&2
        return 3
    fi

    # determine whether to print the arguments or read them from STDIN
    if [[ ${#args[@]} -gt 0 ]]; then
        print_args=("printf" "%s\n" "${args[@]}")
    else
        print_args=("cat" "-")
    fi

    # loop over each argument
    local exit_code
    local output
    "${print_args[@]}" | while read -r arg; do
        # run the command
        output=$("${cmd[@]}" "${arg}" 2>&1)
        exit_code=${?}

        # log the output
        if [ -n "${log_filepath}" ]; then
            echo "${output}" >> "${log_filepath}"
        fi

        # print the output
        if [ ${quiet} -eq 0 ]; then
            echo "${output}"
        fi

        # check the exit code
        if [ ${exit_code} -eq 0 ]; then
            any_success=1
        else
            any_failure=1
        fi
    done

    # return the appropriate exit code
    if [ ${any_success} -eq 1 ] && [ ${any_failure} -eq 0 ]; then
        return 0
    elif [ ${any_success} -eq 0 ] && [ ${any_failure} -eq 1 ]; then
        return 1
    else
        return 2
    fi
}

# @description
#   Check for dependencies and exit if any are not met.
#
#   Output:
#   --quiet: if this option is specified, all output will be suppressed.
#
#   --success-message <message>: if this option is specified, the specified
#   message will be printed if all dependencies are met.
#
#   --failure-message <message>: if this option is specified, the specified
#   message will be printed if any dependencies are not met. if the requirements
#   generated any other output, this option will suppress those messages unless
#   the `--verbose` option is specified
#
#   --verbose: if this option is specified, the `--failure-message` will not
#   suppress any output generated by the requirements.
#
#
#   Commands:
#   --optional: if the specified command is not found, a warning will be
#   printed, but the script will continue.
#
#   --one-of: this option allows you to specify a set of commands where only
#   one of them is required. The first command in the set that is found will be
#   set to the variable name specified in the --one-of option. e.g.:
#       require --one-of downloader="curl wget"
#       echo "${downloader}"
#   If curl is found, `downloader` will be set to curl. If curl is not found,
#   but wget is, downloader will be set to wget. If neither curl nor wget is
#   found, the script will exit.
#
#
#   Exit code:
#   --exit-success <eval>: run `<eval>` and exit if its exit code is not 0.
#
#   --exit-failure <eval>: run `<eval>` and exit if its exit code is 0.
#
#
#   Variables/values:
#   --value <value1>="<value2>": if `value1` is not equal to `value2`, the
#   script will exit.
#
#   --variable-value <varname>="<value>": if the variable `varname` is not equal
#   to `value`, the script will exit.
#
#   --is-set <varname>: if the variable `varname` is not set, the script will
#   exit.
#
#   --is-empty <varname>: if the variable `varname` is not empty, the script
#   will exit.
#
#
#  Access:
#  --root: if this option is specified, the script will exit if it is not run as
#  root.
#
#  --uid <uid>: if this option is specified, the script will exit if it is not
#  run as the specified user.
#
#  --user <username>: if this option is specified, the script will exit if it is
#  not run as the specified user.
#
#  --gid <gid>: if this option is specified, the script will exit if it is not
#  run as the specified group.
#
#  --group <groupname>: if this option is specified, the script will exit if it
#  is not run as the specified group.
#
#  --read <filepath>: if this option is specified, the script will exit if it
#  does not have read permissions for the specified file or directory.
#
#  --write <filepath>: if this option is specified, the script will exit if it
#  does not have write permissions for the specified file or directory.
#
#
#  Misc:
#  --os <os>: if this option is specified, the script will exit if it is not
#  run on the specified OS. The value of this option should be the value of the
#  ID field in /etc/os-release.
#
# @usage: require [-r|--root] [-o|--optional <dep>] [-O|--one-of <name>="<dep1> <dep2> <dep3>"] <dep1> <dep2> <dep3>
# @example:
#   require --root --one-of downloader="curl wget" tar
#   case "${downloader}" in
#       curl)
#           curl -sSL https://example.com | tar -xzf -
#           ;;
#       wget)
#           wget -qO- https://example.com | tar -xzf -
#           ;;
#   esac
function require() {
    # Default values
    local success_message=""
    local failure_message=""
    local exit_success_eval=""
    local exit_failure_eval=""
    local required_user=""
    local required_uid=""
    local required_group=""
    local required_gid=""
    local required_os=""
    local optional_dependencies=()
    local required_dependencies=()
    local should_exit=false
    local error_messages=()
    local warning_messages=()
    local exit_code=0
    local set_variables=()
    local empty_variables=()
    local read_filepaths=()
    local write_filepaths=()
    local do_quiet=false
    local do_exit_on_failure=true
    local do_verbose=false
    declare -A values # format: ['value1'="val1" 'value2'="val2"...]
    declare -A variable_values # format: ['varname'="value'...]
    declare -A one_of # format: ['download'="curl wget" 'extract'="unzip tar"...]

    # Loop over the arguments
    while [[ ${#} -gt 0 ]]; do
        case ${1} in
            --success-message)
                success_message="${2}"
                shift 2
                ;;
            --failure-message)
                failure_message="${2}"
                shift 2
                ;;
            --verbose)
                do_verbose=true
                do_quiet=false
                shift 1
                ;;
            --exit-success)
                exit_success_eval="${2}"
                shift 2
                ;;
            --exit-failure)
                exit_failure_eval="${2}"
                shift 2
                ;;
            -o | --optional)
                optional_dependencies+=("${2}")
                shift 2
                ;;
            -O | --one-of)
                # syntax: --one-of name="dep1 dep2 dep3"
                if ! [[ "${2}" =~ = ]]; then
                    echo "error: --one-of requires an argument in the format: name=\"dep1 dep2 dep3\"" >&2
                    exit 1
                fi
                local name="${2%%=*}"
                local deps="${2#*=}"
                one_of["${name}"]="${deps}"
                shift 2
                ;;
            -R | --os)
                required_os="${2}"
                shift 2
                ;;
            --root)
                required_user="root"
                shift 1
                ;;
            -u | --user)
                required_user="${2}"
                shift 2
                ;;
            -U | --uid)
                required_uid="${2}"
                shift 2
                ;;
            -g | --group)
                required_group="${2}"
                shift 2
                ;;
            -G | --gid)
                required_gid="${2}"
                shift 2
                ;;
            -r | --read)
                read_filepaths+=("${2}")
                shift 2
                ;;
            -w | --write)
                write_filepaths+=("${2}")
                shift 2
                ;;
            -n | --is-set)
                set_variables+=("${2}")
                shift 2
                ;;
            -z | --is-empty)
                empty_variables+=("${2}")
                shift 2
                ;;
            -v | --value)
                # syntax: --value name="value"
                if ! [[ "${2}" =~ = ]]; then
                    echo "error: --value requires an argument in the format: name=\"value\"" >&2
                    exit 1
                fi
                local value1="${2%%=*}"
                local value2="${2#*=}"
                values["${value1}"]="${value2}"
                shift 2
                ;;
            -V | --variable-value)
                # syntax: --variable-value varname="value"
                if ! [[ "${2}" =~ = ]]; then
                    echo "error: --variable-value requires an argument in the format: varname=\"value\"" >&2
                    exit 1
                fi
                local varname="${2%%=*}"
                local value="${2#*=}"
                variable_values["${varname}"]="${value}"
                shift 2
                ;;
            -q | --quiet)
                do_quiet=true
                shift 1
                ;;
            --no-exit)
                do_exit_on_failure=false
                shift 1
                ;;
            *)
                required_dependencies+=("${1}")
                shift 1
                ;;
        esac
    done

    ## Setup

    # If quiet mode is enabled, then redirect all output to /dev/null and setup
    # a trap to restore the output when the function exits
    if ${do_quiet}; then
        function __restore_output() {
            exec 1>&9 2>&8 9>&- 8>&-
        }
        exec 9>&1 8>&2 1>/dev/null 2>&1
        trap __restore_output RETURN
    fi


    ## Run dependency checks

    # Evaluate any supplied commands
    if [[ -n "${exit_success_eval}" ]]; then
        eval "${exit_success_eval}"
        if [[ ${?} -ne 0 ]]; then
            error_messages+=("eval did not exit with a success code")
            exit_code=1
        fi
    fi

    if [[ -n "${exit_failure_eval}" ]]; then
        eval "${exit_failure_eval}"
        if [[ ${?} -eq 0 ]]; then
            error_messages+=("eval did not exit with a failure code")
            exit_code=1
        fi
    fi

    # Check the OS
    if [[ -n "${required_os}" ]]; then
        local current_os=$(grep -Po '(?<=^ID=).+' /etc/os-release)
        if [[ "${current_os}" != "${required_os}" ]]; then
            error_messages+=("must be run on ${required_os}")
            exit_code=1
        fi
    fi

    # Check for uid/user
    if [[ -n "${required_uid}" ]]; then
        # set the required user to the user name
        required_user="$(id -u "${required_uid}" -n 2>&1)"
        if [[ ${?} != 0 ]]; then
            error_messages+=("user with uid ${required_uid} does not exist")
            required_user=""
            exit_code=1
        fi
    fi
    if [[ -n "${required_user}" ]]; then
        if [[ "${required_user}" != "$(id -un)" ]]; then
            error_messages+=("must be run as ${required_user}")
            exit_code=1
        fi
    fi

    # Check for gid/group
    if [[ -n "${required_gid}" ]]; then
        # set the required group to the group name
        required_group="$(getent group "${required_gid}" | cut -d: -f1)"
    fi
    if [[ -n "${required_group}" ]]; then
        if ! getent group "${required_group}" | grep -qE ":${USER}$"; then
            error_messages+=("user must be in group '${required_group}'")
            exit_code=1
        fi
    fi

    # Check for read permissions
    for filepath in "${read_filepaths[@]}"; do
        if [[ ! -r "${filepath}" ]]; then
            error_messages+=("must have read permissions for '${filepath}'")
            exit_code=1
        fi
    done

    # Check for write permissions
    for filepath in "${write_filepaths[@]}"; do
        local check_filepath=true
        # If the filepath does not exist, then check if its parent directory is
        # writable
        if [[ ! -e "${filepath}" ]]; then
            local parent_dir
            parent_dir="$(dirname "${filepath}")"

            # If the parent directory also doesn't exist, then exit with an
            # error
            if [[ ! -e "${parent_dir}" ]]; then
                error_messages+=("must have write permissions for '${filepath}', but parent directory '${parent_dir}' does not exist")
                exit_code=1
                check_filepath=false
            else
                filepath="${parent_dir}"
            fi
        fi
        if ${check_filepath} && [[ ! -w "${filepath}" ]]; then
            error_messages+=("must have write permissions for '${filepath}'")
            exit_code=1
        fi
    done

    # Check for set variables
    for var in "${set_variables[@]}"; do
        if [[ -z "${!var}" ]]; then
            error_messages+=("variable '${var}' must be set")
            exit_code=1
        fi
    done

    # Check for empty variables
    for var in "${empty_variables[@]}"; do
        if [[ -n "${!var}" ]]; then
            error_messages+=("variable '${var}' must be empty")
            exit_code=1
        fi
    done

    # Check values
    for key in "${!values[@]}"; do
        if [[ "${key}" != "${values["${key}"]}" ]]; then
            error_messages+=("value '${key}' is not '${values["${key}"]}'")
            exit_code=1
        fi
    done

    # Check variable values
    for var in "${!variable_values[@]}"; do
        if [[ "${!var}" != "${variable_values["${var}"]}" ]]; then
            error_messages+=("variable '${var}' is set to '${!var}', not '${variable_values["${var}"]}'")
            exit_code=1
        fi
    done

    # Check for required dependencies
    for dep in "${required_dependencies[@]}"; do
        if ! command -v "${dep}" &> /dev/null; then
            error_messages+=("missing required command: '${dep}'")
            exit_code=1
        fi
    done

    # Check for optional dependencies
    for dep in "${optional_dependencies[@]}"; do
        if ! command -v "${dep}" &> /dev/null; then
            warning_messages+=("missing optional command: '${dep}'")
        fi
    done

    # Check for one of a set of dependencies
    for name in "${!one_of[@]}"; do
        local found=false
        local found_dep
        for dep in ${one_of["${name}"]}; do
            if command -v "${dep}" &> /dev/null; then
                found=true
                found_dep="${dep}"
                break
            fi
        done
        if ! ${found}; then
            error_messages+=("missing '${name}': ${one_of["${name}"]}")
            exit_code=1
        else
            # Set the variable to the found dependencies
            read -r "${name}" <<< "${found_dep}"
        fi
    done


    ## Output the results

    # First, check to see if we need to suppress the output
    local suppress_output=false
    if [[
        (-n "${failure_message}" && "${do_verbose}" == "false") ||
        "${do_quiet}" == "true"
    ]]; then
        suppress_output=true
    fi

    # Print any warning messages
    if ! ${suppress_output}; then
        for msg in "${warning_messages[@]}"; do
            echo "warning: ${msg}" >&2
        done

        # Print any error messages
        if [[ ${exit_code} -ne 0 ]]; then
            for msg in "${error_messages[@]}"; do
                echo "error: ${msg}" >&2
            done
        fi
    fi

    # If there were explicit success and failure messages, then print them
    if [[ ${exit_code} -eq 0 ]] && [[ -n "${success_message}" ]]; then
        echo "${success_message}"
    elif [[ ${exit_code} -ne 0 ]] && [[ -n "${failure_message}" ]]; then
        echo "${failure_message}" >&2
    fi

    # If this function is being called from an interactive shell, then
    # exit on failure, else return
    if ${do_exit_on_failure} && [[ ! "${-}" =~ i && "${exit_code}" -ne 0 ]]; then
        if ! ${suppress_output}; then
            echo "exiting due to unmet dependencies" >&2
        fi
        exit "${exit_code}"
    fi
    return "${exit_code}"
}

# @description Run benchmarks on a command
# @usage benchmark --iterations <num> command [args...]
function benchmark() {
    local iterations=1
    local do_silent=false
    local do_progress=true
    local do_show_output=false
    local cmd=()

    # determine these after processing the args
    local progress_as_header=false
    local progress_as_inplace=false

    # Parse the command and arguments
    while [[ ${#} -gt 0 ]]; do
        case "${1}" in
            --iterations)
                iterations="${2}"
                shift 2
                ;;
            --silent)
                do_silent=true
                shift 1
                ;;
            --progress)
                do_progress=true
                shift 1
                ;;
            --no-progress)
                do_progress=false
                shift 1
                ;;
            --show-output)
                do_show_output=true
                shift 1
                ;;
            --no-show-output)
                do_show_output=false
                shift 1
                ;;
            --)
                shift 1
                cmd+=("${@}")
                break
                ;;
            *)
                cmd+=("${1}")
                shift 1
                ;;
        esac
    done

    # If showing progress *and* output, then show a header above each iteration
    if ${do_progress}; then
        if ${do_show_output}; then
            progress_as_header=true
        else
            progress_as_inplace=true
        fi
    fi

    if ${do_silent}; then
        exec 9>/dev/null 8>/dev/null
    else
        exec 9>&1 8>&2
    fi

    if ${do_show_output}; then
        exec 3>&1 4>&2
    else
        exec 3>/dev/null 4>/dev/null
    fi

    debug-vars do_silent iterations cmd

    # Run the command the specified number of times
    time (
        for ((i = 0; i < iterations; i++)); do
            # # Print the progress header
            # if ${progress_as_header}; then
            #     echo -e "\033[1miteration\033[0m ${i}"
            # elif ${progress_as_inplace}; then
            #     printf '\r[%d/%d] ' "${i}" "${iterations}"
            # fi
            "${cmd[@]}"
        done 1>&9 2>&8
    )

    # Restore the output
    exec 9>&- 8>&- 3>&- 4>&-
}

# @description Print a function definition, optionally renaming it
# @usage print-function <function name> [<new name>]
function print-function() {
    local f_name="${1}"
    local f_name_new="${2:-${f_name}}"
    local f_declare

    # Ensure a function was given
    [[ -z "${f_name}" ]] && return

    # Get the function declaration and exit with an error if it doesn't exist
    f_declare=$(declare -f "${f_name}" 2>/dev/null)
    if [[ -z "${f_declare}" ]]; then
        echo "error: no such function '${f_name}'" >&2
        return 1
    fi

    # Print the function source, optionally renaming the function
    awk -v name="${f_name_new}" '
        NR == 1 { printf("function %s() {\n", name) }
        NR > 2
    ' <<< "${f_declare}"
}

# @description Split a quoted string into an array (xargs quoting applies)
# @usage split-quoted <quoted string> [<array name>]
# @example
#     $ split-quoted "one two 'three four' five" NUMBER_ARRAY
#     $ declare -p NUMBER_ARRAY
#     declare -a NUMBER_ARRAY=([0]="one" [1]="two" [2]="three four" [3]="five")
function split-quoted() {
    local quoted="${1}"
    local varname="${2:-SPLIT_ARRAY}"
    local lines
    local err_msg exit_code=0

    # Link the local `arr` to the specified variable name
    declare -n arr="${varname}"

    # Split the quoted string into lines
    if lines=$(xargs -n1 printf '%s\n' <<< "${quoted}" 2>&1); then
        # Read the lines into the array
        readarray -t arr <<< "${lines}"

        # Print the array
        printf '%s\n' "${arr[@]}"
    else
        exit_code=1
        # Look for the error
        err_msg=$(grep '^xargs: .*' <<< "${lines}")
        err_msg="${err_msg#xargs: }"
        err_msg="${err_msg%%;*}"
        echo "error: ${err_msg}" >&2
    fi

    # Unlink the local `arr`
    unset -n arr

    return ${exit_code}
}

function search-back() {
    :  'Search for a file or directory traversing parent directories

        This function searches for a file or directory by traversing parent
        directories until (a) it finds the file or directory or (b) it reaches
        the root directory.

        @usage
            [-d/--directory] [-f/--file] [-h/--help] [-m/--max-depth <num>]
            [-v/--verbose] <name>

        @option -h/--help
            Print this help message and exit.

        @option -d/--directory
            Search for a directory.

        @option -f/--file
            Search for a file.

        @option -m/--max-depth <num>
            The maximum number of directories to search before giving up.

        @option -v/--verbose
            Print the directories being searched.

        @arg name
            The name of the file or directory to search for.

        @stdout
            The full path to the file or directory if found.

        @return 0
            If the file or directory is found.

        @return 1
            If the file or directory is not found.
    '
    # Default values
    local do_verbose=false
    local do_directory=false
    local do_file=false
    local max_depth=-1 # -1 means no limit
    local name

    # Parse the options
    while [[ ${#} -gt 0 ]]; do
        case "${1}" in
            -h | --help)
                echo "${FUNCNAME[0]}: ${1}"
                grep -E '^\s+\#\s+' "${BASH_SOURCE[0]}" | sed 's/^\s\+#\s\+//'
                return 0
                ;;
            -d | --directory)
                do_directory=true
                do_file=false
                shift
                ;;
            -f | --file)
                do_file=true
                do_directory=false
                shift
                ;;
            -m | --max-depth)
                max_depth="${2}"
                shift 2
                ;;
            -v | --verbose)
                do_verbose=true
                shift
                ;;
            --)
                shift
                name="${@}"
                break
                ;;
            *)
                name="${1}"
                shift
                ;;
        esac
    done

    # Ensure a name was given
    [[ -z "${name}" ]] && return 1

    # Disallow "." and ".."
    if [[ "${name}" =~ ^(.*/)?\.\.?(/.*)?$ ]]; then
        echo "error: path cannot include './' or '../'" >&2
        return 1
    fi

    # If no file or directory option was given, search for both
    if ! ${do_directory} && ! ${do_file}; then
        do_directory=true
        do_file=true
    fi

    debug-vars do_verbose do_directory do_file max_depth name

    # Set up a trap to restore the current directory on function return
    local _search_back_pwd="${PWD}"
    restore_search_back_pwd() {
        cd "${_search_back_pwd}"
    }
    trap restore_search_back_pwd RETURN

    # Traverse the parent directories
    local depth=0
    local match=""
    while [[ -z "${match}"  ]]; do
        # Print the current directory if verbose mode is enabled
        if ${do_verbose}; then
            echo "${PWD}"
        fi

        # Search for the file or directory
        if ${do_directory} && [[ -d "${name}" ]]; then
            match="${PWD%/}/${name}"
        elif ${do_file} && [[ -f "${name}" ]]; then
            match="${PWD%/}/${name}"
        fi

        # Check if the maximum depth has been reached
        if [[ ${max_depth} -gt 0 ]] && [[ ${depth} -ge ${max_depth} ]]; then
            break
        fi

        # If we've just chceked the root directory, break out of the loop
        if [[ "${PWD}" == "/" ]]; then
            break
        fi

        # Move up a directory
        cd ..
        ((depth++))
    done

    # Return the result
    if [[ -n "${match}" ]]; then
        echo "${match}"
        return 0
    fi
    return 1
}

function read-chars() {
    :  'Read individual characters from stdin

        Read individual characters from stdin and set a variable to the value of
        each character. By default, the variable is set to REPLY. Intended to be
        used in a while loop, e.g.:

            while read-chars foo; do something --with $foo; done

        @usage
            [-n <int>] [<var>]

        @optarg -n <int>
            Read <int> characters at a time. Defaults to 1.

        @optarg <var>
            Set <var> to the value of each character. Defaults to REPLY.
    '
    # Default values
    local varname="REPLY"
    local count=1
    local chars=()
    local char

    # Parse the values
    while [[ ${#} -gt 0 ]]; do
        case "${1}" in
            -c | --count)
                count="${2}"
                shift 2
                ;;
            --)
                shift
                varname="${1}"
                break
                ;;
            *)
                varname="${1}"
                shift
                ;;
        esac
    done

    # Validate the count
    if ! [[ "${count}" =~ ^[0-9]+$ ]]; then
        echo "error: invalid count: ${count}" >&2
        return 1
    fi

    # Set up the variable
    declare -n var="${varname}"

    # The magic sauce, taken from StackExchange:
    # https://unix.stackexchange.com/a/49585
    #
    #     while IFS= read -rn1 a; do printf %s "${a:-$'\n'}"; done
    #
    # But since we only want to use this in a while loop, we will NOT use a
    # while loop here. Instead, we will simply use `read` to obtain a single
    # character at a time. We will still use a `for` loop to repeat this process
    # <count> times. Since this is intended to be used in a while loop, we will
    # instead simply set the variable to the characters read and then return a 0
    # or 1 depending on whether any characters were read to indicate whether the
    # loop should continue.
    for ((i = 0; i < count; i++)); do
        if IFS= read -rn1 char; then
            chars+=("${char:-$'\n'}")
        elif [[ ${#chars[@]} -eq 0 ]]; then
            # We reached the end of stdin before reading any characters. Will
            # set the variable to nothing and return 1 to break out of the loop.
            var=""
            return 1
        fi
    done

    # Set the variable to the characters read
    IFS='' var="${chars[*]}"
}

function prompt-continue() {
    :  'Prompt the user to continue

        Prompt the user to continue and check their input against a pattern.
        Exit or return based on user input and specified options.

        @usage
            [-y/--yes-pattern <regex>] [-e/--exit] [--exit-msg <msg>] [<prompt>]

        @optarg -y/--yes-pattern <regex>
            Use <regex> to determine if the user input is a "yes". Defaults to
            "^[Yy](es)?$".

        @optarg -e/--exit
            If specified, will `exit` rather than `return`.

        @optarg --exit-msg <msg>
            A message to print before exiting. Defaults to "".

        @optarg <prompt>
            Display <prompt> before the input is received. Defaults to "Type
            \"yes\" to continue:".
    '

    # Default values
    local yes_pattern="[Yy](es)?"
    local prompt="Type \"yes\" to continue:"
    local do_exit=false
    local exit_msg=""

    # Parse the values
    while [[ ${#} -gt 0 ]]; do
        case "${1}" in
            -y | --yes-pattern)
                yes_pattern="${2}"
                shift 2
                ;;
            -e | --exit)
                do_exit=true
                shift 1
                ;;
            --exit-msg)
                exit_msg="${2}"
                shift 2
                ;;
            --)
                shift 1
                prompt="${1}"
                break
                ;;
            -*)
                echo "error: unknown option: ${1}" >&2
                return 1
                ;;
            *)
                prompt="${1}"
                shift 1
                ;;
        esac
    done

    # Wrap the regex in "^...$" if it is not already
    ! [[ "${yes_pattern}" == "^"* ]] && yes_pattern="^${yes_pattern}"
    ! [[ "${yes_pattern}" == *"$" ]] && yes_pattern="${yes_pattern}$"

    # Prompt the user for input
    read -p "${prompt} " user_input

    # Check if the input matches the yes pattern
    if ! [[ "${user_input}" =~ ${yes_pattern} ]]; then
        [[ -n "${exit_msg}" ]] && echo "${exit_msg}"
        if ${do_exit}; then
            exit 1
        else
            return 1
        fi
    fi
}

function describe-var() (
    :  'Return the type and value of a bash variable

        Return the type and value of a bash variable as returned by `declare`.
        Optionally, can return a more human-readable type and inferred types
        (e.g.: integers and floats).

        Output is returned in the format "<type>\t<value>".

        @usage
            [-h/--human] [-i/--infer] [-f/--follow-links]
            [-t/--type] [-v/--value] [-a/--all] <var>

        @optarg -h/--human
            Return a human-readable type. Defaults to false.

        @optarg -i/--infer
            Infer the type of the variable. Implies --human. Defaults to false.

        @optarg -f/--follow-links
            Follow linked variables. Defaults to false.

        @option -t/--type
            Only show the variable type.

        @option -v/--value
            Only show the variable value.

        @option -a/--all
            Show the variable type and value. This is the default.

        @arg <var>
            The variable to check.

        @stdout
            The type of the variable.

        @return 0
            If the type is determined successfully.

        @return 1
            If the type is not determined successfully.
    '
    # Default values
    local do_human=false
    local do_infer=false
    local do_follow_links=false
    local show_type=true
    local show_value=true
    local var_name var_value
    local __var_type __var_type_char __var_type_chars=() __var_types=()
    local regex
    local opts=() # describe-var options to passthrough if recursing
    local decl

    # Parse the values
    while [[ ${#} -gt 0 ]]; do
        case "${1}" in
            -h | --human)
                do_human=true
                opts+=("${1}")
                shift
                ;;
            -i | --infer)
                do_infer=true
                opts+=("${1}")
                shift
                ;;
            -f | --follow-links)
                do_follow_links=true
                opts+=("${1}")
                shift
                ;;
            -t | --type)
                do_type=true
                do_value=false
                opts+=("${1}")
                shift
                ;;
            -v | --value)
                do_value=true
                do_type=false
                opts+=("${1}")
                shift
                ;;
            -a | --all)
                do_type=true
                do_value=true
                opts+=("${1}")
                shift
                ;;
            --)
                shift
                var_name="${1}"
                break
                ;;
            *)
                var_name="${1}"
                shift
                ;;
        esac
    done

    # Get the variable declaration
    decl=$(declare -p "${var_name}" 2>&1)
    regex="^declare -([^ ]+) ${var_name}=(.*)"
    if [[ "${decl}" =~ ${regex} ]]; then
        __var_type="${BASH_REMATCH[1]}"
        var_value="${BASH_REMATCH[2]}"
    elif [[ "${decl}" =~ "declare: ${var_name}: not found"$ ]]; then
        __var_type="N"
    else
        __var_type="U"
    fi

    # Clean up the value
    ## Remove leading/trailing double quotes
    var_value="${var_value#\"}"
    var_value="${var_value%\"}"
    ## Convert the trailing ' )' in maps to just ')'
    if [[ "${__var_type}" == *"A"* && "${var_value}" == *" )" ]]; then
        var_value="${var_value% )})"
    fi

    debug "var_name:  ${var_name}"
    debug "__var_type:  ${__var_type}"
    debug "var_value: ${var_value}"

    # Check if the variable is linked
    if [[ "${__var_type}" == *"n"* ]] && ${do_follow_links}; then
        # Trim the quotes off the value to get the linked variable name
        if [[ -z "${var_value}" ]]; then
            echo "error: could not determine linked variable" >&2
            return 1
        fi
        describe-var "${opts[@]}" "${var_value}"
        return ${?}
    fi

    # Sort the type chars for consistent output
    ## read the chars into a sorted array
    readarray -t __var_type_chars < <(grep -o . <<< "${__var_type}" | sort)
    ## join the array back into a sorted string
    __var_type="${__var_type_chars[*]}"
    __var_type="${__var_type// /}"

    debug "__var_type_chars: ${__var_type_chars[*]}"
    debug "__var_type:       $(printf %q "${__var_type}")"

    # Determine the human readable / inferred types
    if ${do_human} || ${do_infer}; then
        for __var_type_char in "${__var_type_chars[@]}"; do
            debug "processing __var_type_char: ${__var_type_char}"
            case "${__var_type_char}" in
                *a*) __var_types+=("array") ;;
                *A*) __var_types+=("map") ;;
                *i*) __var_types+=("integer") ;;
                *n*) __var_types+=("link") ;;
                *t*) __var_types+=("trace") ;;
                *x*) __var_types+=("export") ;;
                *r*) __var_types+=("readonly"); ;;
                *l*) __var_types+=("string" "lower") ;;
                *u*) __var_types+=("string" "upper") ;;
                *-*) __var_types+=("string")
                    if ${do_infer}; then
                        # Try to determine a type based on patterns
                        if [[ "${var_value}" == "true" || "${var_value}" == "false" ]]; then
                            __var_types+=("boolean")
                        elif [[ "${var_value}" =~ ^[0-9]+$ ]]; then
                            __var_types+=("integer")
                        elif [[ "${var_value}" =~ ^[0-9]+\.[0-9]+$ ]]; then
                            __var_types+=("float")
                        fi
                    fi
                    ;;
                *N*) __var_types+=("unset") ;;
                *)   __var_types+=("unknown") ;;
            esac
        done
    fi

    # Print the type and value
    if ${do_type}; then
        if ${do_human}; then
            (IFS=, ; echo -n "${__var_types[*]}")
        else
            echo -n "${__var_type}"
        fi
    fi
    if ${do_type} && ${do_value}; then
        printf '\t'
    fi
    if ${do_value}; then
        printf '%s' "${var_value}"
    fi
    echo
)

function negate() {
    :  'Negate "true"<->"false" and "1"<->"-1"

        Negate the value of a boolean or integer. If the value is "true" or "1",
        then the result will be "false" or "-1". If the value is "false" or "-1",
        then the result will be "true" or "1".

        @usage
            <value>

        @arg <value>
            The value to negate.

        @stdout
            The negated value.

        @return 0
            If the value is negated successfully.

        @return 1
            If the value is not negated successfully.
    '
    local value="${1}"

    case "${value}" in
        true)   echo "false" ;;
        false)  echo "true" ;;
        1)      echo "-1" ;;
        -1)     echo "1" ;;
        *)
            echo "error: invalid value: ${value}" >&2
            return 1
            ;;
    esac
}

function truthy() (
    :  'Return 0 for truthy values, else 1

        Uses pythonic logic for determining truthiness. The following values are
        considered falsey:
            - false
            - 0
            - null
            - empty string
            - empty array
            - empty object

        @usage
            [--varname] [-v/--verbose] <value>

        @option --varname
            If specified, the value is the name of a variable.

        @option -v/--verbose
            Output "true" or "false".

        @arg <value>
            The value to check for truthiness.

        @return 0
            If the value is truthy.

        @return 1
            If the value is falsey.
    '
    local __is_var=false
    local __var_description __var_type
    local value
    local -i exit_code=0
    local do_verbose=false

    # Parse the values
    while [[ ${#} -gt 0 ]]; do
        case "${1}" in
            --var | --varname)
                __is_var=true
                shift
                ;;
            -v | --verbose)
                do_verbose=true
                shift
                ;;
            --)
                shift
                value="${1}"
                break
                ;;
            *)
                value="${1}"
                shift
                ;;
        esac
    done

    # Check if the value is a variable
    if ${__is_var}; then
        # Get the type and value
        __var_description=$(describe-var --human --all --follow-links "${value}")
        __var_type="${__var_description%%$'\t'*}"
        debug-vars __var_type
        # we intentionally do not use double quotes here since the value comes
        # from `declare` and will be perfectly escaped
        eval "value=${__var_description#*$'\t'}"
    else
        __var_type="string"
    fi

    debug-vars __var_description __var_type value

    case "${__var_type}" in
        *array* | *map*)
            debug "evaluating as array"
            [[ ${#value[@]} -eq 0 ]] && exit_code=1 ;;
        *integer*)
            debug "evaluating as integer"
            [[ "${value}" -eq 0 ]] && exit_code=1 ;;
        *string*)
            debug "evaluating as string"
            case "${value}" in
                false) exit_code=1 ;;
                0)     exit_code=1 ;;
                "")    exit_code=1 ;;
            esac
            ;;
        *N*) # Not set
            debug "evaluating as not set"
            exit_code=1 ;;
        *U*) # unset
            debug "evaluating as unset"
            exit_code=1 ;;
        *)
            echo "warning: unknown type: ${__var_type}" >&2
            exit_code=1
            ;;
    esac

    if ${do_verbose}; then
        ((exit_code == 0)) && echo "true" || echo "false"
    fi
    return ${exit_code}
)

function check-sudo() (
    :  'Validate whether a user has sudo access

        Check if the current user has sudo access, optionally only for specific
        commands (e.g.: if the user has sudo access for `apt-get` but not for
        `reboot`). If no arguments are supplied, this function will simply check
        if the user can run `sudo -v`. If arguments are supplied, they will be
        individually checked with the `sudo [-n] -l <command>`, and if the user
        does not have access to any of the commands, the function will exit with
        an error.

        @usage
            [-v/--verbose] [-q/--quiet] [<command> [<command> ...]]

        @option -v/--verbose
            Print the commands being checked and the results.

        @option -q/--quiet
            Suppress all output.

        @arg <command>
            Check if the user has sudo access for the specified command.

        @return 0
            If the user has sudo access.

        @return 1
            If the user does not have sudo access
        '
    # Default values
    local do_quiet=true
    local commands=()
    local sudo_cmds=()
    local cmd_string=""
    local exit_code=0

    # Parse the values
    while [[ ${#} -gt 0 ]]; do
        case "${1}" in
            -v | --verbose)
                do_quiet=false
                shift
                ;;
            -q | --quiet)
                do_quiet=true
                shift
                ;;
            --)
                shift
                commands+=("${@}")
                break
                ;;
            *)
                commands+=("${1}")
                shift
                ;;
        esac
    done

    # If we should be quiet, then redirect all output to /dev/null and set up
    # a trap to restore the output when the function exits
    if ${do_quiet}; then
        function __restore_output() {
            exec 1>&9 2>&8 9>&- 8>&-
        }
        exec 9>&1 8>&2 1>/dev/null 2>&1
        trap __restore_output RETURN
    fi

    # If no commands were supplied, check if the user can run `sudo -v`
    if [[ ${#commands[@]} -eq 0 ]]; then
        cmd_str="sudo -n -v"
        if eval "${cmd_str}" &> /dev/null; then
            echo "sudo access granted"
            exit_code=0
        else
            echo "sudo access denied"
            exit_code=1
        fi
    else
        # Check if the user has sudo access for the specified commands
        for cmd in "${commands[@]}"; do
            cmd_str="sudo -n -l ${cmd}"
            echo -n "sudo ${cmd} ... "
            if eval "${cmd_str}" &> /dev/null; then
                echo "granted"
            else
                echo "denied"
                exit_code=1
            fi
        done
    fi

    return ${exit_code}
)

# TODO: *maybe* do something about text running off the screen
# TODO: when aligning the text, only consider printable characters in the maths
function printf-at() {
    :  'Print text at a specific location in the terminal

        Prints text at a specific location in the terminal using ANSI escape
        sequences and `printf`. The cursor is moved to the specified location
        before printing the text and then moved back to its original location
        after the text is printed.

        @usage
            [-r/--row <num>] [-c/--col <num>]
            [-l/--left[=<num>]] [-r/--right[=<num>]]
            [-t/--top[=<num>]] [-b/--bottom[=<num>]]
            [-L/--align-left | -R/--align-right | -C/--align-center]
            [-h/--help] [x,y] <format> [arguments...]

        @option -r/--row <num>
            Move the cursor to row <num> before printing the text.

        @option -c/--col <num>
            Move the cursor to column <num> before printing the text.

        @option -l/--left[=<num>]
            Move the cursor <num> columns from the left before printing the
            text. Defaults to 1.

        @option -r/--right[=<num>]
            Move the cursor <num> columns from the right before printing the
            text. Defaults to 1.

        @option -t/--top[=<num>]
            Move the cursor <num> rows from the top before printing the text.
            Defaults to 1.

        @option -b/--bottom[=<num>]
            Move the cursor <num> rows from the bottom before printing the text.
            Defaults to 1.

        @option -L/--align-left
            Align the text with the specified location on the left.

        @option -R/--align-right
            Align the text with the specified location on the right.

        @option -C/--align-center
            Align the text with the specified location in the center.

        @option -h/--help
            Print this help message and exit.

        @optarg x,y
            The row and column to move the cursor to before printing the text.
            This is equivalent to using `--row x` and `--col y`.

        @arg <format>
            The text to print with plain characters, escape sequences, and/or
            format specifiers.

        @arg* arguments
            The arguments to pass to `printf` for formatting the text.
    '
    # Default values
    local __row __col
    local __left __right __top __bottom
    local __do_align_left=false
    local __do_align_right=false
    local __do_align_center=false
    local __format_string __args=() __print_string

    # Parse the options
    while [[ ${#} -gt 0 ]]; do
        case "${1}" in
            -y | --row)
                __row="${2}"
                __top=
                __bottom=
                shift 2
                ;;
            -x | --col)
                __col="${2}"
                __left=
                __right=
                shift 2
                ;;
            -l* | --left | --left=*)
                [[ "${1}" =~ ^(-l|--left=)(.*)$ ]] \
                    && __left="${BASH_REMATCH[2]}" \
                    || __left=0
                __col=
                __right=
                shift 1
                ;;
            -r* | --right | --right=*)
                [[ "${1}" =~ ^(-r|--right=)(.*)$ ]] \
                    && __right="${BASH_REMATCH[2]}" \
                    || __right=0
                __col=
                __left=
                shift 1
                ;;
            -t* | --top | --top=*)
                [[ "${1}" =~ ^(-t|--top=)(.*)$ ]] \
                    && __top="${BASH_REMATCH[2]}" \
                    || __top=0
                __row=
                __bottom=
                shift 1
                ;;
            -b* | --bottom | --bottom=*)
                [[ "${1}" =~ ^(-b|--bottom=)(.*)$ ]] \
                    && __bottom="${BASH_REMATCH[2]}" \
                    || __bottom=0
                __row=
                __top=
                shift 1
                ;;
            -L | --align-left)
                __do_align_left=true
                __do_align_right=false
                __do_align_center=false
                shift 1
                ;;
            -R | --align-right)
                __do_align_right=true
                __do_align_left=false
                __do_align_center=false
                shift 1
                ;;
            -C | --align-center)
                __do_align_center=true
                __do_align_left=false
                __do_align_right=false
                shift 1
                ;;
            --)
                shift 1
                # Collect any remaining arguments as the format string or args
                if [[ ${#} -gt 0 ]]; then
                    if [[ -z "${__format_string}" ]]; then
                        # If this is the first positional argument, check if it
                        # is in the 'x,y' format
                        if [[ "${1}" =~ ^([0-9]+),([0-9]+)$ ]]; then
                            __row="${BASH_REMATCH[1]}"
                            __col="${BASH_REMATCH[2]}"
                        else
                            __format_string="${1}"
                        fi
                    else
                        __args+=("${@}")
                    fi
                fi
                break
                ;;
            *)
                if [[ -z "${__format_string}" ]]; then
                    # If this is the first positional argument, check if it
                    # is in the 'x,y' format
                    if [[ "${1}" =~ ^([0-9]+),([0-9]+)$ ]]; then
                        __row="${BASH_REMATCH[1]}"
                        __col="${BASH_REMATCH[2]}"
                    else
                        __format_string="${1}"
                    fi
                else
                    __args+=("${1}")
                fi
                shift 1
                ;;
        esac
    done

    # debug-vars \
    #     __row __col __left __right __top __bottom \
    #     __do_align_left __do_align_right __do_align_center \
    #     __format_string __args

    # ---- empty string exit ----

    # If no format string is given, simply exit
    [[ -z "${__format_string}" ]] && return 0

    # ---- formatting

    # Format the string
    ## note: we add a 'x' to the end of the string to ensure that we retain
    ## any (missing) trailing newlines
    if ! __print_string=$(
        printf -- "${__format_string}" "${__args[@]}"
        printf -- x
    ); then
        echo "error: invalid format string" >&2
        return 1
    else
        ## note: now we remove the x, and when we do that using this variable
        ## syntax, it ensures that: 1) if a newline was at the end of the
        ## string, it stays, or 2) if there was no newline at the end of the
        ## string, our __print_string variable won't have one either
        __print_string="${__print_string%x}"
    fi

    # ---- convert relative positions

    # If any relative positions are given, then calculate the absolute positions
    if [[ -n "${__left}" ]]; then
        if [[ "${__left}" =~ ^[0-9]+%$ ]]; then
            __left=$((COLUMNS * ${__left%?} * 100 / 10000))
        fi
        __col="${__left}"
    elif [[ -n "${__right}" ]]; then
        if [[ "${__right}" =~ ^[0-9]+%$ ]]; then
            __right=$((COLUMNS * ${__right%?} * 100 / 10000))
        fi
        __col=$((COLUMNS - __right))
    fi
    if [[ -n "${__top}" ]]; then
        if [[ "${__top}" =~ ^[0-9]+%$ ]]; then
            __top=$((LINES * ${__top%?} * 100 / 10000))
        fi
        __row="${__top}"
    elif [[ -n "${__bottom}" ]]; then
        if [[ "${__bottom}" =~ ^[0-9]+%$ ]]; then
            __bottom=$((LINES * ${__bottom%?} * 100 / 10000))
        fi
        __row=$((LINES - __bottom))
    fi

    # ---- no position given, normal print

    # If __col and __row are empty, then print the string as is
    if [[ -z "${__col}" ]] && [[ -z "${__row}" ]]; then
        printf '%s' "${__print_string}"
        return 0
    fi

    # ---- print at position

    # If only one coordinate is provided, set the other to 0
    [[ -z "${__col}" ]] && __col=0
    [[ -z "${__row}" ]] && __row=0

    # If any alignment options are given, then shift the column position from
    # its current value based on the length of the string
    if ${__do_align_left}; then
        :
    elif ${__do_align_right}; then
        let __col-=${#__format_string}
    elif ${__do_align_center}; then
        let __col-=${#__format_string}/2
    fi

    # debug-vars __row __col __print_string

    # ---- the magic ----
    ## save the cursor position
    tput sc
    ## move the cursor to the specified position
    tput cup "${__row}" "${__col}"
    ## print the string
    printf '%s' "${__print_string}"
    ## restore the cursor position
    tput rc
}

function env-diff() {
    :  'Determine the affect on the environment of running a command

        Determine the affect on the environment of running a command by
        comparing the environment before and after running the command. The
        command is run in a subshell to prevent changes to the current shell.

        @usage
            [-d/--declared] [-D/--no-declared] [-v] [--] command [args...]

        @option -d/--declared
            Include all set variables from `declare -p`.

        @option -D/--no-declared
            Only compare the output of `env`.

        @option -v
            Verbose output.

        @arg command
            The command to run.

        @arg* args
            The arguments to pass to the command.
    '
    local __do_declared=true
    local __do_verbose=false
    local __cmd=()
    local __tmp_dir __tmp_before __tmp_after
    local __cmd_esc __tmp_before_esc __tmp_after_esc

    # Parse the options
    while [[ ${#} -gt 0 ]]; do
        case "${1}" in
            -d | --declared)
                __do_declared=true
                shift 1
                ;;
            -D | --no-declared)
                __do_declared=false
                shift 1
                ;;
            -v)
                __do_verbose=true
                shift 1
                ;;
            -V)
                __do_verbose=false
                shift 1
                ;;
            --)
                shift 1
                __cmd+=("${@}")
                break
                ;;
            *)
                __cmd+=("${1}")
                shift 1
                ;;
        esac
    done

    # Ensure a command was given
    if [[ ${#__cmd[@]} -eq 0 ]]; then
        echo "error: no command given" >&2
        return 1
    fi

    # Create a temporary directory to store the environment files. We do this
    # rather than simply storing the environment in variables because to do that
    # would require running `env` and `declare` in subshells, which might
    # introduce differences in the environment.
    __tmp_dir=$(mktemp -d --tmpdir "env-diff.XXXXXXXXXX")
    __tmp_before="${__tmp_dir}/before"
    __tmp_after="${__tmp_dir}/after"
    trap 'rm -rf "${__tmp_dir}" 2>/dev/null' RETURN

    ${__do_verbose} && echo "* set up temporary directory: ${__tmp_dir}"

    # Escape all variables that will be used in the subshell
    __cmd_esc="${__cmd[0]}"
    [[ ${#__cmd[@]} -gt 1 ]] && __cmd_esc+=$(printf ' %q' "${__cmd[@]:1}")
    __tmp_before_esc=$(printf '%q' "${__tmp_before}")
    __tmp_after_esc=$(printf '%q' "${__tmp_after}")

    ${__do_verbose} && echo "* launching subshell"

    env -i bash --noprofile --norc <<EOF
        # Get the environment before running the command
        env > ${__tmp_before_esc}
        ${__do_declared} && declare -p >> ${__tmp_before_esc}
        if ${__do_verbose}; then
            echo "* env before:"
            env
            if ${__do_declared}; then
                echo "* declared before:"
                declare -p
            fi
        fi

        # Run the command
        ${__do_verbose} && echo "* running command: ${__cmd_esc}"
        eval "${__cmd_esc}"

        # Get the environment after running the command
        env > ${__tmp_after_esc}
        ${__do_declared} && declare -p >> ${__tmp_after_esc}
        if ${__do_verbose}; then
            echo "* env after:"
            env
            if ${__do_declared}; then
                echo "* declared after:"
                declare -p
            fi
        fi

        if ${__do_verbose}; then
            echo "* got before length: \$(wc -c < ${__tmp_before_esc})"
            echo "* got after length:  \$(wc -c < ${__tmp_after_esc})"
        fi

        ${__do_verbose} && echo "* diffing the environment ... "

        # Print the differences
        diff --label env.before --label env.after \
            --changed-group-format='%<%>' --unchanged-group-format='' \
            ${__tmp_before_esc} ${__tmp_after_esc}
EOF
}

function get-user() {
    :  'Get the current user, optionally at a base level

        Get the current user, optionally at a base level. That is, if a user has
        logged in (User A), then logged into another account (User B), then used
        the `sudo` command (root), return User A.

        @usage
            [-b/--base]

        @option -b/--base
            Get the user at the base level.

        @stdout
            The current user.

        @return 0
            If the user is determined successfully.

        @return 1
            If the user is not determined successfully.
    '
    local __do_base=false
    local __user

    # Parse the options
    while [[ ${#} -gt 0 ]]; do
        case "${1}" in
            -b | --base)
                __do_base=true
                shift 1
                ;;
            *)
                echo "error: unknown option: ${1}" >&2
                return 1
                ;;
        esac
    done

    # Get the user
    if ${__do_base}; then
        __user=$(who am i)
        __user=${__user%% *}
    else
        __user=${USER}
    fi

    # Print the user
    echo "${__user}"

    return 0
}