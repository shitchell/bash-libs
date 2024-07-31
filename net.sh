: '
Network related functions
'

include-source 'debug'

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
            [-u/--user <user:password>] [-p/--protocol <protocol>]
            [-S/--suppress-headers] [-s/--silent] <host>[:<port>][/<path>]

        @optarg -X/--request <method>
            The request method to use. Defaults to GET.

        @optarg -H/--header <header>
            Additional headers to include in the request. Can be used multiple
            times. Syntax is "<header>: <value>".

        @optarg -d/--data <data>
            Data to send in the request body. Only applicable to POST requests.

        @optarg -u/--user <user:password>
            Basic authentication credentials to use.

        @optarg -p/--protocol <protocol>
            The protocol to use (used under /dev). Available options are tcp and
            udp. Defaults to tcp.

        @optarg -S/--suppress-headers
            Suppress response headers.

        @optarg -s/--silent
            Suppress all output.

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
    local auth_header=""
    local protocol="tcp"
    local host=""
    local port=80
    local path="/"
    local do_suppress_headers=false
    local do_silent=false
    local response_headers_finished=false

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
                do_silent=true
                shift 1
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

    # If suppressing all output, then redirect stdout and stderr
    if ${do_silent}; then
        exec 3>&1 4>&2 1>/dev/null 2>&1
    fi

    # Parse host
    if [[ "${host}" =~ ^([^:]+)(:([0-9]+))?(\/.*)?$ ]]; then
        host="${BASH_REMATCH[1]}"
        port="${BASH_REMATCH[3]:-${port}}"
        path="${BASH_REMATCH[4]:-${path}}"
    else
        echo "error: invalid host: ${host}" >&2
        return 1
    fi

    debug-vars protocol method host port path headers auth data \
        do_suppress_headers do_silent

    # Prepare request
    local request="${method} ${path} HTTP/1.1"$'\r\n'
    request+="Host: ${host}"$'\r\n'
    request+="Connection: close"$'\r\n'
    request+="User-Agent: bash"$'\r\n'
    ## Custom Headers
    for header in "${headers[@]}"; do
        request+="${header}"$'\r\n'
    done
    ## Basic Authentication
    if [[ -n "${auth}" ]]; then
        auth_header="Authorization: Basic $(generate-basic-auth ${auth})"$'\r\n'
        request+="${auth_header}"
    fi
    ## Data
    if [[ -n "${data}" ]]; then
        request+="Content-Length: ${#data}"$'\r\n'
        request+="${data}"$'\r\n'
    fi
    request+=$'\r\n'
    
    debug-vars request

    # Prepare the file descriptor
    exec {net_fd}<>/dev/tcp/${host}/${port}
    debug-vars net_fd

    # Set up cleanup traps on function return
    ## Fix stdout/stderr if `--silent` was used
    function unsilent() {
        [[ -t 3 ]] && exec 1>&3 || echo "no &3"
        [[ -t 4 ]] && exec 2>&4 || echo "no &4"
    }
    ## Close the file descriptor
    function close-netfd() {
        exec {net_fd}<&- || echo "error: failed to close net_fd" >&2
    }
    ## Combined trap
    function cleanup() {
        close-netfd
        unsilent
    }
    trap cleanup RETURN

    # Send the request
    printf '%s' "${request}" >&"${net_fd}"

    # Read and print the response
    while IFS= read -r -u "${net_fd}" line; do
        if ${do_suppress_headers} && ! ${response_headers_finished}; then
            if [[ -z "${line}" || "${line}" == $'\r' || "${line}" == $'\r\n' ]]; then
                response_headers_finished=true
            fi
            continue
        fi
        printf '%s\n' "${line}"
    done
}

function exec-socket() {
    :  'Send arbitrary data over a tcp/udp socket

        @usage
            [-p/--protocol <protocol>] [-s/--silent] [-v/--verbose]
            <host> <port> <data>

        @optarg -p/--protocol <protocol>
            The protocol to use. Available options are tcp and udp. Defaults to
            tcp.

        @optarg -s/--silent
            Suppress all output.

        @optarg -v/--verbose
            Enable verbose output.

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
    local verbosity=1  # 0 = silent, 1 = normal, 2 = verbose

    # Parse arguments
    while [[ ${#} -gt 0 ]]; do
        case "${1}" in
            -p | --protocol)
                protocol="${2}"
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
            *)
                host="${1}"
                port="${2}"
                data="${3}"
                break
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

    # If suppressing all output, then redirect stdout and stderr
    if ((verbosity == 0)); then
        exec 3>&1 4>&2 1>/dev/null 2>&1
    fi

    debug-vars protocol host port data verbosity

    # Prepare the file descriptor
    exec {net_fd}<>"/dev/${protocol}/${host}/${port}"

    # Set up cleanup traps on function return
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

    # If verbosity is enabled, print the data with a "> " prefix
    if ((verbosity > 1)); then
        while IFS= read -r line; do
            printf '> %s\n' "${line}"
        done <<< "${data}"
    fi

    # Send the data
    printf '%s' "${data}" >&${net_fd}

    # Read and print the response
    local prefix
    ((verbosity > 1)) && prefix="< "
    while IFS= read -r -u ${net_fd} line; do
        printf "${prefix}%s\n" "${line}"
    done
}
