: '
Network related functions
'
# TODO: - add -i/--interactive option to exec-socket for interactive sessions
#       - add -t/--timeout option for connection timeout
#       - have exec-http do its own colorization rather than offloading to
#         exec-socket, that way we can colorize headers but not response data

include-source 'debug'
include-source 'colors'


function generate-basic-auth() {
    :  'Generate a base64 encoded basic authentication token.

        @usage
            <user> <password>

        @stdout
            The basic authentication header.
    '
    local user="${1}"
    local password="${2}"
    
    printf '%s' "${user}:${password}" | base64
}

function exec-http() {
    :  'Makes use of /dev to send a request without any external tools

        @usage
            [-X/--request <method>] [-H/--header <header>] [-d/--data <data>]
            [-u/--user <user:password>] [-A/--user-agent <agent>]
            [-p/--protocol <protocol>] [-V/--http-version <version>]
            [-S/--suppress-headers] [-s/--silent] [-v/--verbose]
            [-c/--color <when>] <host>[:<port>][/<path>]

        @optarg -X/--request <method>
            The request method to use. Defaults to GET.

        @optarg -H/--header <header>
            Additional headers to include in the request. Can be used multiple
            times. Syntax is "<header>: <value>".

        @optarg -d/--data <data>
            Data to send in the request body. Only applicable to POST requests.

        @optarg -u/--user <user:password>
            Basic authentication credentials to use.

        @optarg -A/--user-agent <agent>
            The user agent to use. Defaults to bash.

        @optarg -p/--protocol <protocol>
            The protocol to use (under /dev). Available options are tcp and udp.
            Defaults to tcp.

        @optarg -V/--http-version <version>
            The HTTP version to use. Defaults to 1.1.

        @optarg -S/--suppress-headers
            Suppress response headers.

        @optarg -s/--silent
            Suppress all output.

        @option -v/--verbose
            Enable verbose output.

        @optarg -c/--color <when>
            Colorize the output. Available options are always, auto, and never.
            Defaults to auto.

        @arg <host>[:<port>][/<path>]
            The host to send the request to. Port defaults to 80 if not
            specified. Path defaults to / if not specified.

        @stdout
            The response from the server.

        @return 0
            The request was successful.

        @return 1
            The request failed.
    '
    # Default values
    local method="GET"
    local headers=()
    local data=""
    local auth=""
    local user_agent="bash"
    local protocol="tcp"
    local http_version="1.1"
    local host=""
    local port=80
    local path="/"
    local do_suppress_headers=false
    local verbosity=1 # 0 = silent, 1 = normal, 2 = verbose
    local response_headers_finished=false
    local -A request_headers=()
    local sock_args=()
    local color_when="auto"

    # Parse arguments
    while [[ ${#} -gt 0 ]]; do
        case "${1}" in
            -X | --request)
                method="${2}"
                shift 2
                ;;
            -H | --header)
                headers+=("${2}")
                shift 2
                ;;
            -d | --data)
                data="${2}"
                shift 2
                ;;
            -u | --user)
                auth="${2}"
                shift 2
                ;;
            -p | --protocol)
                protocol="${2}"
                shift 2
                ;;
            -S | --suppress-headers)
                do_suppress_headers=true
                shift 1
                ;;
            -s | --silent)
                verbosity=0
                shift 1
                ;;
            -v | --verbose)
                verbosity=2
                shift 1
                ;;
            -c | --color)
                color_when="${2}"
                shift 2
                ;;
            *)
                host="${1}"
                shift 1
                ;;
        esac
    done

    # Validate the protocol
    case "${protocol}" in
        tcp | udp) ;;
        *)  echo "error: invalid protocol: ${protocol}" >&2
            return 1
            ;;
    esac

    # Parse host
    if [[ "${host}" =~ ^([^:]+)(:([0-9]+))?(\/.*)?$ ]]; then
        host="${BASH_REMATCH[1]}"
        port="${BASH_REMATCH[3]:-${port}}"
        path="${BASH_REMATCH[4]:-${path}}"
    else
        echo "error: invalid host: ${host}" >&2
        return 1
    fi

    # Setup colors for exec-socket. We have to do this here because exec-socket
    # will be running in a subshell and won't be able to accurately determine
    # how to handle "auto"
    if ((verbosity > 0)); then
        if [[ "${color_when}" == "auto" ]]; then
            [[ -t 1 ]] && color_when="always" || color_when="never"
        fi
    fi

    debug-vars protocol method host port path headers auth data \
        do_suppress_headers verbosity

    # Prepare the HTTP request
    local request="${method} ${path} HTTP/${http_version}"$'\r\n'
    ## Headers
    ### Default
    request_headers["host"]="${host}"
    request_headers["connection"]="close"
    request_headers["user-agent"]="${user_agent}"
    ### Add/Update custom headers
    for header in "${headers[@]}"; do
        local key="${header%%:*}"
        local value="${header#*: }"
        # If the value is empty, remove the header
        if [[ -z "${value}" ]]; then
            unset request_headers["${key,,}"]
        else
            request_headers["${key,,}"]="${value}"
        fi
    done
    ### Basic Authentication
    if [[ -n "${auth}" ]]; then
        request_headers["authorization"]="Basic $(generate-basic-auth ${auth})"
    fi
    ### Content length
    if [[ -n "${data}" ]]; then
        request_headers["content-length"]="${#data}"
    fi
    ### Add headers to the request
    for key in "${!request_headers[@]}"; do
        request+="${key}: ${request_headers[${key}]}"$'\r\n'
    done
    ## Data
    if [[ -n "${data}" ]]; then
        request+=$'\r\n'
        request+="${data}"
    fi
    request+=$'\r\n'

    debug-vars request

    # Use the exec-socket function to send the request and handle the response
    ((verbosity > 1)) && sock_args+=(-v)
    ((verbosity < 1)) && sock_args+=(-s)
    sock_args+=(
        -p "${protocol}"
        --color "${color_when}"
        "${host}" "${port}" "${request}"
    )
    while IFS= read -r line; do
        if ${do_suppress_headers} && ! ${response_headers_finished}; then
            if [[ -z "${line}" || "${line}" == $'\r' || "${line}" == $'\r\n' ]]; then
                response_headers_finished=true
            fi
            continue
        fi
        echo "${line}"
    done < <(exec-socket "${sock_args[@]}")
}

function exec-socket() {
    :  'Send arbitrary data over a tcp/udp socket

        @usage
            [-p/--protocol <protocol>] [-s/--silent] [-v/--verbose]
            [-c/--color <when>] [--no-color-response-body]
            [-t/--timeout <seconds>] <host> <port> <data>

        @optarg -p/--protocol <protocol>
            The protocol to use. Available options are tcp and udp. Defaults to
            tcp.

        @option -s/--silent
            Suppress all output.

        @option -v/--verbose
            Enable verbose output.

        @optarg -c/--color <when>
            Colorize the output. Available options are always, auto, and never.
            Defaults to auto.

        @option no-color-response-body
            Do not colorize the response body. This function will attempt to
            still colorize response headers if possible.

        @optarg -t/--timeout <seconds>
            The timeout for the connection. NOTE: This requires a dependency on
            the `timeout` command. (Not yet implemented)

        @arg <host>
            The host to send the data to.

        @arg <port>
            The port to send the data to.

        @arg <data>
            The data to send.

        @stdout
            The response from the server.

        @return 0
            The request was successful.

        @return 1
            The request failed.
    '
    # Default values
    local protocol="tcp"
    local host=""
    local port=""
    local data=""
    local timeout=""
    local timeout_cmd=()
    local output=""
    local fd=""
    local verbosity=1  # 0 = silent, 1 = normal, 2 = verbose
    local do_color=false
    local do_color_response_body=false
    local response_headers_finished=false
    local color_when="auto"

    # Parse arguments
    while [[ ${#} -gt 0 ]]; do
        case "${1}" in
            -p | --protocol)
                protocol="${2}"
                shift 2
                ;;
            -t | --timeout)
                timeout="${2}"
                echo "warning: --timeout not yet implemented" >&2
                shift 2
                ;;
            -s | --silent)
                verbosity=0
                shift 1
                ;;
            -v | --verbose)
                verbosity=2
                shift 1
                ;;
            -c | --color)
                color_when="${2}"
                shift 2
                ;;
            --no-color-response-body)
                do_color_response_body=false
                shift 1
                ;;
            --color-response-body)
                do_color_response_body=true
                shift 1
                ;;
            *)
                if [[ -z "${host}" ]]; then
                    host="${1}"
                elif [[ -z "${port}" ]]; then
                    port="${1}"
                elif [[ -z "${data}" ]]; then
                    data="${1}"
                else
                    echo "error: too many arguments" >&2
                    return 1
                fi
                shift 1
                ;;
        esac
    done

    # Validate the protocol
    case "${protocol}" in
        tcp | udp) ;;
        *)  echo "error: invalid protocol: ${protocol}" >&2
            return 1
            ;;
    esac

    # Validate the timeout
    if [[ -n "${timeout}" && ! "${timeout}" =~ ^[0-9]+$ ]]; then
        echo "error: invalid timeout: ${timeout}" >&2
        return 1
    fi

    # If suppressing all output, then redirect stdout and stderr
    if ((verbosity == 0)); then
        exec 3>&1 4>&2 1>/dev/null 2>&1
    else
        # Setup colors
        case "${color_when}" in
            always | yes)
                do_color=true
                ;;
            auto)
                [[ -t 1 ]] && do_color=true
                ;;
            never | no)
                do_color=false
                ;;
            *)
                echo "error: invalid color option: ${color_when}" >&2
                return 1
                ;;
        esac
        if ${do_color}; then
            setup-colors
            C_REQUEST="${C_CYAN}"
            C_REQUEST_PREFIX="${S_BOLD}${C_REQUEST}"
            C_RESPONSE="${C_GREEN}"
            C_RESPONSE_PREFIX="${S_BOLD}${C_RESPONSE}"
        else
            unset-colors
        fi
    fi

    debug-vars protocol host port data verbosity timeout do_color

    # Prepare the file descriptor
    fd="/dev/${protocol}/${host}/${port}"
    debug "setting up {net_fd}<>${fd}"
    if 2>/dev/null exec {net_fd}<>"${fd}"; then
        debug "net_fd: ${net_fd}"
    else
        echo "error: failed to open ${fd}" >&2
        return 1
    fi
    debug-vars net_fd

    # Set up cleanup traps on function return
    debug "setting up traps"
    ## restore stdout/stderr if silenced
    function unsilence() {
        [[ -t 3 ]] && exec 1>&3
        [[ -t 4 ]] && exec 2>&4
    }
    ## close the network file descriptor
    function close-netfd() {
        exec {net_fd}<&- || echo "error: failed to close net_fd" >&2
    }
    ## cleanup function
    function cleanup() {
        close-netfd
        unsilence
    }
    trap cleanup RETURN
    debug "traps complete"

    # If verbosity is enabled, print the data with a "> " prefix
    if ((verbosity > 1)); then
        debug "verbosely printing request data"
        while IFS= read -r line; do
            echo "${C_REQUEST_PREFIX}>${S_RESET} ${C_REQUEST}${line}${S_RESET}"
        done <<< "${data}"
    fi

    # Send the data
    debug "sending ${#data} bytes to &${net_fd}"
    debug-vars data
    printf '%s' "${data}" >&${net_fd}

    # Read and print the response
    local base_prefix prefix suffix
    ((verbosity > 1)) && base_prefix="< "
    if ${do_color}; then
        prefix="${C_RESPONSE_PREFIX}${base_prefix}${S_RESET}${C_RESPONSE}"
        suffix="${S_RESET}"
    else
        prefix="${base_prefix}"
    fi
    while IFS= read -r -u ${net_fd} line; do
        # debug-vars line
        # Attempt to determine when the response headers have finished (assuming
        # the protocol has headers)
        if ! ${response_headers_finished}; then
            if [[ -z "${line}" || "${line}" == $'\r' || "${line}" == $'\r\n' ]]; then
                response_headers_finished=true
                if ! ${do_color_response_body}; then
                    if ${do_color}; then
                        prefix="${C_RESPONSE_PREFIX}${base_prefix}${S_RESET}"
                        suffix=""
                    else
                        prefix="${base_prefix}"
                    fi
                fi
            fi
        fi
        printf "${prefix}%s${suffix}\n" "${line}"
    done
}
