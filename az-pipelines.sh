AZURE_LOG_DIR="${AZURE_LOG_DIR:- $(mktemp -d)}"

function _az_logging() {
    command="${1}" && shift
    printf '%s\n' "${@}" \
        | awk -v cmd="${command}" '{print "##[" cmd "]" $0}' >&2
}
function az-error() { _az_logging error "${@}"; }
function az-errorlog() {
  echo "##vso[task.logissue type=error]${*}" >&2
}
function az-warning() { _az_logging warning "${@}"; }
function az-info() { _az_logging info "${@}"; }
function az-section() { _az_logging section "${@}"; }
function az-group() { _az_logging group "${*}"; }
function az-endgroup() { _az_logging endgroup "${*}"; }

function az-setvariable() {
    # Default values
    local name=""
    local value=""
    local is_output=false

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "${1}" in
            --name)
                name="${2}"
                shift 2
                ;;
            --value)
                value="${2}"
                shift 2
                ;;
            --output)
                is_output=true
                shift 1
                ;;
            *)
                if [[ -z "${name}" ]]; then
                    name="${1}"
                elif [[ -z "${value}" ]]; then
                    value="${1}"
                else
                    az-error "error: unknown argument: ${1}"
                    return 1
                fi
                shift 1
        esac
    done

    echo "##vso[task.setvariable variable=${name};isOutput=${is_output}]${value}"
}

function _get_all_files() {
    :  'Given a directory, return all files in it'
    local dir="${1}"
    shopt -s nullglob
    local files=("${dir}"/*)
    for file in "${files[@]}"; do
        if [[ -d "${file}" ]]; then
            _get_all_files "${file}"
        else
            echo "${file}"
        fi
    done
}

function upload-files() {
    :  'Upload all files in the given arguments'
    local args=( "${@}" )
    local files=() dir_files=()

    # Recursively collect all files from the args
    for arg in "${args[@]}"; do
        if [[ -f "${arg}" ]]; then
            files+=( "${arg}" )
        elif [[ -d "${arg}" ]]; then
            readarray -t dir_files < <(_get_all_files "${arg}")
            files+=( "${dir_files[@]}" )
        fi
    done

    # Upload each file
    for file in "${files[@]}"; do
        if [[ -f "${file}" ]]; then
            # File found, upload it
            echo "##vso[task.uploadfile]${file}"
        fi
    done
    echo "Done"
}

function upload-logs() {
    :  'Upload all files in the log directory'
    local log_dir="${1:-${AZURE_LOG_DIR}}"
    upload-files "${log_dir}"

    # If DEBUG_LOG is set, upload it as well
    if [[ -n "${DEBUG_LOG}" && -f "${DEBUG_LOG}" ]]; then
        upload-files "${DEBUG_LOG}"
    fi
}

# If we're running in an Azure DevOps pipeline environment and DEBUG is set:
# 1. Set DEBUG_LOG to /tmp/az-debug.log
# 2. Register a trap to upload the debug log to the CI system
if declare -p AGENT_ID SYSTEM_JOBID &>/dev/null; then
    # We're in an Azure DevOps pipeline
    if [[ -n "${DEBUG}" ]]; then
        if [[ -z "${DEBUG_LOG}" ]]; then
            export DEBUG_LOG="${AZURE_LOG_DIR}/az-debug.log"
        fi
        trap 'upload-logs "${AZURE_LOG_DIR}"' EXIT
    fi
fi