: 'Module for importing functions from bash & zsh scripts.

`include-source <filename>` will search the current directory or
<SHELL>_PATH_LIB (falls back on PATH if unset) for <filename>, then source it
into the current shell. Scripts that call `include-source` can be "compiled"
with `compile-sources` to replace any calls to `include-source` with the
contents of the included script.

I have a lot of useful utility functions that I like to reuse across my
scripts, but copy/pasting them is annoying, and deploying many bash scripts to
a client can get untidy. These functions allow me to keep all of those utility
functions in one place, which allows me to much more quickly employ them and
cut down development time, while still being able to deploy just one compiled
file to a client.

# Setup

  1. Setup the lib dir(s)
     * create a <SHELL>_LIB_PATH environment variable to include the directories
       to search for importable scripts, e.g.:
         export BASH_LIB_PATH="$HOME/bin/lib:$HOME/code/bash/lib"
         export ZSH_LIB_PATH="$HOME/bin/lib:$HOME/code/zsh/lib"
     * OR create a LIB_DIR environment variable to include a single directory
       to search for importable scripts, e.g.:
         export LIB_DIR="$HOME/code/bash/lib"
  2. Source this script in your shell.

# Usage

```sh
include-source "<script_name[.sh]|url>"
compile-sources "<script_path>" ["<script_path>" ...]
```

# Example

## Add these lines to ~/.bashrc to enable the include/compile functions

```sh
# ~/.bashrc

export BASH_LIB_PATH="$HOME/bin/lib:$HOME/code/bash/lib"
source "$HOME/code/bash/lib/include.sh"
```

## Write two bash "libraries" to be imported into other scripts:

```sh
# $HOME/code/bash/lib/somelib.sh

function somelib_func() {
  echo "Hello from somelib_func!"
}
```

```sh
# https://raw.githubusercontent.com/foo/bar/master/gitlib.sh

function gitlib_func() {
  echo "[gitlib_func] $@"
  return 0
}
```

## Write a script that imports the above two libraries

```sh
# ./foo.sh

#!/usr/bin/env bash

include-source "https://raw.githubusercontent.com/foo/bar/master/gitlib.sh"
include-source "somelib"

if gitlib_func "do the thing"; then
  somelib_func "we did the thing!"
fi
```

## Run the script

```sh
$ ./foo.sh
[gitlib_func] do the thing
Hello from somelib_func!
```

## Optionally, compile the above script into a single file

Compile ./foo.sh to ./foo.compiled.sh
```sh
$ compile-sources ./foo.sh > foo.compiled.sh
$ cat ./foo.compiled.sh
#!/usr/bin/env bash

# include-source "https://raw.githubusercontent.com/foo/bar/master/gitlib.sh"
function gitlib_func() {
  echo "[gitlib_func] $@"
  return 0
}
# compile-sources: end of "https://raw.githubusercontent.com/foo/bar/master/gitlib.sh"
# include-source "somelib"
function somelib_func() {
  echo "Hello from somelib_func!"
}
# compile-sources: end of "somelib.sh"

if func_from_gitlib "do the thing"; then
  func_from_somelib "we did the thing!"
fi
```

Compile multiple files in place
```sh
$ compile-sources -i ./foo.sh ./bar.sh
```

Remove, instead of commenting out, the `include-source` call from the compiled
file and do not include the closing tag at the end of the included source code
```sh
$ compile-sources -i -T "./foo.sh" "./bar.sh"
```

# TODO
  - Prevent infinite recursion in include-source
  - Make compile-sources work for `source` calls as well
  - Use regex to import only functions from the included script
    - Allow for modifying imported function names with a prefix/suffix
'
### NOTE: INCLUDE_LIBS Removal
#   Previously, we attempted to track the included libraries in a global
#   INCLUDE_LIBS associative array. We found that bash does *not* support
#   exporting associative arrays, so we've removed this feature for now, leaving
#   the code commented out in place for future reference. If we decide to
#   re-implement this feature, we'll need to do so using `declare -p` to
#   serialize the associative array to a string, then `eval` to deserialize it
#   again. This has implications for both performance and security, so it will
#   require careful consideration if we decide to go this route.


## helpful functions ###########################################################
################################################################################

function __debug() {
    :  'Print a debug message if DEBUG or DEBUG_LOG is set

        @usage
            [<msg> ...]

        @optarg <msg>
            The message to print

        @return 0
            If debugging is enabled

        @return 1
            If debugging is not enabled

        @stderr
            The message to print
    '
    local __prefix __timestamp
    if (
        [ "${INCLUDE_DEBUG}" == "1" ] ||
        [ "${INCLUDE_DEBUG}" == "true" ] ||
        [ -n "${INCLUDE_DEBUG_LOG}" ]
    ); then
        [ ${#} -eq 0 ] && return 0
        __timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
        __prefix="\033[36m[${__timestamp}]\033[0m "
        __prefix+="\033[35m$(basename "${BASH_SOURCE[-1]}")"
        [ "${FUNCNAME[1]}" != "main" ] && __prefix+="\033[1m:${FUNCNAME[1]}()\033[0m"
        __prefix+="\033[32m:${BASH_LINENO[0]}\033[0m -- "
        printf "%s\n" "${@}" \
            | awk -v prefix="${__prefix}" '{print prefix $0}' >> "${INCLUDE_DEBUG_LOG:-/dev/stderr}"
    else
        return 1
    fi
}

function __get_var() {
    :  'Get the value of a variable by name

        Note: This function is not safe for user input. It should only be used
        with trusted input.

        @usage
            <varname>

        @arg <varname>
            The name of the variable

        @stdout
            The value of the variable
    '
    local __varname="${1}"
    eval "echo \${${__varname}}"
}

function __get_shell() {
    :  'Reliably determine the current shell

        @stdout
            The current shell
    '
    local __process_name
    local __shell_var
    local __shell

    # For efficiencies, we will first look for a "__SHELL_$$" variable in the
    # environment which should contain the shell for this specific process. This
    # function will set that variable on the first run, then use it each
    # subsequent run.
    __shell_var="__SHELL_$$"
    __shell_value=$(__get_var "${__shell_var}")
    if [ -z "${__shell_value}" ]; then
        # If the variable is not set, we will determine the shell using the process
        # name.
        __process_name=$(ps -p "$$" -o args= | sed 's/^-\?\([^ ]\+\).*/\1/')
        __shell=$(basename "${__process_name}" | tr '[:upper:]' '[:lower:]')
        [ -z "${__shell}" ] && return 1
        export "${__shell_var}"="${__shell}"
        __shell_value=$(__get_var "${__shell_var}")
    fi

    echo "${__shell_value}"
}

function __is_uri() {
    :  'Test a string to determine if it is a URI

        @usage
            <string>

        @arg <string>
            The string to test

        @return 0
            If the string is a URI

        @return 1
            If the string is not a URI
    '
    local __string="${1}"
    case "${__string}" in
        http://* | https://*)  return 0 ;;
        *)                     return 1 ;;
    esac
}

function __functionname() {
    :  'Cross-shell function for returning the calling function name

        @usage
            [<stack index>]

        @optarg <stack index>
            The index of the function in the call stack to return

        @stdout
            The name of the calling function

        @return 0
            If the function name was successfully returned

        @return 108
            If the shell is not recognized
    '
    local __shell=$(__get_shell)
    local __index=${1:- -1}
    case "${__shell}" in
        bash)
            echo ${FUNCNAME[${__index}]}
            ;;
        zsh)
            echo ${funcstack[${__index}]}
            ;;
        *)
            echo "unknown shell: ${__shell}" >&2
            return 108
            ;;
    esac
}

function __in_array() {
    :  'Checks if an item is in an array.

        @usage
            <item> <array-item-1> [<array-item-2> ...

        @arg <item>
            The item to check for in the array

        @arg+
            The array to check

        @return 0
            The item is in the array

        @return 1
            The item is not in the array
    '
    #__debug "_call(${*})"

    local __item __array=() __el
    __item="${1}"
    __array=( "${@:2}" )

    for __el in ${__array[@]}; do
        if [ "${__el}" == "${__item}" ]; then
            return 0
        fi
    done

    return 1
}


## include-source ##############################################################
################################################################################

## Usage functions
###

function __include_source_help_usage() {
    echo "usage: $(__functionname) [-hlnNcCvV] <path>"
}

function __include_source_help_epilogue() {
    echo "import shell scripts"
}

function __include_source_help_full() {
    __include_source_help_usage
    __include_source_help_epilogue
    echo
    echo "Imports the specified shell script. The specified script can be the"
    echo "name of a script in <SHELL>_LIB_PATH, the name of a script in PATH,"
    echo "the name of a script in the current directory, or a url to a script."
    echo
    cat << EOF
    -h/--help          show help info
    -l/--location      print the location of the imported script
    -n/--dry-run       don't import the script
    -N/--no-dry-run    import the script
    -c/--cat           print the contents of the imported script
    -C/--no-cat        don't print the contents of the imported script
    -v/--verbose       be verbose
    -V/--no-verbose    don't be verbose
EOF
}

function __include_source_parse_args() {
    # default values
    VERBOSE=0
    DO_CAT=0
    DO_SOURCE=1
    SHOW_LOCATION=0

    # parse arguments
    SOURCE_PATH=""
    SOURCE_ARGS=()
    while [ ${#} -gt 0 ]; do
        local arg="$1"
        case "$arg" in
            -v | --verbose)
                VERBOSE=1
                shift
                ;;
            -V | --no-verbose)
                VERBOSE=0
                shift
                ;;
            -l | --location)
                SHOW_LOCATION=1
                shift
                ;;
            -L |--no-location)
                SHOW_LOCATION=0
                shift
                ;;
            -N | --no-source)
                DO_SOURCE=0
                shift
                ;;
            -n | --source)
                DO_SOURCE=1
                shift
                ;;
            -c | --cat)
                DO_CAT=1
                shift
                ;;
            -C | --no-cat)
                DO_CAT=0
                shift
                ;;
            -h)
                __include_source_help_usage
                __include_source_help_epilogue
                return 3
                ;;
            --help)
                __include_source_help_full
                return 3
                ;;
            -*)
                echo "$(__functionname): invalid option '${arg}'" >&2
                return 1
                ;;
            *)
                SOURCE_PATH="${arg}"
                shift 1
                # Set any remaining args as arguments to the included script
                SOURCE_ARGS=("${@}")
                break
                ;;
        esac
    done
}


## Helpful functions
###

function __include_libs_get_path() {
    : '
    Return the value of <SHELL>_LIB_PATH or PATH if it is not set.

    @stdout     The value of <SHELL>_LIB_PATH or PATH
    '
    #__debug "_call(${*})"
    local __shell_lower __shell_upper
    local __path __lib_path_name __lib_path_value

    # reliably determine the shell
    __shell_lower=$(__get_shell)
    __shell_upper=$(echo "${__shell_lower}" | tr '[:lower:]' '[:upper:]')

    # determine the current shell's lib path
    __lib_path_name="${__shell_upper}_LIB_PATH"
    #__debug "lib_path_name: ${lib_path_name}"

    # load the value of the lib path from the environment
    if [ "${__shell_lower}" = "bash" ]; then
        #__debug "getting bash lib path"
        __lib_path_value="${!__lib_path_name}"
    elif [ "${__shell_lower}" = "zsh" ]; then
        #__debug "getting zsh lib path"
        __lib_path_value="${(P)__lib_path_name}"
    else
        #__debug "attempting generic lib path eval"
        # attempt a generic eval, although chances are low that the rest of
        # the module will work even if this does
        eval local __lib_path_value="\$${__lib_path_name}"
        if [ $? -ne 0 ]; then
            echo "$(__functionname): failed to determine the value of '${__lib_path_name}'" >&2
            return 1
        fi
    fi

    __path="${__lib_path_value:-${PATH}}"

    # If LIB_DIR is set, append it to the lib path
    if [ -n "${LIB_DIR}" ]; then
        if [ -n "${__path}" ]; then
            __path="${LIB_DIR}:${__path}"
        else
            __path="${LIB_DIR}"
        fi
    fi

    #__debug "lib_path: ${lib_path}"
    echo "${__path}"
}

function __include_libs_get_filepath() {
    : '
    Given a library name (with or without the .sh extension), get its filepath
    in the current directory, <SHELL>_LIB_PATH, or PATH

    @usage      <filename>[.sh]
    @stdout     The path to the file
    '
    #__debug "_call(${*})"

    local __filename="${1}"
    local __local_filepath
    local __dir __lib_path_array=()

    # look for the file in the current directory with and without the .sh
    # extension
    __local_filepath="$(pwd)/${__filename}"
    if [ -f "${__local_filepath}" ] && [ -r "${__local_filepath}" ]; then
        echo "${__local_filepath}"
        return 0
    elif [ -f "${__local_filepath}.sh" ] && [ -r "${__local_filepath}.sh" ]; then
        echo "${__local_filepath}.sh"
        return 0
    fi

    # Try to find the path in <SHELL>_LIB_PATH or PATH, with or without the .sh
    IFS=":" read -ra __lib_path_array <<< "$(__include_libs_get_path)"
    #__debug "__lib_path_array: ${__lib_path_array[@]}"
    for __dir in "${__lib_path_array[@]}"; do
        #__debug "looking for '${__filename}' in '${__dir}'"
        # determine if a readable file with the given name exists in this dir
        if [ -f "${__dir}/${__filename}" ] && [ -r "${__dir}/${__filename}" ]; then
            #__debug "found '${__filename}' in '${__dir}'"
            echo "${__dir}/${__filename}"
            return 0
        elif [ -f "${__dir}/${__filename}.sh" ] && [ -r "${__dir}/${__filename}.sh" ]; then
            #__debug "found '${__filename}.sh' in '${__dir}'"
            echo "${__dir}/${__filename}.sh"
            return 0
        fi
    done

    # if we get here, we didn't find the file
    return 1
}

function __include_libs_get_location() {
    : '
    Get the location of the shell lib, whether a file or url

    @usage      <filename>
    @stdout     The location of the file
    '
    #__debug "_call(${*})"

    local __filename="${1}"
    local __filepath

    # determine if the file is a filepath or a url
    if __is_uri "${__filename}"; then
        echo "${__filename}"
        return 0
    fi

    __filepath="$(__include_libs_get_filepath "${__filename}")"
    if [ $? -eq 0 ]; then
        echo "${__filepath}"
        return 0
    fi
    return 1
}

## Main functions
###

# Import a shell script from a url
function source-url() {
    : '
    Download a shell script from a url and source it in the current shell

    @usage <url>
    '
    #__debug "_call(${*})"

    local __url="${1}"
    local __filename="${__url##*/}"
    shift 1
    local __source_args=("${@}")
    local __exit_code=0
    local __tmp_dir __script_file

    # treat the filename as a url
    if [ "${SHOW_LOCATION}" -eq 1 ] 2>/dev/null; then
        echo "${__url}"
        return 0
    elif [ "${VERBOSE}" -eq 1 ] 2>/dev/null; then
        echo "$(__functionname): sourcing '${__filename}'"
    fi

    # download the script
    __tmp_dir=$(mktemp -dt "$(__functionname).XXXXX")
    __script_file="${__tmp_dir}/${__filename}"

    # ensure the temporary directory is removed on function return
    trap "rm -rf ${__tmp_dir}" RETURN

    curl -s -o "${__script_file}" "${__url}"
    if [ $? -ne 0 ] && [ "${VERBOSE}" -eq 1 ]; then
        echo "$(__functionname): failed to download '${__filename}'" >&2
        return 1
    fi

    # print the contents of the script if requested
    if [ "${DO_CAT}" -eq 1 ]; then
        cat "${__script_file}"
    fi

    # source the contents of the downloaded script
    if [ "${DO_SOURCE}" -eq 1 ]; then
        source "${__script_file}" "${__source_args[@]}"
        __exit_code=${?}
        ### NOTE: INCLUDE_LIBS Removal
        # If successful, add the URL to the list of included libs
        #INCLUDE_LIBS["${__filename}"]="${__url}"
    fi

    # return the exit code of the sourced script if available
    return ${__exit_code}
}

# Import a shell script from a filename
function source-lib() {
    : '
    Given a library name, find it in the LIB_PATH or PATH and source it in the
    current shell.

    @usage      <lib>[.sh]
    '
    #__debug "_call(${*})"

    local __filename="${1}"
    local __filepath
    shift 1
    local __source_args=("${@}")
    local __exit_code=0

    # get the path to the file
    __filepath=$(__include_libs_get_filepath "${__filename}")

    #__debug "sourcing filepath: ${__filepath}"

    # if we couldn't find the file, exit with an error
    if [ -z "${__filepath}" ]; then
        echo "$(__functionname): failed to find '${__filename}'" >&2
        return 1
    fi

    # print the location of the file if requested
    if [ "${SHOW_LOCATION}" -eq 1 ]; then
        echo "${__filepath}"
        return 0
    fi

    # print the contents of the script if requested
    if [ "${DO_CAT}" -eq 1 ]; then
        cat "${__filepath}"
        __exit_code=${?}
    fi

    # source the file
    if [ "${DO_SOURCE:-1}" -eq 1 ]; then
        if [ "${VERBOSE:-0}" -eq 1 ]; then
            echo "$(__functionname): sourcing '${__filepath}'"
        fi
        #__debug "sourcing 'source ${__filepath} ${__source_args[@]}'"
        source "${__filepath}" "${__source_args[@]}"
        __exit_code=${?}
        #__debug "finished sourcing '${__filepath}'"
        # If successful, add the file to the list of included libs
        if ((__exit_code == 0)); then
            :
            #__debug "successfully sourced '${__filename}'"
            ### NOTE: INCLUDE_LIBS Removal
            #INCLUDE_LIBS["${__filename}"]="${__filepath}"
        else
            :
            #__debug "failed to source '${__filename}'"
        fi
    fi

    return ${__exit_code}
}

# Import a shell script from ${<SHELL>_LIB_PATH:-${PATH}} given a filename
function include-source() {
    : '
    Given a library name or url, source it in the current shell. If arguments
    are passed after the filename, they are treated as arguments to the
    included script.

    @usage      [-h/--help] [-l/--location] [-L/--no-location] [-n/--dry-run]
                [-N/--no-dry-run] [-c/--cat] [-C/--no-cat] [-v/--verbose]
                [-V/--no-verbose] <filename> [<filename args> ...]
    '
    #__debug "_call(${*})"

    local __exit_code=0

    __include_source_parse_args "$@"
    case $? in 0);; 3) return 0 ;; *) return $?;; esac

    # ensure the path is not empty
    if [ -z "${SOURCE_PATH}" ]; then
        __include_source_help_usage >&2
        __exit_code=1
    else
        # determine whether to treat the path as a filepath or url
        if __is_uri "${SOURCE_PATH}"; then
            # treat the path as a url
            #__debug "sourcing url: ${SOURCE_PATH}"
            source-url "${SOURCE_PATH}" "${SOURCE_ARGS[@]}"
            __exit_code=${?}
        else
            # treat the path as a filepath
            #__debug "sourcing lib: ${SOURCE_PATH}"
            source-lib "${SOURCE_PATH}" "${SOURCE_ARGS[@]}"
            __exit_code=${?}
            #__debug "why are we not reaching this line? ;-;"
            #__debug "source ${SOURCE_PATH} exit code: ${__exit_code}"
        fi
    fi

    unset SOURCE_PATH SOURCE_ARGS SHOW_LOCATION VERBOSE DO_CAT DO_SOURCE
    return ${__exit_code}
}

# Alias for include-source
function import() { include-source "${@}"; }


## compile-sources #############################################################
################################################################################

## Usage functions
###

function __compile_sources_help_usage() {
    echo "usage: $(__functionname) [-hiItT] <file> [<file> ...]"
}

function __compile_sources_help_epilogue() {
    echo 'replace `include-source` calls with the contents of the included file'
}

function __compile_sources_help_full() {
    __compile_sources_help_usage
    __compile_sources_help_epilogue
    echo
    echo "Generates a single compiled shell script that contains the source"
    echo "of the original script along with the source of each included script."
    echo
    cat << EOF
    -h/--help          show help info
    -i/--in-place      replace the original script with the compiled script
    -I/--no-in-place   print the compiled script to stdout
    -b/--backups       keep backups of the original script when replacing it
    -B/--no-backups    do not keep backups of the original script
    -t/--tags          print markers at the beginning and end of each included
                       script
    -T/--no-tags       do not print markers at the beginning and end of each
                       included script
EOF
}

function __compile_sources_parse_args() {
    # default values
    IN_PLACE=0
    IN_PLACE_BACKUPS=1
    INCLUDE_TAGS=1

    # parse arguments
    POSITIONAL_ARGS=()
    while [ ${#} -gt 0 ]; do
        local arg="$1"
        case "$arg" in
            -i|--in-place)
                IN_PLACE=1
                shift
                ;;
            -I|--no-in-place)
                IN_PLACE=0
                shift
                ;;
            -b|--backups)
                IN_PLACE_BACKUPS=1
                shift
                ;;
            -B|--no-backups)
                IN_PLACE_BACKUPS=0
                shift
                ;;
            -t|--tags)
                INCLUDE_TAGS=1
                shift
                ;;
            -T|--no-tags)
                INCLUDE_TAGS=0
                shift
                ;;
            -h)
                __compile_sources_help_usage
                __compile_sources_help_epilogue
                return 3
                ;;
            --help)
                __compile_sources_help_full
                return 3
                ;;
            -*)
                echo "$(__functionname): invalid option '$arg'" >&2
                return 1
                ;;
            *)
                POSITIONAL_ARGS+=("$arg")
                shift
                ;;
        esac
    done
    set -- "${POSITIONAL_ARGS[@]}"
}


## helpful functions
###

# Check if the given filepath has any valid `include-source` or `source` calls.
# If the given filepath is "-", read from stdin
function __compile_sources_has_source_calls() {
    local __filepath="${1}"
    local __contents

    # get the file's contents
    if [ "${__filepath}" = "-" ]; then
        __contents=$(cat)
    else
        __contents=$(cat "${__filepath}")
    fi
    echo "${__contents}" | grep -Eq '^(include-)?source\b'
}

# Returns the line number of and shell lib specified by  the first occurrence of
# "^include-source\b" in the given file. If '-' is specified, read from stdin
function __compile_sources_find_include_source_line() {
    local __filename="${1:- -}"
    local __file_contents
    local __line_number
    local __line
    local __sourced_filename

    # get the contents of the file
    if [ "${__filename}" = "-" ]; then
        __file_contents=$(cat)
    else
        __file_contents=$(<"${__filename}")
    fi

    # get the line number of the first "include-source" line
    __line_number=$(
        echo "${__file_contents}" \
        | grep -n "^include-source\b" \
        | cut -d ':' -f1 \
        | head -n1
    )

    # if we couldn't find the line number, exit with an error
    if [ -z "${__line_number}" ]; then
        return 1
    fi

    # get the line content of that "include-source" line
    __line=$(echo "${__file_contents}" | sed -n "${__line_number}p")

    # get the sourced filename from the line
    __sourced_filename=$(echo "${__line}" | awk -F " " '{print $2}')

    # remove any single or double quotes from the beginning/end of the filename
    __sourced_filename="$(echo "${__sourced_filename}" | sed "s/^[\"']//;s/[\"']$//")"

    echo "${__line_number}:${__sourced_filename}"
}

# accepts a filepath and replaces all "^include-source\b" lines with the
# contents of the included file. if the filepath is '-', read from stdin.
# compiled scripts are output to stdout
# exit codes:
#  0 - success
#  1 - one or more included libs was empty
#  2 - error parsing source file
function __compile_sources() {
    #__debug "_call(${*})"

    # get the filepath
    local __filepath="${1}"
    local __included_sources
    local __file_contents
    local __include_source_line
    local __line_number
    local __sourced_filename
    local __included_filepath
    local __sourced_contents
    local __sourced_contents_exit_code
    local __recursive_exit_code

    # treat any remaining arguments as already included files from recursive calls
    shift
    __included_sources=("$@")

    # get the file contents
    if [ "${__filepath}" = "-" ]; then
        __file_contents=$(cat)
    else
        __file_contents=$(<"${__filepath}")
    fi

    # loop while we can find "^include-source\b" lines
    while grep -q "^include-source\b" <<< "${__file_contents}"; do
        # get the line number of the first "include-source" line
        __include_source_line=$(echo "${__file_contents}" | __compile_sources_find_include_source_line -)
        __line_number=$(echo "${__include_source_line}" | cut -d ':' -f1)
        __sourced_filename=$(echo "${__include_source_line}" | cut -d ':' -f2)

        # check whether the source has already been included
        if __in_array "${__sourced_filename}" "${__included_sources[@]}"; then
            # if it has, remove the "include-source" line from the file
            __file_contents=$(echo "${__file_contents}" | sed -e "${__line_number}d")
            continue
        fi

        # add the sourced file to the stack of libs that have been included
        __included_sources+=("${__sourced_filename}")

        # get the filepath or url of the source
        __included_filepath=$(include-source -l "${__sourced_filename}")

        # get the contents of the lib
        __sourced_contents=$(include-source -n --cat "${__sourced_filename}" 2>&1)
        __sourced_contents_exit_code=$?

        # if there was an error. exit with an error
        if [ ${__sourced_contents_exit_code} -ne 0 ]; then
            echo "${__sourced_contents}" >&2
            return 2
        fi

        # if the source file is empty, then exit with an error
        if [ -z "${__sourced_contents}" ]; then
            echo "$(__functionname): source file '${__sourced_filename}' is empty" >&2
            return 1
        else
            # check to see if the source file contains any "include-source" lines
            if grep -q "^include-source\b" <<< "${__sourced_contents}"; then
                # if it does, recursively compile the source file
                __sourced_contents=$(echo "${__sourced_contents}" | __compile_sources - "${__included_sources[@]}")
                # if the recursive sourcing returned a non-zero status, pass it on
                __recursive_exit_code=$?
                if [ "${__recursive_exit_code}" -ne 0 ]; then
                    return "${__recursive_exit_code}"
                fi
            fi
        fi

        # if we successfully loaded some content and include_tags is set,
        # then add a line to the end of the source indicating where it ends
        if [ "${INCLUDE_TAGS:-1}" -eq 1 ]; then
            __sourced_contents="${__sourced_contents}"$'\n'"# $(__functionname): end of '${__sourced_filename}'"
        fi

        # if include_tags is set, comment out the include-source line and
        # add the source file contents after it, else just replace the
        # include-source line with the source file contents
        if [ "${INCLUDE_TAGS:-1}" -eq 1 ]; then
            # comment out the include-source line
            __file_contents=$(echo "${__file_contents}" | sed "${__line_number}s/^/# /")
        else
            # delete the include-source line
            __file_contents=$(echo "${__file_contents}" | sed "${__line_number}d")
            __line_number=$((__line_number - 1))
        fi

        # if the line number is 0, then prepend the contents
        if [ "${__line_number}" -eq 0 ]; then
            __file_contents="${__sourced_contents}"$'\n'"${__file_contents}"
        else
            # otherwise, insert the contents after the line number
            __file_contents=$(
                sed "${__line_number}r /dev/stdin" \
                    <(echo "${__file_contents}") \
                    <<< "${__sourced_contents}"
            )
        fi
    done

    # output the compiled file
    echo "${__file_contents}"
}


## main functions
###

function compile-sources() {
    : '
    Replace `include-source` calls with the source library contents.

    @usage      [-h/--help] [-i/--in-place] [-I/--no-in-place] [-b/--backups]
                [-B/--no-backups] [-t/--tags] [-T/--no-tags] <file> [<file> ...]
    '
    #__debug "_call(${*})"

    local __exit_code=0
    local __filepath="${1}"
    local __compiled_file
    local __position_args

    __compile_sources_parse_args "$@"
    # exit cleanly if help was displayed or with the exit code if non-zero
    case $? in 0);; 3) return 0 ;; *) return $?;; esac

    # loop over each file in the positional arguments
    for __filepath in "${POSITIONAL_ARGS[@]}"; do
        # compile the file
        __compiled_file=$(__compile_sources "${__filepath}")
        __exit_code=$?

        # if the exit code is non-zero, exit with that code
        if [ "${__exit_code}" -ne 0 ]; then
            break
        fi

        # output the compiled file or overwrite the original file as appropriate
        if [ "${IN_PLACE}" -eq 1 ]; then
            if [ "${IN_PLACE_BACKUPS}" -eq 1 ]; then
                # make a backup of the original file
                cp "${__filepath}" "${__filepath}.bak"
            fi
            echo "${__compiled_file}" > "${__filepath}"
        else
            echo "${__compiled_file}"
        fi
    done

    unset DO_CAT DO_LIST DO_HELP IN_PLACE IN_PLACE_BACKUPS INCLUDE_TAGS POSITIONAL_ARGS
    return ${__exit_code}
}

if [ "${BASH_SOURCE[0]}" != "${0}" ]; then
    # When sourcing the script, allow some options to be passed in
    __do_set_lib_dir=false

    # Parse the arguments
    while [ ${#} -gt 0 ]; do
        case "${1}" in
            --set-libdir | --auto)
                __do_set_lib_dir=true
                shift
                ;;
            *)
                break
                ;;
        esac
    done

    # Automatically set LIB_DIR to the same directory as the script
    if ${__do_set_lib_dir}; then
        __include_path="${BASH_SOURCE[0]}"
        if [ "${__include_path}" == */* ]; then
            __lib_dir="${__include_path%/*}"
        else
            __lib_dir="."
        fi
        export LIB_DIR="$(realpath "${__lib_dir}")"
        #__debug "set LIB_DIR=${LIB_DIR}" >&2
        unset __include_path __lib_dir
    fi

    ## Export Functions ########################################################
    ############################################################################

    export -f __debug
    export -f __get_var
    export -f __get_shell
    export -f __is_uri
    export -f __functionname
    export -f __in_array
    export -f __include_source_help_usage
    export -f __include_source_help_epilogue
    export -f __include_source_help_full
    export -f __include_source_parse_args
    export -f __include_libs_get_path
    export -f __include_libs_get_filepath
    export -f __include_libs_get_location
    export -f source-url
    export -f source-lib
    export -f include-source
    export -f import
    export -f __compile_sources_help_usage
    export -f __compile_sources_help_epilogue
    export -f __compile_sources_help_full
    export -f __compile_sources_parse_args
    export -f __compile_sources_find_include_source_line
    export -f __compile_sources
    export -f compile-sources


    ## Export Variables ########################################################
    ############################################################################

    export INCLUDE_SOURCE="include-source"
    export INCLUDE_FILE=$(realpath "${BASH_SOURCE[0]}")
    ### NOTE: INCLUDE_LIBS Removal
    #declare -Ax INCLUDE_LIBS=( ["${INCLUDE_FILE##*/}"]="${INCLUDE_FILE}" )
fi
