: '
Azure DevOps Pipelines library

Provides convenience functions for interacting with Azure DevOps Pipelines.

# Startup

When this script is sourced or called directly:

* if called inside a pipeline *and* DEBUG is set
    * set AZURE_LOG_DIR to $(mktemp -d) if not already set
    * set DEBUG_LOG to "az-debug.log" if not already set
    * ensure AZURE_LOG_DIR exists, creating it if necessary
    * register a trap to upload logs to the CI system on exit

# Logging commands and functions

| Logging Command                  | Function             | Description                    |
|----------------------------------|----------------------|--------------------------------|
| ##[error]                        | az-error             | Log an error message           |
| ##[warning]                      | az-warning           | Log a warning message          |
| ##[info]                         | az-info              | Log an info message            |
| ##vso[task.logissue]             | az-logwarning        | Log a warning message          |
| ##vso[task.logissue]             | az-logerror          | Log an error message           |
| ##[section]                      | az-section           | Start a new section            |
| ##[group]                        | az-group             | Start a new group              |
| ##[endgroup]                     | az-endgroup          | End the current group          |
| ##vso[task.setprogress]          | az-progress          | Set the current progress       |
| ##vso[task.complete]             | az-complete          | Mark the task as complete      |
| ##vso[task.setvariable]          | az-setvariable       | Set a variable in the pipeline |
| ##vso[task.setsecret]            | az-secret            | Mark a value as a secret       |
| ##vso[task.addattachment]        | az-uploadattachment  | Upload an attachment           |
| ##vso[task.uploadsummary]        | az-uploadsummary     | Upload a summary file          |
| ##vso[task.uploadfile]           | az-uploadfile        | Upload a file                  |
| ##vso[task.uploadlog]            | az-uploadlog         | Upload a log file              |
| ##vso[artifact.upload]           | az-uploadartifact    | Upload an artifact             |
| ##vso[build.updatebuildnumber]   | az-updatebuildnumber | Override the build number      |
| ##vso[build.addbuildtag]         | az-addbuildtag       | Add a tag to the build         |
| ##vso[release.updatereleasename] | az-updatereleasename | Update the release name        |

# Custom functions

## upload-files()

Upload all files in the given arguments. If a directory is passed, all files
in the directory are uploaded recursively. These files are added to the
downloadable task logs accessible from the Azure DevOps Web UI on the build
page.

## upload-logs()

Upload all logs in the directory specified by AZURE_LOG_DIR. These logs are
added to the downloadable task logs accessible from the Azure DevOps Web UI on
the build page.
'
export AZURE_LOG_DIR="${AZURE_LOG_DIR:- $(mktemp -d)}"

function _az_logging() {
    :  'Print Azure DevOps logging commands

        Azure DevOps uses logging commands to provide rich information in the
        logs. These commands are in the format:
            ##${prefix}[${command}[ key=value;key=value;...]]${message}
        e.g.:
            ##[section]This is a section
            ##vso[task.logissue type=error]This is an error

        This function is a wrapper around the logging commands to include them
        in scripts in a more readable, script-friendly way.

        @usage
            [-p/--prefix <prefix>] [-o/--option <key=value>] [--<key>=<value>]
            [-m/--multiline] [-M/--no-multiline] <command>
            [<message> [<message> ...]]

        @option -p/--prefix <prefix>
            The prefix of the logging command. Default is an empty string.

        @option -o/--option <key=value>
            An option to include in the logging command. This can be repeated
            to include multiple options.

        @option --<key>=<value>
            An option to include in the logging command. This can be repeated
            to include multiple options.

        @arg <command>
            The command to include in the logging command.

        @optarg <message>
            An optional message to include in the logging command. If multiple
            messages are passed, each will be printed separately using the
            same command. Default is an empty string.

        @return
            1 if an error occurred parsing arguments, 0 otherwise.
    '
    local __prefix=""
    local __options=()
    local __opt_str=""
    local __command=""
    local __message __messages=()
    local __command_str=""
    local __do_multiline=false  # allow multiline values

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "${1}" in
            -p | --prefix)
                __prefix="${2}"
                shift 2
                ;;
            -o | --option)
                __options+=( "${2}" )
                shift 2
                ;;
            -m | --multiline)
                __do_multiline=true
                shift 1
                ;;
            -M | --no-multiline)
                __do_multiline=false
                shift 1
                ;;
            --*)
                # Allow for `--foo=bar` or `--foo bar` style options
                local __opt="${1:2}" # strip the leading `--`
                if [[ "${__opt}" =~ ^[-_A-Za-z0-9]+= ]]; then
                    __options+=( "${__opt}" )
                    shift 1
                else
                    __options+=( "${__opt}=${2}" )
                    shift 2
                fi
                ;;
            -*)
                az-error "error: unknown option: ${1}"
                return 1
                ;;
            *)
                if [[ -z "${__command}" ]]; then
                    __command="${1}"
                else
                    __messages+=( "${1}" )
                fi
                shift 1
        esac
    done

    # Require a command
    if [[ -z "${__command}" ]]; then
        az-error "error: missing required argument: <command>"
        return 1
    fi

    # Validate the value
    for __message in "${__messages[@]}"; do
        if ! ${__do_multiline} && [[ "${__message}" =~ [$'\n\f'] ]]; then
            az-warning "warning: must use --multiline for values with newlines"
            az-warning "warning: value: $(printf "%q" "${__message}")"
            return 1
        fi
    done

    # Build the command string
    ## prefix and command
    __command_str="##${__prefix}[${__command}"
    ## options
    if (( ${#__options[@]} > 0 )); then
        __opt_str=$(IFS=";"; echo "${__options[*]}")
        __command_str+=" ${__opt_str}"
    fi
    __command_str+="]"

    # Print the command and messages
    printf "%s\n" "${__messages[@]}" \
        | awk -v cmd="${__command_str}" '{print cmd $0}'
}


# ------------------------------------------------------------------------------
# Logging functions
# ------------------------------------------------------------------------------

function az-error() { _az_logging --multiline error "${@}"; }
function az-warning() { _az_logging warning "${@}"; }
function az-info() { _az_logging info "${@}"; }

# ---- task.logissue -----------------------------------------------------------
# Options:
#   * --sourcepath <path> : The path to the file that contains the issue.
#   * --linenumber <number> : The line in the file that contains the issue.
#   * --columnnumber <number> : The column in the file that contains the issue.
#   * --code <code> : Error or warning code.
# Message: The message to log.
function az-logwarning() {
    _az_logging --prefix vso --type=warning task.logissue "${@}"
}
function az-logerror() {
    _az_logging --prefix vso --type=error task.logissue "${@}"
}
function az-errorlog() { az-logerror "${@}"; } # for backwards compatibility


# ------------------------------------------------------------------------------
# Grouping functions
# ------------------------------------------------------------------------------

function az-section() { _az_logging section "${@}"; }
function az-group() { _az_logging group "${*}"; }
function az-endgroup() { _az_logging endgroup "${*}"; }


# ------------------------------------------------------------------------------
# Status functions
# ------------------------------------------------------------------------------

# ---- task.setprogress --------------------------------------------------------
# Options:
#   * --value <value> : The current progress value (1-100).
# Message: Label for the current operation
function az-progress() { _az_logging task.setprogress "${@}"; }

# ---- task.complete -----------------------------------------------------------
# Options:
#   * --result <result>
#     * Succeeded : The task succeeded
#     * SucceededWithIssues : The task ran into problems. The build will be
#       completed as partially succeeded at best.
#     * Failed : The build will be completed as failed. If the "Continue on
#       Error" option is selected, the build will be completed as partially
#       succeeded at best.
# Message: A completion message to log
function az-complete() { _az_logging task.complete "${@}"; }
function az-complete-success() { az-complete --result Succeeded; }
function az-complete-failure() { az-complete --result Failed; }
function az-complete-with-issues() { az-complete --result SucceededWithIssues; }


# ------------------------------------------------------------------------------
# Variable functions
# ------------------------------------------------------------------------------

# ---- task.setvariable --------------------------------------------------------
# Options:
#   * --variable  <name> : The name of the variable to set.
#   * --issecret <bool> : Whether to mark the variable as a secret.
#   * --isoutput <bool> : Whether to mark the variable as an output variable.
#   * --isreadonly <bool> : Whether to mark the variable as read-only.
# Message: The value to set for the variable.
function az-setvariable() {
    :  'task.setvariable: Set a variable in the pipeline

        Sets a variable in the pipeline using the task.setvariable logging
        command. This produces an echo statement in the format:
            ##vso[task.setvariable variable=${name}]${value}

        @usage
            [--name <name>] [--value <value>] [--output] [--secret]
            [<name> [<value>]]

        @option --name <name>
            The name of the variable to set.

        @option --value <value>
            The value of the variable to set.

        @option --output
            If set, the variable will be marked as an output variable.

        @option --secret
            If set, the variable will be marked as a secret variable.

        @optarg <name>
            The name of the variable to set.

        @optarg <value>
            The value of the variable to set.

        @return
            1 if an unknown argument is passed, 0 otherwise.
    '
    # Default values
    local name=""
    local value=""
    local is_output=false
    local is_secret=false

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
            --secret)
                is_secret=true
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

    _az_logging \
        --prefix vso \
        --variable="${name}" \
        --isOutput="${is_output}" \
        --isSecret="${is_secret}" \
        task.setvariable "${value}"
}

# ---- task.setsecret ----------------------------------------------------------
function az-secret() { _az_logging task.setsecret "${*}"; }


# ------------------------------------------------------------------------------
# File upload
# ------------------------------------------------------------------------------

# ---- task.addattachment ------------------------------------------------------
# Upload an attachment to the build (not downloadable with the task logs)
# Options:
#   * --type <type> : The type of the attachment.
#   * --name <name> : The name of the attachment.
# Message: The path to the attachment.
function az-uploadattachment() { _az_logging task.addattachment "${@}"; }

# ---- task.uploadsummary ------------------------------------------------------
# Upload a markdown file as the build summary
# Message: The path to the markdown file
function az-uploadsummary() { _az_logging task.uploadsummary "${@}"; }

# ---- task.uploadfile ---------------------------------------------------------
# Upload a file to be downloaded with task logs
# Message: The path to the file
function az-uploadfile() { _az_logging task.uploadfile "${@}"; }

# ---- task.uploadlog ----------------------------------------------------------
# Upload a log file to the build
# Message: The path to the log file
function az-uploadlog() { _az_logging task.uploadlog "${@}"; }

# ---- artifact.upload ---------------------------------------------------------
# Upload an artifact to the build
# Options:
#   * --containerfolder <folder> : The folder in the artifact to upload to.
#   * --artifactname <name> : The name of the artifact.
# Message: The local path to the artifact
function az-uploadartifact() { _az_logging artifact.upload "${@}"; }


# ------------------------------------------------------------------------------
# Build and release functions
# ------------------------------------------------------------------------------

# ---- build.updatebuildnumber -------------------------------------------------
# Override the build number
# Message: The new build number
function az-updatebuildnumber() { _az_logging build.updatebuildnumber "${@}"; }

# ---- build.addbuildtag -------------------------------------------------------
# Add a tag to the build
# Message: The tag to add
function az-addbuildtag() { _az_logging build.addbuildtag "${@}"; }

# ---- release.updatereleasename -----------------------------------------------
# Update the release name
# Message: The new release name
function az-updatereleasename() { _az_logging release.updatereleasename "${@}"; }


# ------------------------------------------------------------------------------
# Custom functions
# ------------------------------------------------------------------------------

function _in_azure_pipelines() {
    :  'Check if the script is running in an Azure DevOps pipeline'
    declare -p AGENT_ID SYSTEM_JOBID &>/dev/null
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


# ------------------------------------------------------------------------------
# Startup
# ------------------------------------------------------------------------------

# If we're running in an Azure DevOps pipeline environment and DEBUG is set:
# 1. Set DEBUG_LOG to /tmp/az-debug.log
# 2. Register a trap to upload the debug log to the CI system
if _in_azure_pipelines; then
    # We're in an Azure DevOps pipeline
    if [[ -n "${DEBUG}" ]]; then
        if [[ -z "${DEBUG_LOG}" ]]; then
            export DEBUG_LOG="${AZURE_LOG_DIR}/az-debug.log"
        fi
        trap 'upload-logs "${AZURE_LOG_DIR}"' EXIT
    fi
fi