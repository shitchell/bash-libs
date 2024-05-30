#!/usr/bin/env bash
#
# Trinoor Deployments - Deploy
#
# @author Shaun Mitchell
# @date   2023-06-06
#
# This script is part of the Trinoor Deployments project. It deploys files from
# a source directory to a target directory using a provided `git --name-status`
# or `git --name-only` style changelog to determine which files to deploy.

## imports #####################################################################
################################################################################

# Ensure the `include-source` function is available
[[ -z "${INCLUDE_SOURCE}" ]] && {
    source "${BASH_LIB_PATH%%:*}/include.sh" || {
        echo "error: cannot source required libraries" >&2
        exit 1
    }
}

include-source 'changelogs.sh'
include-source 'debug.sh'
include-source 'echo.sh'
include-source 'as-common.sh'


## exit codes ##################################################################
################################################################################

declare -ri E_SUCCESS=0
declare -ri E_ERROR=1
declare -ri E_PERMISSION_DENIED=2


## traps #######################################################################
################################################################################

# @description Silence all output
# @usage silence-output
function silence-output() {
    exec 3>&1 4>&2 1>/dev/null 2>&1
}

# @description Restore stdout and stderr
# @usage restore-output
function restore-output() {
    [[ -t 3 ]] && exec 1>&3 3>&-
    [[ -t 4 ]] && exec 2>&4 4>&-
}

# @description Exit trap
function trap-exit() {
    restore-output
}
trap trap-exit EXIT


## colors ######################################################################
################################################################################

# Determine if we're in a terminal
[[ -t 1 ]] && __IN_TERMINAL=true || __IN_TERMINAL=false

# @description Set up color variables
# @usage setup-colors
function setup-colors() {
    C_RED=$'\e[31m'
    C_GREEN=$'\e[32m'
    C_YELLOW=$'\e[33m'
    C_BLUE=$'\e[34m'
    C_MAGENTA=$'\e[35m'
    C_CYAN=$'\e[36m'
    C_WHITE=$'\e[37m'
    S_RESET=$'\e[0m'
    S_BOLD=$'\e[1m'
    S_DIM=$'\e[2m'
    S_UNDERLINE=$'\e[4m'
    S_BLINK=$'\e[5m'
    S_INVERT=$'\e[7m'
    S_HIDDEN=$'\e[8m'

    # Color aliases
    C_ERROR="${C_RED}"
    C_SUCCESS="${C_GREEN}"
    C_WARNING="${C_YELLOW}"
    C_INFO="${C_BLUE}"
    C_COUNT="${C_CYAN}"
    C_FILEPATH="${C_MAGENTA}"
    C_DIRECTORY="${C_MAGENTA}${S_BOLD}"
}

# @description Unset color variables
# @usage unset-colors
function unset-colors() {
    unset C_RED C_GREEN C_YELLOW C_BLUE C_MAGENTA C_CYAN C_WHITE \
          S_RESET S_BOLD S_DIM S_UNDERLINE S_BLINK S_INVERT S_HIDDEN
}


## usage functions #############################################################
################################################################################

function help-usage() {
    echo "usage: $(basename "${0}") [-h/--help] [-c/--color <when>]"
    echo "       [-s/--silent] [-x/--exclude <regex>] [-v/--validate-status]"
    echo "       [-b/--preserve-bits] [-o/--preserve-owner] [-g/--preserve-group]"
    echo "       [--all] [--delete-missing]"
    echo "       --source <source> --target <target> [file...]"
}

function help-epilogue() {
    echo "deploy files from a source directory to a target directory"
}

function help-full() {
    help-usage
    help-epilogue
    echo
    echo "Files to be copied can be specified as arguments or listed in a"
    echo "changelog file. If both are provided, they will be combined. If a"
    echo "\`git --name-status\` changelog is provided, the file status can"
    echo "optionally be validated when copying files (i.e.: verifying that a"
    echo "file marked as deleted in the changelog is not present in the source"
    echo "directory and is deleted from the target directory)."
    echo
    echo "If a changelog is not provided, no action will be taken unless the"
    echo "\`--all\` option is specified, in which case all files in the source"
    echo "directory will be copied to the target directory, optionally deleting"
    echo "files in the target directory that are not in the source directory."
    echo
    echo "Deployments can be customized through the use of various hooks:"
    echo "  - \`pre-run\`:"
    echo "    run before any files are copied, passed all arguments. if the"
    echo "    hook returns a non-zero exit code, no files will be copied"
    echo "  - \`pre-deploy\`:"
    echo "    run before each file is copied, passed all options and the file"
    echo "    to be copied as the only argument. if the hook returns a non-zero"
    echo "    exit code, the file will not be copied"
    echo "  - \`post-deploy\`:"
    echo "    run after each file is copied, passed all options and the file"
    echo "    that was copied as the only argument. if the hook returns a"
    echo "    non-zero exit code, the original file will be restored"
    echo "  - \`post-run\`:"
    echo "     run after all files are copied, passed all arguments. if the"
    echo "     hook returns a non-zero exit code, all files will be restored"
    echo "     from the backup"
    echo
    echo "Files will be backed up to a temporary directory before being copied"
    echo "to the target directory unless the \`--no-backups\` option is used."
    echo "The backup directory can be specified with the \`--backup-dir\`"
    echo "option."
    echo
    echo "Options:"
    cat << EOF
    -h                        display usage
    --help                    display this help message
    --config-file <file>      use the specified configuration file
    -c/--color <when>         when to use color ("auto", "always", "never")
    -s/--silent               suppress all output
    -n/--dry-run              do not copy files, just print what would be done
    --changelog <file>        use the specified changelog file
    --source <source>         source directory
    --target <target>         target directory
    --db-connect-string <string>
                              SQL*Plus connect string for database scripts
    --backup-dir <directory>  backup files to <directory> before copying
    --no-backups              do not create backups before copying files
    -x/--exclude <regex>      exclude files matching the specified regex
    -v/--validate-status      if the changelog is a name-status changelog,
                              validate the change status when copying files
    -V/--no-validate-status   do not validate the change status
    -b/--preserve-bits        preserve file bits when copying files
    -B/--no-preserve-bits     do not preserve file bits when copying files
    -o/--preserve-owner       preserve file owner when copying files
    -O/--no-preserve-owner    do not preserve file owner when copying files
    -g/--preserve-group       preserve file group when copying files
    -G/--no-preserve-group    do not preserve file group when copying files
    -p/--preserve-all         preserve all file attributes when copying files
    -P/--no-preserve-all      do not preserve any file attributes when copying
    --chown <owner:group>     specify the owner and group of the copied files
    --chmod <mode>            specify the mode of the copied files
    --all                     deploy all files, ignoring the changelog
    --delete-missing          delete files in the target directory that are not
                              in the source directory (requires --all)
    --no-delete-missing       do not delete files in the target directory that
                              are not in the source directory (default)
EOF
    echo
    echo "Custom configurations:"
    cat << EOF
    --pre-run <command>       a command to run before any files are copied
    --pre-deploy <command>    a command to run before each file is copied
    --post-deploy <command>   a command to run after each file is copied
    --post-run <command>      a command to run after all files are copied
EOF
}

function parse-args() {
    debug "parsing arguments: ${*}"

    # Parse the arguments first for a config file to load default values from
    CONFIG_FILE="./devops/tdeploy.conf"
    for ((i=0; i<${#}; i++)); do
        case "${!i}" in
            -c | --config-file)
                let i++
                CONFIG_FILE="${!i}"
                ;;
        esac
    done
    if [[ -f "${CONFIG_FILE}" ]]; then
        debug "loading config file: ${CONFIG_FILE}"
        source "${CONFIG_FILE}"
    fi

    # Default values
    FILEPATHS=()
    DO_DRY_RUN=false
    local color_when="${DO_COLOR:-auto}" # auto, on, yes, always, off, no, never
    DO_COLOR=false
    DO_SILENT=false
    CHANGELOG=""
    CHANGELOG_FILEPATH="${CHANGELOG_FILEPATH}"
    SOURCE_DIR="${SOURCE_DIR:-.}"
    TARGET_DIR="${TARGET_DIR}"
    DB_CONNECT_STRING="${DB_CONNECT_STRING}"
    BACKUP_DIR="${BACKUP_DIR}"
    DO_BACKUPS="${DO_BACKUPS:-true}"
    EXCLUDE_PATTERNS=( "${EXCLUDE_PATTERNS[@]}" )
    DO_VALIDATE_STATUS="${DO_VALIDATE_STATUS:-false}"
    DO_PRESERVE_BITS="${DO_PRESERVE_BITS:-false}"
    DO_PRESERVE_OWNER="${DO_PRESERVE_OWNER:-false}"
    DO_PRESERVE_GROUP="${DO_PRESERVE_GROUP:-false}"
    FILE_OWNER="${FILE_OWNER}"
    FILE_GROUP="${FILE_GROUP}"
    FILE_MODE="${FILE_MODE}"
    DO_DEPLOY_ALL="${DO_DEPLOY_ALL:-false}"
    DO_DELETE_MISSING="${DO_DELETE_MISSING:-false}"
    DIRECTORY_MAPPINGS=( "${DIRECTORY_MAPPINGS[@]}" )
    if [[ -z "${DIRECTORY_MAPPINGS[@]}" ]]; then
        DIRECTORY_MAPPINGS=(
            "^app_config/.*:/abb/assetsuite/config_templates"
        )
    fi
    debug-vars DIRECTORY_MAPPINGS

    # Hooks
    HOOK_ARGS=()
    HOOK_PRE_RUN=( "${PRE_RUN[@]}" )
    HOOK_PRE_DEPLOY=( "${PRE_DEPLOY[@]}" )
    HOOK_POST_DEPLOY=( "${POST_DEPLOY[@]}" )
    HOOK_POST_RUN=( "${POST_RUN[@]}" )

    # Loop over the arguments
    while [[ ${#} -gt 0 ]]; do
        case ${1} in
            -h)
                help-usage
                help-epilogue
                exit ${E_SUCCESS}
                ;;
            --help)
                help-full
                exit ${E_SUCCESS}
                ;;
            --config-file)
                shift 1
                ;;
            -c | --color)
                color_when="${2}"
                HOOK_ARGS+=( "${1}" "${2}" )
                shift 1
                ;;
            -s | --silent)
                DO_SILENT=true
                HOOK_ARGS+=( "${1}" )
                ;;
            -n | --dry-run)
                DO_DRY_RUN=true
                HOOK_ARGS+=( "${1}" )
                ;;
            --changelog)
                CHANGELOG_FILEPATH="${2}"
                HOOK_ARGS+=( "${1}" "${2}" )
                shift 1
                ;;
            --source)
                SOURCE_DIR="${2}"
                HOOK_ARGS+=( "${1}" "${2}" )
                shift 1
                ;;
            --target)
                TARGET_DIR="${2}"
                HOOK_ARGS+=( "${1}" "${2}" )
                shift 1
                ;;
            --db-connect-string)
                DB_CONNECT_STRING="${2}"
                HOOK_ARGS+=( "${1}" "${2}" )
                shift 1
                ;;
            --backup-dir)
                BACKUP_DIR="${2}"
                HOOK_ARGS+=( "${1}" "${2}" )
                shift 1
                ;;
            --no-backups)
                DO_BACKUPS=false
                HOOK_ARGS+=( "${1}" )
                ;;
            -x | --exclude)
                EXCLUDE_PATTERNS+=( "${2}" )
                HOOK_ARGS+=( "${1}" "${2}" )
                shift 1
                ;;
            -v | --validate-status)
                DO_VALIDATE_STATUS=true
                HOOK_ARGS+=( "${1}" )
                ;;
            -V | --no-validate-status)
                DO_VALIDATE_STATUS=false
                HOOK_ARGS+=( "${1}" )
                ;;
            -b | --preserve-bits)
                DO_PRESERVE_BITS=true
                FILE_MODE=""
                HOOK_ARGS+=( "${1}" )
                ;;
            -B | --no-preserve-bits)
                DO_PRESERVE_BITS=false
                HOOK_ARGS+=( "${1}" )
                ;;
            -o | --preserve-owner)
                DO_PRESERVE_OWNER=true
                HOOK_ARGS+=( "${1}" )
                ;;
            -O | --no-preserve-owner)
                DO_PRESERVE_OWNER=false
                HOOK_ARGS+=( "${1}" )
                ;;
            -g | --preserve-group)
                DO_PRESERVE_GROUP=true
                HOOK_ARGS+=( "${1}" )
                ;;
            -G | --no-preserve-group)
                DO_PRESERVE_GROUP=false
                HOOK_ARGS+=( "${1}" )
                ;;
            -p | --preserve-all)
                DO_PRESERVE_BITS=true
                DO_PRESERVE_OWNER=true
                DO_PRESERVE_GROUP=true
                FILE_MODE=""
                HOOK_ARGS+=( "${1}" )
                ;;
            -P | --no-preserve-all)
                DO_PRESERVE_BITS=false
                DO_PRESERVE_OWNER=false
                DO_PRESERVE_GROUP=false
                HOOK_ARGS+=( "${1}" )
                ;;
            --chown)
                FILE_OWNER="${2%%:*}"
                FILE_GROUP="${2##*:}"
                HOOK_ARGS+=( "${1}" "${2}" )
                shift 1
                ;;
            --chmod)
                FILE_MODE="${2}"
                PRESERVE_BITS=false
                HOOK_ARGS+=( "${1}" "${2}" )
                shift 1
                ;;
            --all)
                DO_DEPLOY_ALL=true
                HOOK_ARGS+=( "${1}" )
                ;;
            --delete-missing)
                DO_DELETE_MISSING=true
                HOOK_ARGS+=( "${1}" )
                ;;
            --no-delete-missing)
                DO_DELETE_MISSING=false
                HOOK_ARGS+=( "${1}" )
                ;;
            --pre-run)
                HOOK_PRE_RUN+=( "${2}" )
                HOOK_ARGS+=( "${1}" "${2}" )
                shift 1
                ;;
            --pre-deploy)
                HOOK_PRE_DEPLOY+=( "${2}" )
                HOOK_ARGS+=( "${1}" "${2}" )
                shift 1
                ;;
            --post-deploy)
                HOOK_POST_DEPLOY+=( "${2}" )
                HOOK_ARGS+=( "${1}" "${2}" )
                shift 1
                ;;
            --post-run)
                HOOK_POST_RUN+=( "${2}" )
                HOOK_ARGS+=( "${1}" "${2}" )
                shift 1
                ;;
            --)
                shift 1
                break
                ;;
            -*)
                echo "error: unknown option: ${1}" >&2
                return ${E_ERROR}
                ;;
            *)
                FILEPATHS+=("${1}")
                ;;
        esac
        shift 1
    done

    # If -- was used, collect the remaining arguments
    while [[ ${#} -gt 0 ]]; do
        FILEPATHS+=("${1}")
        shift 1
    done

    # If in silent mode, silence the output
    ${DO_SILENT} && silence-output

    # Set up colors
    if ! ${DO_SILENT}; then
        case "${color_when}" in
            on | yes | always)
                DO_COLOR=true
                ;;
            off | no | never)
                DO_COLOR=false
                ;;
            auto)
                if ${__IN_TERMINAL}; then
                    DO_COLOR=true
                else
                    DO_COLOR=false
                fi
                ;;
            *)
                echo "error: invalid color mode: ${color_when}" >&2
                return ${E_ERROR}
                ;;
        esac
        ${DO_COLOR} && setup-colors || unset-colors
    fi

    # If no target directory is provided, print an error and exit
    if [[ -z "${TARGET_DIR}" ]]; then
        echo "error: no target directory provided" >&2
        return ${E_ERROR}
    fi

    # Noramlize the source and target directories
    SOURCE_DIR=$(realpath "${SOURCE_DIR}")
    TARGET_DIR=$(realpath "${TARGET_DIR}")

    # If no changelog or filepaths are provided, ensure that --all is set
    if ! ${DO_DEPLOY_ALL} && [[
        -z "${CHANGELOG_FILEPATH}" && ${#FILEPATHS[@]} -eq 0
    ]]; then
        echo "error: must use \`--all\` if no changelog is provided" >&2
        return ${E_ERROR}
    fi

    if ! ${DO_DEPLOY_ALL}; then
        # Read the changelog and passed filepaths into a single array
        if [[ -n "${CHANGELOG_FILEPATH}" ]]; then
            readarray -t CHANGELOG < "${CHANGELOG_FILEPATH}" || {
                echo "error: cannot read changelog: ${CHANGELOG_FILEPATH}" >&2
                return ${E_ERROR}
            }
        fi
        CHANGELOG+=( "${FILEPATHS[@]}" )
    else
        # If deploying all files, build a changelog between the source and
        # target directories
        debug "building changelog for all files"
        if [[ -n "${CHANGELOG_FILEPATH}" ]]; then
            echo "warning: ignoring changelog file when using \`--all\`" >&2
        fi
        local line
        while read -r line; do
            mode="${line:0:1}"
            # If --delete-missing is not set, skip deleted files
            if ! ${DO_DELETE_MISSING} && [[ "${mode}" == "D" ]]; then
                continue
            fi
            CHANGELOG+=( "${line}" )
        done < <(
            generate-changelog "${TARGET_DIR}" "${SOURCE_DIR}"
        )
    fi

    # If no backup directory is specified, create a temporary one
    if [[ -z "${BACKUP_DIR}" ]]; then
        BACKUP_DIR=$(mktemp -d -t "tdeploy-XXXXXX") || {
            echo "error: cannot create temporary backup directory" >&2
            return ${E_ERROR}
        }
    fi

    # If an owner or group is specified, validate and combine them
    if [[ -n "${FILE_OWNER}" ]]; then
        # Validate the owner
        if ! id -u "${FILE_OWNER}" &>/dev/null; then
            echo "error: invalid owner: ${FILE_OWNER}" >&2
            return ${E_ERROR}
        fi
    fi
    if [[ -n "${FILE_GROUP}" ]]; then
        # Validate the group
        if ! getent group "${FILE_GROUP}" &>/dev/null; then
            echo "error: invalid group: ${FILE_GROUP}" >&2
            return ${E_ERROR}
        fi
    fi
    if [[ -n "${FILE_OWNER}" || -n "${FILE_GROUP}" ]]; then
        FILE_OWNERSHIP="${FILE_OWNER}:${FILE_GROUP}"
    fi

    return ${E_SUCCESS}
}


## helpful functions ###########################################################
################################################################################

# @description header alias
function header() {
    local before_margin=1
    [[ -z "${IS_FIRST_HEADER}" ]] && before_margin=0 && IS_FIRST_HEADER=false
    print-header \
        --underline \
        --border-character '-' \
        -A 1 -B ${before_margin} \
        "${@}"
}

# @description Return true if the line contains a SQL error
function contains-sql-error() {
    # Receive the line as an argument
    line="${1}"

    # Ensure the line conforms to the expected format
    if [[ "${line}" =~ ^([A-Za-z0-9*]+)"-"[0-9]+": " ]]; then
        # Extract the error code category
        # error_code=$(sed -E 's/^([A-Za-z0-9*]+)-([0-9]+): .*$/\1/' <<< "${line}")
        error_code="${BASH_REMATCH[1]}"
        # Ensure the error code category is one we are interested in
        case "${error_code}" in
            ACFS | ACFSK | ADVM | ADVMK | AMDU | ASMCMD | CAT | CLSCH \
            | CLSDNSSD | CLSGN | CLSMDNS | CLSNS | CLSR | CLSRSC | CLSS | CLST \
            | CLSU | CLSW | CLSWS | CLSX | CLSZM | CPY | CRJA | CRS | CSKM | DBT \
            | DBV | DCS | DGM | DIA | DRG | EVM | EXP | GIMR | GIPC | HAMI \
            | IMP | INS | JMS | JWC | JZN | KFED | KFNDG | KFOD | KUP | LCD | LFI \
            | LPX | LRM | LSX | MGTCA | NCR | NDFN | NID | NMP | NNC | NNF \
            | NNL | NNO | NPL | NZE | O2F | O2I | O2U | OCI | ODIG | OKA | OKSK \
            | ORA | ORADNFS | PCC | PGA | PGU | PLS | PLW | PRCA | PRCC | PRCD \
            | PRCE | PRCF | PRCG | PRCH | PRCI | PRCN | PRCO | PRCR | PRCS | PRCT \
            | PRCV | PRCW | PRCZ | PRGC | PRGD | PRGG | PRGH | PRGO | PRGP \
            | PRGR | PRGS | PRGT | PRGZ | PRIF | PRKA | PRKC | PRKE | PRKF | PRKH \
            | PRKN | PRKO | PRKP | PRKR | PRKU | PRKZ | PROC | PROCL | PROT \
            | PROTL | PRVE | PRVF | PRVG | PRVH | PRVP | QSM | RDE | RDJ | RMAN \
            | SBT | SCLC | SCLS | SP2 | SQL | SQL*Loader | TNS | UDE | UDI | WLMD \
            | WLMF | WLMV | XAG | XOQ)
                # This is an error we are interested in, return true
                return 0
                ;;
        esac
    fi
    return 1
}

# @description Deploy a database script
# @usage deploy-db [--connect-string <string>] <file> [<file>...]
function deploy-db() {
    local db_connect_string="${DB_CONNECT_STRING}"
    local filepaths=()

    # Parse the arguments
    while [[ ${#} -gt 0 ]]; do
        case "${1}" in
            --connect-string)
                db_connect_string="${2}"
                shift 1
                ;;
            -*)
                echo "error: unknown option: ${1}" >&2
                return ${E_INVALID_OPTION:-1}
                ;;
            *)
                filepaths+=( "${1}" )
                ;;
        esac
        shift 1
    done

    debug-vars db_connect_string filepaths

    printf '%s\n' "${filepaths[@]}" | ./devops/deploy_db.sh "${db_connect_string}" - \
        |& {
            error_files=()
            warning_files=()
            success_files=()
            missing_files=()
            error_msg_count=0
            warning_msg_count=0
            missing_msg_count=0
            cur_script=""
            cur_errors=()
            cur_warnings=()
            cur_missing=false
            deploy_finished=false
            failed_scripts=()
            while read line; do
                debug "deploy_db.sh: ${line}"
                # Get the script name
                if [[ "${line}" =~ ': Deploying script "'.*'"'$ ]]; then
                    # Starting deployment of a new script
                    cur_script=$(
                        echo "${line}" \
                            | sed -E 's/.*Deploying script "(.*)"$/\1/'
                    )
                    printf "  - %s ... " "${cur_script}"
                elif contains-sql-error "${line}"; then
                    # This is an error message
                    cur_errors+=("${line}")
                    let error_msg_count++
                elif [[ "${line}" =~ ^"Warning: " ]]; then
                    # This is a warning message
                    cur_warnings+=("${line}")
                    let warning_msg_count++
                elif [[ "${line}" =~ ^'Error: "'.*'does not exist under' ]]; then
                    # This is a missing file error
                    cur_script=$(echo "${line}" | sed -E 's/Error: "(.*)" does not exist under .*/\1/')
                    printf "  - %s ... " "${cur_script}"
                    cur_missing=true
                    let missing_msg_count++
                elif [[
                    "${line}" =~ ^"("[0-9]+") ".*"execution completed."$
                    || "${line}" =~ ^"Moving onto the next script..."$
                ]]; then
                    # Deployment of the current script has finished
                    # If we have a script name and an error, we can report the error
                    if [[ -n "${cur_script}" && ${#cur_errors[@]} -gt 0 ]]; then
                        printf "\e[31mfailed\e[0m\n"
                        printf "    - %s\n" "${cur_errors[@]}" | sort -u
                        error_files+=("${cur_script}")
                    elif [[ -n "${cur_script}" && ${#cur_warnings[@]} -gt 0 ]]; then
                        printf "\e[33mcompleted with warnings\e[0m\n"
                        printf "    - %s\n" "${cur_warnings[@]}" | sort -u
                        warning_files+=("${cur_script}")
                    elif ${cur_missing}; then
                        printf "\e[31mfile missing\e[0m\n"
                        missing_files+=("${cur_script}")
                    elif [[ -n "${cur_script}" ]]; then
                        printf "\e[32mdone\e[0m\n"
                        success_files+=("${cur_script}")
                    fi
                    # Reset the script name and error array
                    cur_script=""
                    cur_errors=()
                    cur_warnings=()
                    cur_missing=false
                fi
            done
            # Print the final summary
            printf "\n"
            printf "Of %d scripts, %d succeeded, %d warnings, %d missing, and %d had errors.\n" \
                $(( ${#success_files[@]} + ${#warning_files[@]} + ${#missing_files[@]} + ${#error_files[@]} )) \
                ${#success_files[@]} ${#warning_files[@]} ${#missing_files[@]} ${#error_files[@]}
        }
}


## main ########################################################################
################################################################################

function main() {
    parse-args "${@}" || return ${?}

    debug-vars \
        DO_DRY_RUN DO_SILENT DO_COLOR \
        CHANGELOG_FILEPATH SOURCE_DIR TARGET_DIR BACKUP_DIR DB_CONNECT_STRING \
        DO_BACKUPS EXCLUDE_PATTERNS DIRECTORY_MAPPINGS DO_VALIDATE_STATUS \
        DO_PRESERVE_BITS DO_PRESERVE_OWNER DO_PRESERVE_GROUP \
        FILE_OWNERSHIP FILE_MODE DO_DEPLOY_ALL DO_DELETE_MISSING \
        HOOK_PRE_RUN HOOK_PRE_DEPLOY HOOK_POST_DEPLOY HOOK_POST_RUN USER


    ## Pre-run hooks ###########################################################
    ############################################################################
    if [[ ${#HOOK_PRE_RUN[@]} -gt 0 ]]; then
        local s=$([[ ${#HOOK_PRE_RUN[@]} -gt 1 ]] && echo "s")
        header "Pre-run hook${s}"

        local arg_string=$(printf " %q" "${@}")
        for hook in "${HOOK_PRE_RUN[@]}"; do
            echo "> ${C_GREEN}${hook}${S_RESET}${S_DIM}${S_BOLD}${arg_string}${S_RESET}"
            if ! ${DO_DRY_RUN}; then
                if ! eval "${hook} ${arg_string}"; then
                    echo "error: pre-run hook failed: ${hook}" >&2
                    return ${E_ERROR}
                fi
            fi
        done
    fi


    ## Deploy files ############################################################
    ############################################################################
    header "Deploying files"
    local files_deployed=0
    local files_failed=0
    local database_files=()
    local errors=()

    # Set up the `cp` args
    local cp_args=()
    local preserve_attr=()
    ${DO_PRESERVE_BITS} && preserve_attr+=( "mode" )
    (${DO_PRESERVE_OWNER} || ${DO_PRESERVE_GROUP}) && preserve_attr+=( "ownership" )
    if [[ ${#preserve_attr[@]} -gt 0 ]]; then
        local preserve_string="--preserve="
        for attr in "${preserve_attr[@]}"; do
            preserve_string+="${attr},"
        done
        cp_args+=( "${preserve_string%,}" )
    fi
    debug-vars cp_args

    for line in "${CHANGELOG[@]}"; do
        debug "processing line: ${line}"
        local mode filepath
        if [[ "${line}" =~ ^([A-Z])[0-9]{0,3}$'\t'(.*)$ ]]; then
            mode="${BASH_REMATCH[1]}"
            filepath="${BASH_REMATCH[2]}"
        else
            filepath="${line}"
        fi
        debug-vars mode filepath

        # Skip files that match an exclude pattern
        for pattern in "${EXCLUDE_PATTERNS[@]}"; do
            if [[ "${filepath}" =~ ${pattern} ]]; then
                debug "skipping file: '${filepath}' =~ ${pattern}"
                continue 2
            fi
        done

        # If the file is a database script, and the mode is not "D", add it to
        # the list of database files to be deployed
        if [[
            "${filepath}" =~ ^"database/"
            && -n "${mode}" && "${mode}" != "D"
        ]]; then
            debug "tracking deployable database file: ${filepath}"
            database_files+=( "${filepath}" )
        fi

        # TODO: Validate the mode if requested

        # TODO: Run the pre-deploy hooks

        # Determine the full source and target filepaths
        local source_filepath="${SOURCE_DIR}/${filepath}"

        # Check to see if there is a custom mapping for the filepath
        local target_filepath target_directory
        local found_mapping=false
        local mapping pattern
        for mapping in "${DIRECTORY_MAPPINGS[@]}"; do
            pattern="${mapping%%:*}"
            debug "checking custom mapping: ${pattern}"
            if [[ "${filepath}" =~ ${pattern} ]]; then
                local target_directory="${mapping#*:}"
                debug "found custom mapping: ${target_directory}"
                target_filepath="${target_directory}/${filepath}"
                found_mapping=true
                break
            fi
        done
        if ! ${found_mapping}; then
            debug "no custom mapping found"
            local target_filepath="${TARGET_DIR}/${filepath}"
        fi
        debug-vars source_filepath target_filepath

        # Determine whether to copy or delete the file
        if [[
            (-n "${mode}" && "${mode}" != "D")
            || -f "${source_filepath}"
        ]]; then
            if [[ ! -f "${source_filepath}" ]]; then
                local error="file not found in source: ${source_filepath}"
                echo "warning: ${error}" >&2
                errors+=( "${error}" )
                continue
            fi

            # File exists in the source, so copy it to the target
            if ${DO_DRY_RUN}; then
                echo "cp ${cp_args[@]} '${source_filepath}' '${target_filepath}'"
            else
                # Ensure the target directory exists
                local target_directory=$(dirname "${target_filepath}")
                if [[ ! -d "${target_directory}" ]]; then
                    mkdir -p "${target_directory}" || {
                        echo "error: cannot create directory: ${target_directory}" >&2
                        return ${E_ERROR}
                    }
                fi

                # Attempt to copy the file
                cp -v "${cp_args[@]}" "${source_filepath}" "${target_filepath}" 2>/dev/null
                if [[ ${?} -ne 0 ]]; then
                    # Try to set ownership of the parent directory and file
                    debug "chown ${FILE_OWNERSHIP} ${target_directory}"
                    sudo chown "${FILE_OWNERSHIP}" "${target_directory}"
                    if [[ -f "${target_filepath}" ]]; then
                        debug "chown ${FILE_OWNERSHIP} ${target_filepath}"
                        sudo chown "${FILE_OWNERSHIP}" "${target_filepath}"
                        if [[ -n "${FILE_MODE}" ]]; then
                            debug "chmod ${FILE_MODE} ${target_filepath}"
                            sudo chmod "${FILE_MODE}" "${target_filepath}"
                        fi
                    fi
                    cp -v "${cp_args[@]}" "${source_filepath}" "${target_filepath}"
                    if [[ ${?} -ne 0 ]]; then
                        echo "error: cannot copy file: ${source_filepath}" >&2
                        continue
                    fi

                    # If the file was copied, set the ownership and mode
                    [[ -n "${FILE_OWNERSHIP}" ]] \
                        && sudo chown "${FILE_OWNERSHIP}" "${target_filepath}"
                    [[ -n "${FILE_MODE}" ]] \
                        && sudo chmod "${FILE_MODE}" "${target_filepath}"
                fi
            fi
        else
            # File does not exist in the source, so delete it from the target
            if ${DO_DRY_RUN}; then
                if (${DO_DEPLOY_ALL} && ${DO_DELETE_MISSING}) || [[ "${mode}" == "D" ]]; then
                    echo "rm ${target_filepath}"
                    echo "warning: file not found in source: ${source_filepath}"
                fi
            else
                if (${DO_DEPLOY_ALL} && ${DO_DELETE_MISSING}) || [[ "${mode}" == "D" ]]; then
                    rm -v "${target_filepath}"
                    if [[ ${?} -ne 0 ]]; then
                        local err="cannot delete file: ${target_filepath}"
                        echo "${err}" >&2
                        errors+=( "${err}" )
                        continue
                    fi
                else
                    echo "warning: file not found in source: ${source_filepath}"
                fi
            fi
        fi

        # TODO: Run the post-deploy hooks
        ((files_deployed++))
    done

    # If there are database files to deploy, deploy them now
    if [[ ${#database_files[@]} -gt 0 ]]; then
        header "Deploying database scripts"
        debug "deploying database files: ${database_files[@]}"
        deploy-db --connect-string "${DB_CONNECT_STRING}" "${database_files[@]}"
    fi

    # If no files were deployed, print a message
    if [[ ${files_deployed} -eq 0 ]]; then
        echo "${C_YELLOW}No files deployed${S_RESET}"
    fi

    ## Post-run hooks ##########################################################
    ############################################################################
    if [[ ${#HOOK_POST_RUN[@]} -gt 0 ]]; then
        local s=$([[ ${#HOOK_POST_RUN[@]} -gt 1 ]] && echo "s")
        header "Post-run hook${s}"

        local arg_string=$(printf " %q" "${@}")
        for hook in "${HOOK_POST_RUN[@]}"; do
            echo "> ${C_GREEN}${hook}${S_RESET}${S_DIM}${S_BOLD}${arg_string}${S_RESET}"
            if ! ${DO_DRY_RUN}; then
                if ! eval "${hook} ${arg_string}"; then
                    echo "error: post-run hook failed: ${hook}" >&2
                    return ${E_ERROR}
                fi
            fi
        done
    fi
}


## run #########################################################################
################################################################################

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && main "${@}"
