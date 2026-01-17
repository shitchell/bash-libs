#!/usr/bin/env bash
: '
Functions for bash traps. Traps can be set using the `trap` command:

`trap [-lp] [[ARG] SIGNALS]`

e.g.:

```sh
function foo() {
    local tmp_file=$(mktemp)
    trap "rm ${tmp_file}" RETURN
    # ...do stuff with the temporary file
}
```

If you call `trap` multiple times for the same signal, only the last command
will be used; the previous ones will be overwritten. To that end, this library
provides a simple syntax for setting traps:

`function trap_<signal>[_<name>]() { ... }`
`load-traps [SIGNALS...]`

e.g.:

```sh
function trap_exit_some_stuff() {
    echo "doing some stuff on script exit"
}

function trap_exit_other_stuff() {
    echo "doing other stuff on script exit"
}

eval "$(load-traps)"
```

This will set the `EXIT` trap to run both `trap_exit_some_stuff` and
`trap_exit_other_stuff` when the script exits. Optionally, `load-traps` can be
called with a list of signals to set traps for, e.g. `load-traps EXIT INT` will
only look for functions beginning with `trap_exit_` and `trap_int_`.

The following is the list of available `trap` signals (from `trap -l`):
```
 1) SIGHUP       2) SIGINT       3) SIGQUIT      4) SIGILL       5) SIGTRAP
 6) SIGABRT      7) SIGBUS       8) SIGFPE       9) SIGKILL     10) SIGUSR1
11) SIGSEGV     12) SIGUSR2     13) SIGPIPE     14) SIGALRM     15) SIGTERM
16) SIGSTKFLT   17) SIGCHLD     18) SIGCONT     19) SIGSTOP     20) SIGTSTP
21) SIGTTIN     22) SIGTTOU     23) SIGURG      24) SIGXCPU     25) SIGXFSZ
26) SIGVTALRM   27) SIGPROF     28) SIGWINCH    29) SIGIO       30) SIGPWR
31) SIGSYS      34) SIGRTMIN    35) SIGRTMIN+1  36) SIGRTMIN+2  37) SIGRTMIN+3
38) SIGRTMIN+4  39) SIGRTMIN+5  40) SIGRTMIN+6  41) SIGRTMIN+7  42) SIGRTMIN+8
43) SIGRTMIN+9  44) SIGRTMIN+10 45) SIGRTMIN+11 46) SIGRTMIN+12 47) SIGRTMIN+13
48) SIGRTMIN+14 49) SIGRTMIN+15 50) SIGRTMAX-14 51) SIGRTMAX-13 52) SIGRTMAX-12
53) SIGRTMAX-11 54) SIGRTMAX-10 55) SIGRTMAX-9  56) SIGRTMAX-8  57) SIGRTMAX-7
58) SIGRTMAX-6  59) SIGRTMAX-5  60) SIGRTMAX-4  61) SIGRTMAX-3  62) SIGRTMAX-2
63) SIGRTMAX-1  64) SIGRTMAX
```

The following special signals can also be used:
- `EXIT`: executed when the shell exits.
- `RETURN`: executed when a shell function or a script executed with the `.`
  or `source` commands finishes executing.
- `DEBUG`: executed after every simple command (see `man bash` for more info).
- `ERR`: executed whenever a command has a non-zero exit status.
'

include-source 'debug'

_load_traps() {
    # Helper function for `load-traps()`. Accepts a single signal followed by a
    # set of function names. Sets the trap for the given signal to run all of
    # the provided functions.
    local signal="${1}"
    local functions=( "${@:2}" )
    local trap_function_name=""
    local trap_function_code=""

    debug-vars signal functions

    # Create a trap function for the given signal
    trap_function_name="_trap_${signal,,}"
    trap_function_code="function ${trap_function_name}() {"$'\n'
    for function in "${functions[@]}"; do
        trap_function_code+="$(declare -f ${function});"$'\n'
        trap_function_code+="${function};"$'\n'
    done
    trap_function_code+="}"$'\n'
    trap_function_code+="trap ${trap_function_name} ${signal}"$'\n'

    debug-vars trap_function_name trap_function_code
    printf '%s' "${trap_function_code}"
}

function load-traps() {
    :  'Load all trap functions, optionally for specific signals

        @usage
            [-q/--quiet] [-v/--verbose] <signals>...

        @option -q/--quiet
            Suppress all output.

        @option -v/--verbose
            Print verbose output.

        @arg+ <signals>
            A list of signals to load trap functions for. If not provided, all
            signals will be loaded.

        @stdout
            The names of the trap functions that were loaded. If the `-v` flag
            is provided, the function bodies will also be printed.

        @return 0
            All trap functions were loaded successfully.

        @return 1
            One or more trap functions failed to load.
    '
    # Default values
    local verbosity=1  # 0 = silence, 1 = normal, 2 = verbose
    local signals=()
    local trap_functions=()  # list of all `trap_` functions
    local -A load_functions=()  # map of signals and their `trap_` functions
    local signal
    local function function_signal

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -q | --quiet)
                verbosity=0
                shift 1
                ;;
            -v | --verbose)
                verbosity=2
                shift 1
                ;;
            *)
                signals+=("$1")
                shift 1
                ;;
        esac
    done

    # If silent, redirect all output to /dev/null
    if [[ ${verbosity} -eq 0 ]]; then
        exec 3>&1 4>&2 1>/dev/null 2>&1
        function unsilence() {
            exec 1>&3 2>&4
            exec 3>&- 4>&-
        }
        trap unsilence RETURN
    fi

    # Load all `trap_*` functions
    readarray -t trap_functions < <(compgen -A function trap_)

    # Load the trap functions into a map by signal name
    for trap_function in "${trap_functions[@]}"; do
        # Parse out the signal name
        function_signal="${trap_function,,}"
        function_signal="${function_signal#trap_}"
        function_signal="${function_signal%%_*}"

        # If signals were provided, only load the functions for those signals
        if [[ ${#signals[@]} -gt 0 ]] && ! [[ " ${signals[@]} " =~ " ${function_signal} " ]]; then
            continue
        fi

        # If the signal is already in the map, append this function with a space
        if [[ -v load_functions["${function_signal}"] ]]; then
            load_functions["${function_signal}"]+=" ${trap_function}"
        else
            load_functions[${function_signal}]="${trap_function}"
        fi
    done

    # Load the trap functions
    for signal in "${!load_functions[@]}"; do
        signals=( ${load_functions["${signal}"]} )
        if [[ ${verbosity} -gt 1 ]]; then
            echo "Loading trap functions for signal: ${signal}"
            for signal in "${signals[@]}"; do
                declare -f "${signal}"
            done | sed 's/^/  /'
        fi
        _load_traps "${signal}" "${signals[@]}"
    done
}
