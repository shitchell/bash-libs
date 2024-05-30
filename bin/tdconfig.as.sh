#!/usr/bin/env bash
#
# Trinoor Deployments - Configuration - Asset Suite
#
# @author Shaun Mitchell
# @date   2023-06-06
#
# This script is part of the Trinoor Deployments project. It performs server
# configurations for the Asset Suite application, optionally using a provided
# `git --name-status` style changelog to automatically determine which
# configurations to apply.

## imports #####################################################################
################################################################################

# Ensure the `include-source` function is available
[[ -z "${INCLUDE_SOURCE}" ]] && {
    source "${BASH_LIB_PATH%%:*}/include.sh" || {
        echo "error: cannot source required libraries" >&2
        exit 1
    }
}

include-source 'debug.sh'
include-source 'files.sh'
include-source 'echo.sh'
include-source 'changelogs.sh'
include-source 'as-common.sh'


## exit codes ##################################################################
################################################################################

declare -ri E_SUCCESS=0
declare -ri E_ERROR=1
declare -ri E_INVALID_OPTION=2
declare -ri E_INVALID_CHANGELOG=3
declare -ri E_PERMISSION_DENIED=4
declare -ri E_FILE_ERROR=5
declare -ri E_INVALID_MODE=6
declare -ri E_CONFIG_ERROR=7


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
    C_COUNT="${C_CYAN}"
    C_IGNORED="${S_DIM}"
    C_VAR="${C_GREEN}${S_BOLD}"
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
    echo "usage: $(basename "${0}") [-h] [--dry-run] [--auto] [--apply-all]"
    echo "       [--changelog <file>] [--print-changelog] [--print-summary]"
    echo "       [--silent] [--color <when>] [--config-file <file>]"
    echo "       [--as-dir <dir>] [--as-user <user>]"
    echo "       [--(no-)config-nxa] [--(no-)config-tailored]"
    echo "       [--(no-)config-database] [--(no-)config-helix]"
    echo "       [--(no-)config-batch] [--(no-)config-image]"
    echo "       [--(no-)config-view] [--(no-)config-flow]"
    echo "       [--(no-)config-class] [--(no-)config-properties]"
    echo "       [--(no-)config-rbs] [--(no-)config-menu]"
    echo "       [--server-mode <mode>]"
    echo "       [--(no-)restart-jboss] [--(no-)config-and-deploy]"
    echo "       [--pre-config <command>] [--post-config <command>]"
}

function help-epilogue() {
    echo "run assetsuite configurations"
}

function help-full() {
    help-usage
    help-epilogue
    echo
    echo "Category configurations can be run manually, even if --auto is set"
    echo "and the changelog does not include changes for a category."
    echo "For example, if the changelog includes NxA and Batch files:"
    echo "  * --auto"
    echo "    will run NxA and Batch configurations"
    echo "  * --auto --config-view"
    echo "    will run NxA, Batch, and VIEW configurations"
    echo "Ordering is important! Using --auto will unset any previously set"
    echo "manual configurations. Continuing the above example:"
    echo "  * --config-view --auto"
    echo "    will run NxA and Batch configurations but not VIEW configurations"
    echo
    echo "This script can be extended to include custom configurations through"
    echo "hooks. Custom commands and scripts can be called before and after"
    echo "applying configurations. The called command will be passed the"
    echo "changelog through stdin."
    echo
    echo "Basic Options:"
    cat << EOF
    -h                         display usage
    --help                     display this help message
    --config-file <file>       use the provided configuration file
    --as-dir <dir>             set the Asset Suite directory
                               (default: /as_shared)
    --as-user <user>           set the Asset Suite user (default: asuser)
    --changelog <file>         use the provided changelog file ("-" for stdin)
    --ignore-file <regex>      ignore files matching the provided regex
    --no-changelog             do not use a changelog
    --print-changelog          print the changelog
    --no-print-changelog       do not use a changelog
    --print-summary            print a summary of changes and configurations
    --preview-lines <n>        for long output, trim to <n> lines
    --no-print-summary         do not print a summary
    -n/--dry-run               show but do not apply configurations
    -c/--color <when>          when to use color ("auto", "always", "never")
    -s/--silent                suppress all output
EOF
    echo
    echo "Category Configuration Options:"
    cat << EOF
    --config-nxa               run NxA configurations
    --no-config-nxa            do not run NxA configurations
    --config-tailored          run tailored configurations
    --no-config-tailored       do not run tailored configurations
    --config-database          run database configurations
    --no-config-database       do not run database configurations
    --config-helix             run helix configurations
    --no-config-helix          do not run helix configurations
    --config-batch             run batch configurations
    --no-config-batch          do not run batch configurations
    --config-image             run image configurations
    --no-config-image          do not run image configurations
    --config-view              run view configurations
    --no-config-view           do not run view configurations
    --config-flow              run flow configurations
    --no-config-flow           do not run flow configurations
    --config-class             run java class configurations
    --no-config-class          do not run java class configurations
    --config-properties        run properties configurations
    --no-config-properties     do not run properties configurations
    --config-rbs               run RBS configurations
    --no-config-rbs            do not run RBS configurations
    --config-menu              run menu configurations
    --no-config-menu           do not run menu configurations
EOF
    echo
    echo "Server Configuration Options:"
    cat << EOF
    -A/--apply-all             apply all configurations
    -a/--auto                  automatically determine configurations to apply
    -m/--server-mode <mode>    set the server mode (auto-detect, development,
                               production -- default: auto-detect)
    -r/--restart-jboss         restart JBoss after applying configurations
    -R/--no-restart-jboss      do not restart JBoss after applying
                               configurations
    -c/--config-and-deploy     run configure_and_deploy
    -C/--no-config-and-deploy  do not run configure_and_deploy
EOF
    echo
    echo "Custom Configurations:"
    cat << EOF
    --pre-config <command>     run the provided command before applying any
                               configurations
    --post-config <command>    run the provided command after applying all
                               configurations
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
    ## Basic options
    AS_DIR="${AS_DIR:-/as_shared}"
    AS_USER="${AS_USER:-asuser}"
    CHANGELOG_FILEPATH="${CHANGELOG_FILEPATH:-}"
    CHANGELOG=""
    IGNORE_FILE_PATTERNS=( "${IGNORE_FILE_PATTERNS[@]}" )
    DO_USE_CHANGELOG="${DO_USE_CHANGELOG:-true}"
    DO_PRINT_CHANGELOG="${DO_PRINT_CHANGELOG:-false}"
    DO_PRINT_SUMMARY="${DO_PRINT_SUMMARY:-true}"
    PREVIEW_LINES="${PREVIEW_LINES:-10}"
    DO_DRY_RUN="${DO_DRY_RUN:-false}"
    DO_SILENT="${DO_SILENT:-false}"
    DO_COLOR="${DO_COLOR:-false}"
    local color_when='auto' # auto, on, yes, always, off, no, never
    ## Change category overrides
    CATEGORY_OVERRIDE_NXA="${CATEGORY_OVERRIDE_NXA:-}"
    CATEGORY_OVERRIDE_TAILORED="${CATEGORY_OVERRIDE_TAILORED:-}"
    CATEGORY_OVERRIDE_DATABASE="${CATEGORY_OVERRIDE_DATABASE:-}"
    CATEGORY_OVERRIDE_HELIX="${CATEGORY_OVERRIDE_HELIX:-}"
    CATEGORY_OVERRIDE_BATCH="${CATEGORY_OVERRIDE_BATCH:-}"
    CATEGORY_OVERRIDE_IMAGE="${CATEGORY_OVERRIDE_IMAGE:-}"
    CATEGORY_OVERRIDE_VIEW="${CATEGORY_OVERRIDE_VIEW:-}"
    CATEGORY_OVERRIDE_FLOW="${CATEGORY_OVERRIDE_FLOW:-}"
    CATEGORY_OVERRIDE_CLASS="${CATEGORY_OVERRIDE_CLASS:-}"
    CATEGORY_OVERRIDE_PROPERTIES="${CATEGORY_OVERRIDE_PROPERTIES:-}"
    CATEGORY_OVERRIDE_RBS="${CATEGORY_OVERRIDE_RBS:-}"
    CATEGORY_OVERRIDE_MENU="${CATEGORY_OVERRIDE_MENU:-}"
    ## Server configuration options
    DO_APPLY_ALL="${DO_APPLY_ALL_CONFIGURATIONS:-false}"
    DO_AUTO="${DO_AUTO_CONFIGURATIONS:-true}"
    local server_mode="${SERVER_MODE:-auto-detect}"
    SERVER_MODE="" # to be set after option parsing based on --server-mode
    CONFIG_OVERRIDES_JBOSS="${CONFIG_OVERRIDES_JBOSS:-}"
    CONFIG_OVERRIDES_CND="${CONFIG_OVERRIDES_CND:-}"
    ## Hooks
    PRE_CONFIG_COMMANDS=( "${PRE_CONFIG_COMMANDS[@]}" )
    POST_CONFIG_COMMANDS=( "${POST_CONFIG_COMMANDS[@]}" )

    # Loop over the arguments
    while [[ ${#} -gt 0 ]]; do
        case ${1} in
            ## Basic options
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
            --as-dir)
                AS_DIR=$(realpath "${2}" 2>/dev/null)
                if [[ -z "${AS_DIR}" ]]; then
                    echo "error: invalid directory: ${2}" >&2
                    return ${E_INVALID_OPTION}
                fi
                shift 1
                ;;
            --as-user)
                AS_USER="${2}"
                shift 1
                ;;
            --changelog)
                CHANGELOG_FILEPATH="${2}"
                DO_USE_CHANGELOG=true
                shift 1
                ;;
            --ignore-file)
                IGNORE_FILE_PATTERNS+=( "${2}" )
                shift 1
                ;;
            --no-changelog)
                DO_USE_CHANGELOG=false
                ;;
            --print-changelog)
                DO_PRINT_CHANGELOG=true
                ;;
            --no-print-changelog)
                DO_PRINT_CHANGELOG=false
                ;;
            --preview-lines)
                PREVIEW_LINES="${2}"
                shift 1
                ;;
            --print-summary)
                DO_PRINT_SUMMARY=true
                ;;
            --no-print-summary)
                DO_PRINT_SUMMARY=false
                ;;
            -n | --dry-run)
                DO_DRY_RUN=true
                ;;
            -c | --color)
                color_when="${2}"
                shift 1
                ;;
            -s | --silent)
                DO_SILENT=true
                ;;
            ## Category Configuration Options
            --config-nxa | --nxa)
                CATEGORY_OVERRIDE_NXA=true
                ;;
            --no-nxa | --no-config-nxa)
                CATEGORY_OVERRIDE_NXA=false
                ;;
            --config-tailored | --tailored)
                CATEGORY_OVERRIDE_TAILORED=true
                ;;
            --no-tailored | --no-config-tailored)
                CATEGORY_OVERRIDE_TAILORED=false
                ;;
            --config-database | --database)
                CATEGORY_OVERRIDE_DATABASE=true
                ;;
            --no-database | --no-config-database)
                CATEGORY_OVERRIDE_DATABASE=false
                ;;
            --config-helix | --helix)
                CATEGORY_OVERRIDE_HELIX=true
                ;;
            --no-helix | --no-config-helix)
                CATEGORY_OVERRIDE_HELIX=false
                ;;
            --config-batch | --batch)
                CATEGORY_OVERRIDE_BATCH=true
                ;;
            --no-batch | --no-config-batch)
                CATEGORY_OVERRIDE_BATCH=false
                ;;
            --config-image | --image)
                CATEGORY_OVERRIDE_IMAGE=true
                ;;
            --no-image | --no-config-image)
                CATEGORY_OVERRIDE_IMAGE=false
                ;;
            --config-view | --view)
                CATEGORY_OVERRIDE_VIEW=true
                ;;
            --no-view | --no-config-view)
                CATEGORY_OVERRIDE_VIEW=false
                ;;
            --config-flow | --flow)
                CATEGORY_OVERRIDE_FLOW=true
                ;;
            --no-flow | --no-config-flow)
                CATEGORY_OVERRIDE_FLOW=false
                ;;
            --config-class | --class)
                CATEGORY_OVERRIDE_CLASS=true
                ;;
            --no-class | --no-config-class)
                CATEGORY_OVERRIDE_CLASS=false
                ;;
            --config-properties | --properties)
                CATEGORY_OVERRIDE_PROPERTIES=true
                ;;
            --no-properties | --no-config-properties)
                CATEGORY_OVERRIDE_PROPERTIES=false
                ;;
            --config-rbs | --rbs)
                CATEGORY_OVERRIDE_RBS=true
                ;;
            --no-rbs | --no-config-rbs)
                CATEGORY_OVERRIDE_RBS=false
                ;;
            --config-menu | --menu)
                CATEGORY_OVERRIDE_MENU=true
                ;;
            --no-menu | --no-config-menu)
                CATEGORY_OVERRIDE_MENU=false
                ;;
            ## Server Configuration Options
            -A | --apply-all)
                DO_APPLY_ALL=true
                unset-category-overrides
                unset-config-overrides
                DO_USE_CHANGELOG=false
                DO_AUTO=false
                ;;
            -a | --auto)
                DO_AUTO=true
                # Reset any previously set overrides
                unset-category-overrides
                unset-config-overrides
                DO_USE_CHANGELOG=true
                DO_APPLY_ALL=false
                ;;
            -m | --server-mode)
                server_mode="${2}"
                shift 1
                ;;
            -r | --restart-jboss)
                CONFIG_OVERRIDES_JBOSS=true
                ;;
            -R | --no-restart-jboss)
                CONFIG_OVERRIDES_JBOSS=false
                ;;
            -c | --config-and-deploy)
                CONFIG_OVERRIDES_CND=true
                ;;
            -C | --no-config-and-deploy)
                CONFIG_OVERRIDES_CND=false
                ;;
            ## Hooks
            --pre-config)
                PRE_CONFIG_COMMANDS+=("${2}")
                shift 1
                ;;
            --post-config)
                POST_CONFIG_COMMANDS+=("${2}")
                shift 1
                ;;
            # --)
            #     shift 1
            #     break
            #     ;;
            # -*)
            #     echo "error: unknown option: ${1}" >&2
            #     return ${E_ERROR}
            #     ;;
            # *)
            #     FILEPATHS+=("${1}")
            #     ;;
            *)
                echo "error: unknown option: ${1}" >&2
                return ${E_INVALID_OPTION}
                ;;
        esac
        shift 1
    done

    # # If -- was used, collect the remaining arguments
    # while [[ ${#} -gt 0 ]]; do
    #     FILEPATHS+=("${1}")
    #     shift 1
    # done

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

    # Set the server mode
    if [[ "${server_mode}" == "auto-detect" ]]; then
        # Determine the server mode from env.properties
        SERVER_MODE=$(as-config -i env.properties -K -F server.mode)
    else
        SERVER_MODE="${server_mode}"
    fi
    # Validate the server mode
    if [[
        "${SERVER_MODE}" != "development"
        && "${SERVER_MODE}" != "production"
    ]]; then
        echo "error: invalid server mode: ${server_mode}" >&2
        return ${E_INVALID_MODE}
    fi

    # If a changelog is being used, validate it
    [[ "${CHANGELOG_FILEPATH}" == "-" ]] && CHANGELOG_FILEPATH="/dev/stdin"
    if ${DO_USE_CHANGELOG}; then
        if [[ -z "${CHANGELOG_FILEPATH}" ]]; then
            echo "error: no changelog provided" >&2
            return ${E_INVALID_CHANGELOG}
        elif [[ "${CHANGELOG_FILEPATH}" != "/dev/stdin" ]]; then
            if [[ ! -f "${CHANGELOG_FILEPATH}" ]]; then
                echo "error: changelog does not exist: ${CHANGELOG_FILEPATH}" >&2
                return ${E_FILE_ERROR}
            elif [[ ! -r "${CHANGELOG_FILEPATH}" ]]; then
                echo "error: cannot read changelog: ${CHANGELOG_FILEPATH}" >&2
                return ${E_PERMISSION_DENIED}
            fi
        fi
    fi

    # Validate that PREVIEW_LINES is a number
    if [[ -n "${PREVIEW_LINES}" && ! "${PREVIEW_LINES}" =~ ^[0-9]+$ ]]; then
        echo "error: preview lines must be an integer: ${PREVIEW_LINES}" >&2
        return ${E_INVALID_OPTION}
    fi

    return ${E_SUCCESS}
}


## helpful functions ###########################################################
################################################################################

function unset-category-overrides() {
    CATEGORY_OVERRIDE_NXA=""
    CATEGORY_OVERRIDE_TAILORED=""
    CATEGORY_OVERRIDE_DATABASE=""
    CATEGORY_OVERRIDE_HELIX=""
    CATEGORY_OVERRIDE_BATCH=""
    CATEGORY_OVERRIDE_IMAGE=""
    CATEGORY_OVERRIDE_VIEW=""
    CATEGORY_OVERRIDE_FLOW=""
    CATEGORY_OVERRIDE_CLASS=""
    CATEGORY_OVERRIDE_PROPERTIES=""
    CATEGORY_OVERRIDE_RBS=""
    CATEGORY_OVERRIDE_MENU=""
}

function unset-config-overrides() {
    CONFIG_OVERRIDES_JBOSS=""
    CONFIG_OVERRIDES_CND=""
}

# @description Determine if a categorical change is required
# @usage do-apply-category <category>
function do-apply-category() {
    local category="${1}"
    local do_apply=false

    debug "do-apply-category: ${category}"

    local category_override_var="CATEGORY_OVERRIDE_${category^^}"
    local category_override="${!category_override_var}"

    if ${DO_APPLY_ALL}; then
        do_apply=true
    elif ${DO_AUTO}; then
        if ((CHANGE_CATEGORY_COUNTS["${category}"] > 0)); then
            do_apply=true
        elif [[
            -n "${category_override}"
            && "${category_override}" == true
        ]]; then
            do_apply=true
        fi
    fi

    ${do_apply}
}

# @description Determine if a configuration is required
# @usage do-apply-config <config>
function do-apply-config() {
    local config="${1}"
    local do_apply=false

    debug "do-apply-config: ${config}"

    local config_override_var="CONFIG_OVERRIDES_${config^^}"
    local config_override="${!config_override_var}"

    if ${DO_APPLY_ALL}; then
        do_apply=true
    elif [[ -n "${config_override}" ]]; then
        do_apply="${config_override}"
    fi

    ${do_apply}
}

# @description Determine if JBoss should be restarted
# @usage do-restart-jboss
function do-restart-jboss() {
    local restart_jboss=false

    if [[ -n "${CONFIG_OVERRIDES_JBOSS}" ]]; then
        restart_jboss=${CONFIG_OVERRIDES_JBOSS}
    elif ${DO_APPLY_ALL}; then
        restart_jboss=true
    elif ${DO_AUTO}; then
        # Depending on the server mode, we'll have different conditions for
        # whether or not to restart JBoss
        if [[ "${SERVER_MODE}" == "development" ]]; then
            # In development mode, restart JBoss if there are any changes
            # to NxA, Batch, Image, VIEW, FLOW, Properties, or Java class files
            if (
                do-apply-category "nxa" \
                || do-apply-category "batch" \
                || do-apply-category "image" \
                || do-apply-category "view" \
                || do-apply-category "flow" \
                || do-apply-category "properties" \
                || do-apply-category "class"
            ) || (
                do-apply-config "jboss"
            ); then
                restart_jboss=true
            fi
        elif [[ "${SERVER_MODE}" == "production" ]]; then
            # In production mode, restart JBoss if there are any changes
            # to NxA, Properties, or Tailored files
            if (
                do-apply-category "nxa" \
                || do-apply-category "properties" \
                || do-apply-category "tailored"
            ) || (
                do-apply-config "jboss"
            ); then
                restart_jboss=true
            fi
        fi
    fi

    ${restart_jboss}
}

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


## main ########################################################################
################################################################################

function main() {
    parse-args "${@}" || return ${?}

    # Track change counts
    declare -A CHANGE_CATEGORY_COUNTS=(
        ["nxa"]=0
        ["tailored"]=0
        ["database"]=0
        ["database_updated"]=0
        ["helix"]=0
        ["batch"]=0
        ["image"]=0
        ["view"]=0
        ["flow"]=0
        ["class"]=0
        ["properties"]=0
        ["rbs"]=0
        ["menu"]=0
        ["ignored"]=0
    )
    declare -A CHANGE_MODE_COUNTS=(
        ["A"]=0
        ["M"]=0
        ["D"]=0
        ["R"]=0
        ["C"]=0
        ["T"]=0
        ["U"]=0
        ["X"]=0
        ["B"]=0
    )

    debug-vars AS_DIR CHANGELOG_FILEPATH DO_USE_CHANGELOG DO_PRINT_CHANGELOG \
               DO_PRINT_SUMMARY DO_DRY_RUN DO_SILENT DO_COLOR \
               'CATEGORY_OVERRIDE_*' 'CONFIG_OVERRIDES_*' \
               DO_APPLY_ALL DO_AUTO SERVER_MODE PRE_CONFIG_COMMANDS \
               POST_CONFIG_COMMANDS CHANGELOG CHANGE_CATEGORY_COUNTS \
               CHANGE_MODE_COUNTS USER

    ## Settings ################################################################
    ############################################################################

    # Print a summary of the settings
    if ${DO_PRINT_SUMMARY}; then
        header "Settings"
        # echo "AS_DIR: ${AS_DIR}"
        # echo "AS_USER: ${AS_USER}"
        # echo "CHANGELOG_FILEPATH: ${CHANGELOG_FILEPATH}"
        # echo "DO_USE_CHANGELOG: ${DO_USE_CHANGELOG}"
        # echo "DO_PRINT_CHANGELOG: ${DO_PRINT_CHANGELOG}"
        # echo "DO_PRINT_SUMMARY: ${DO_PRINT_SUMMARY}"
        # echo "DO_DRY_RUN: ${DO_DRY_RUN}"
        # echo "DO_SILENT: ${DO_SILENT}"
        # echo "DO_COLOR: ${DO_COLOR}"
        # echo "DO_APPLY_ALL: ${DO_APPLY_ALL}"
        # echo "DO_AUTO: ${DO_AUTO}"
        # echo "SERVER_MODE: ${SERVER_MODE}"
        # echo "PRE_CONFIG_COMMANDS: ${PRE_CONFIG_COMMANDS[*]}"
        # echo "POST_CONFIG_COMMANDS: ${POST_CONFIG_COMMANDS[*]}"
        echo "AssetSuite directory:  ${C_VAR}${AS_DIR}${S_RESET}"
        echo "AssetSuite user:       ${C_VAR}${AS_USER}${S_RESET}"
        echo "Running as user:       ${C_VAR}${USER}${S_RESET}"
        echo "Changelog file:        ${C_VAR}${CHANGELOG_FILEPATH}${S_RESET}"
        echo "Use changelog:         ${C_VAR}${DO_USE_CHANGELOG}${S_RESET}"
        echo "Dry run:               ${C_VAR}${DO_DRY_RUN}${S_RESET}"
        echo "Apply all:             ${C_VAR}${DO_APPLY_ALL}${S_RESET}"
        echo "Auto:                  ${C_VAR}${DO_AUTO}${S_RESET}"
        echo "Server mode:           ${C_VAR}${SERVER_MODE}${S_RESET}"
        echo "Pre-config commands:   ${C_VAR}${#PRE_CONFIG_COMMANDS[*]}${S_RESET}"
        echo "Post-config commands:  ${C_VAR}${#POST_CONFIG_COMMANDS[*]}${S_RESET}"
    fi


    ## Changelog ###############################################################
    ############################################################################

    # Read and parse the changelog
    local changelog_data
    local filepath mode abspath
    local command

    # Read and parse the changelog
    if ${DO_PRINT_CHANGELOG}; then
        header "Changelog"
    fi

    local stop_printing=false
    local files_counted=0
    if ${DO_USE_CHANGELOG} && [[ -n "${CHANGELOG_FILEPATH}" ]]; then
        changelog_data=$(cat "${CHANGELOG_FILEPATH}" 2>/dev/null) || {
            echo "error: cannot read changelog: ${CHANGELOG_FILEPATH}" >&2
            return ${E_FILE_ERROR}
        }
        debug-vars changelog_data
        changelog_data=$(uniq-column -c 2 -d $'\t' <<< "${changelog_data}")
        debug-vars changelog_data

        # Print the changelog if requested
        if ${DO_PRINT_CHANGELOG}; then
            if [[ -z "${changelog_data}" ]]; then
                echo "${C_YELLOW}Changelog is empty${S_RESET}"
            fi
        fi

        # Update the change category and mode counts
        while read -r line; do
            mode="${line:0:1}"
            filepath="${line#*$'\t'}"
            abspath="${AS_DIR}/${filepath}"
            debug "tracking file category: ${mode}  ${abspath}"

            # Check if the file should be ignored
            let files_counted++
            if [[
                -n "${PREVIEW_LINES}"
                && ${files_counted} -gt ${PREVIEW_LINES}
            ]]; then
                stop_printing=true
            fi
            if [[ -n "${IGNORE_FILE_PATTERNS[@]}" ]]; then
                for pattern in "${IGNORE_FILE_PATTERNS[@]}"; do
                    if [[ "${filepath}" =~ ${pattern} ]]; then
                        debug "ignoring '${filepath}' =~ ${pattern}"
                        ((CHANGE_CATEGORY_COUNTS["ignored"]++))
                        if ${DO_PRINT_CHANGELOG} && ! ${stop_printing}; then
                            echo "${S_DIM}[${mode}] ${filepath}${S_RESET}"
                        fi
                        continue 2
                    fi
                done
            fi
            ${DO_PRINT_CHANGELOG} && ! ${stop_printing} && echo "[${mode}] ${filepath}"
            ((CHANGE_MODE_COUNTS["${mode}"]++))
            

            ## Count changes ###################################################
            ####################################################################

            ## NxA #############################################################
            if [[ "${filepath}" =~ ^"nxa/" ]]; then
                debug "incrementing nxa count"
                ((CHANGE_CATEGORY_COUNTS["nxa"]++))

            ## Tailored ########################################################
            elif [[ "${filepath}" =~ ^"tailored/" ]]; then
                debug "incrementing tailored count"
                let CHANGE_CATEGORY_COUNTS["tailored"]++

            ## Database ########################################################
            elif [[ "${filepath}" =~ ^"database/" ]]; then
                ((CHANGE_CATEGORY_COUNTS["database"]++))
                if [[ "${mode}" == "M" || "${mode}" == "A" ]]; then
                    ## Deployable database changes
                    ((CHANGE_CATEGORY_COUNTS["database_updated"]++))
                fi

            ## Helix ###########################################################
            elif [[ "${filepath}" =~ ^"helix/" ]]; then
                ((CHANGE_CATEGORY_COUNTS["helix"]++))
            fi

            # Sub-categories
            ## Batch ###########################################################
            if [[
                "${filepath}" =~ ^"tailored/metadata/runtime/batchconfig/"
                || "${filepath}" =~ ^"tailored/extensions/BatchExtensions/"
            ]]; then
                ((CHANGE_CATEGORY_COUNTS["batch"]++))
            
            ## Image ###########################################################
            elif [[ "${filepath}" =~ ^"tailored/metadata/images/" ]]; then
                ((CHANGE_CATEGORY_COUNTS["image"]++))
            
            ## VIEW ############################################################
            elif [[
                "${filepath}" =~ ^"tailored/metadata/runtime/ui/VIEW/"
            ]]; then
                ((CHANGE_CATEGORY_COUNTS["view"]++))
            
            ## FLOW ############################################################
            elif [[
                "${filepath}" =~ ^"tailored/metadata/runtime/ui/FLOW/"
            ]]; then
                ((CHANGE_CATEGORY_COUNTS["flow"]++))
            
            ## MENU ############################################################
            elif [[
                "${filepath}" =~ ^"tailored/metadata/runtime/ui/config/MENU/"
            ]]; then
                ((CHANGE_CATEGORY_COUNTS["menu"]++))

            ## Resource bundles ################################################
            elif [[ "${filepath}" =~ ^"tailored/resource_bundles/" ]]; then
                ((CHANGE_CATEGORY_COUNTS["rbs"]++))

            ## Properties ######################################################
            elif [[ "${filepath}" =~ ".properties"$ ]]; then
                ((CHANGE_CATEGORY_COUNTS["properties"]++))

            ## Java class ######################################################
            elif (
                [[ -f "${abspath}" ]] \
                && is-java-class "${abspath}" 2>/dev/null
            ); then
                ((CHANGE_CATEGORY_COUNTS["class"]++))
            elif (
                [[ -f "${filepath}" ]] \
                && is-java-class "${filepath}" 2>/dev/null
            ); then
                ((CHANGE_CATEGORY_COUNTS["class"]++))
            fi
        done <<< "${changelog_data}"
        if ${stop_printing}; then
            local remainder=$((files_counted - PREVIEW_LINES))
            echo "${S_DIM}... and ${remainder} more files${S_RESET}"
        fi
    elif ${DO_APPLY_ALL} && [[ -n "${CHANGELOG_FILEPATH}" ]]; then
        echo "${C_YELLOW}Changelog set but skipped due to APPLY_ALL setting${S_RESET}"
    else
        echo "${C_YELLOW}No changelog provided${S_RESET}"
    fi
    debug-vars CHANGE_CATEGORY_COUNTS CHANGE_MODE_COUNTS


    ## Pre-config hooks ########################################################
    ############################################################################

    if [[ ${#PRE_CONFIG_COMMANDS[@]} -gt 0 ]]; then
        header "Pre-configuration commands"

        for pre_hook in "${PRE_CONFIG_COMMANDS[@]}"; do
            debug "running pre-config command: '${pre_hook}'"
            # Print the hook
            echo "> ${C_GREEN}${S_BOLD}${pre_hook}${S_RESET}"
            printf '%s' "${changelog_data}" \
                | sudo -u "${AS_USER}" bash -c "${pre_hook}" \
                |& sed -e 's/^/  /'
        done
    fi


    ## Apply configurations ####################################################
    ############################################################################

    header "Applying configurations"
    local errors=()
    local cmd_str=""
    local configurations_applied=0
    local configurations_failed=0

    # ################################################################ Database ##
    # debug "checking for database configurations"
    # if do-apply-category "database_updated"; then
    #     debug "applying database configurations"

    #     local err_db
    #     ${DO_DRY_RUN} \
    #         && cmd_str="true" \
    #         || cmd_str="assetsuite apply_database"

    #     check-command "${cmd_str}" \
    #         --description "applying database configurations" \
    #         --success "done" \
    #         --failure "error" \
    #         --stderr-var "err_db" \
    #         && ((++configurations_applied)) \
    #         || {
    #             echo "${C_RED}${err_db}${S_RESET}" >&2
    #             errors+=("${err_db}")
    #             ((configurations_failed++))
    #         }
    # fi

    ################################################################### JBoss ##
    debug "checking for JBoss restart"
    if do-restart-jboss; then
        debug "stopping JBoss"

        ${DO_DRY_RUN} \
            && cmd_str="true" \
            || cmd_str="asrun-script stop_jboss.sh"

        check-command "${cmd_str}" \
            --description "stopping JBoss" \
            --success "done" \
            --failure "already stopped"
    fi

    ##################################################################### NxA ##
    debug "checking for NxA configurations"
    if do-apply-config "nxa"; then
        debug "applying NxA configurations"

        local err_nxa
        local nxa_index="${AS_DIR}/nxa/SREData/MetaDataMgr/FileMgr/registry/index_db.xml"
        ${DO_DRY_RUN} \
            && cmd_str="true" \
            || cmd_str="rm '${nxa_index}'"

        check-command "${cmd_str}" \
            --description "removing NxA index" \
            --success "done" \
            --failure "error" \
            --stderr-var "err_nxa" \
            && ((++configurations_applied)) \
            || {
                local err="${C_GREEN}${cmd_str}${S_RESET}"$'\n'"${err_nxa}"
                errors+=("${err}")
                ((configurations_failed++))
            }
    fi

    ################################################################### Batch ##
    debug "checking for Batch configurations"
    if do-apply-category "batch"; then
        debug "applying Batch configurations"

        local err_batch
        ${DO_DRY_RUN} \
            && cmd_str="true" \
            || cmd_str="assetsuite generate_custom_batch_jobdefs"

        check-command "${cmd_str}" \
            --description "generating custom batch job definitions" \
            --success "done" \
            --failure "error" \
            --stderr-var "err_batch" \
            && ((++configurations_applied)) \
            || {
                local err="${C_GREEN}${cmd_str}${S_RESET}"$'\n'"${err_batch}"
                errors+=("${err}")
                ((configurations_failed++))
            }

        ${DO_DRY_RUN} \
            && cmd_str="true" \
            || cmd_str="assetsuite generate_custom_batch_jobdefs"
        err_batch=""

        check-command "${cmd_str}" \
            --description "generating custom batch views" \
            --success "done" \
            --failure "error" \
            --stderr-var "err_batch" \
            && ((++configurations_applied)) \
            || {
                local err="${C_GREEN}${cmd_str}${S_RESET}"$'\n'"${err_batch}"
                errors+=("${err}")
                ((configurations_failed++))
            }
    fi

    ################################################ Batch / Resource Bundles ##
    debug "checking for Batch and Resource Bundles configurations"
    if do-apply-category "batch" || do-apply-category "rbs"; then
        debug "applying Batch and Resource Bundles configurations"

        local err_batch_rbs
        ${DO_DRY_RUN} \
            && cmd_str="true" \
            || cmd_str="assetsuite apply_tailored_rbs"

        check-command "${cmd_str}" \
            --description "applying tailored resource bundles" \
            --success "done" \
            --failure "error" \
            --stderr-var "err_batch_rbs" \
            && ((++configurations_applied)) \
            || {
                local err="${C_GREEN}${cmd_str}${S_RESET}"$'\n'"${err_batch_rbs}"
                errors+=("${err}")
                ((configurations_failed++))
            }
    fi

    #################################################################### Menu ##
    debug "checking for Menu configurations"
    if do-apply-category "menu"; then
        debug "applying Menu configurations"

        local err_menu
        ${DO_DRY_RUN} \
            && cmd_str="true" \
            || cmd_str="assetsuite load menu"

        check-command "${cmd_str}" \
            --description "reloading tailored menus" \
            --success "done" \
            --failure "error" \
            --stderr-var "err_menu" \
            && ((++configurations_applied)) \
            || {
                local err="${C_GREEN}${cmd_str}${S_RESET}"$'\n'"${err_menu}"
                errors+=("${err}")
                ((configurations_failed++))
            }
    fi

    ################################ Images / Properties / Configure & Deploy ##
    debug "checking for Image/Properties/configure_and_deploy configurations"
    if (
        do-apply-category "image" \
        || do-apply-category "properties" \
        || do-apply-config "cnd"
    ); then
        debug "performing configure_and_deploy"

        local err_rm
        ${DO_DRY_RUN} \
            && cmd_str="true" \
            || cmd_str="rm /abb/assetsuite/encrypted_passwords.properties"
        
        check-command "${cmd_str}" \
            --description "removing encrypted passwords" \
            --success "done" \
            --failure "error" \
            --stderr-var "err_rm" \
            && ((++configurations_applied)) \
            || {
                local err="${C_GREEN}${cmd_str}${S_RESET}"$'\n'"${err_rm}"
                errors+=("${err}")
                ((configurations_failed++))
            }

        local err_config
        ${DO_DRY_RUN} \
            && cmd_str="true" \
            || cmd_str="assetsuite configure_and_deploy"
        check-command "${cmd_str}" \
            --description "applying configure_and_deploy" \
            --success "done" \
            --failure "error" \
            --stderr-var "err_config" \
            && ((++configurations_applied)) \
            || {
                local err="${C_GREEN}${cmd_str}${S_RESET}"$'\n'"${err_config}"
                errors+=("${err}")
                ((configurations_failed++))
            }
    fi

    ################################################################### JBoss ##
    debug "checking for JBoss restart"
    if do-restart-jboss; then
        debug "restarting JBoss"

        ${DO_DRY_RUN} \
            && cmd_str="true" \
            || cmd_str="asrun-script start_jboss.sh"

        local err_restart
        check-command "${cmd_str}" \
            --description "restarting JBoss" \
            --success "done" \
            --failure "error" \
            --stderr-var "err_restart" \
            --attempts 3 \
            && ((++configurations_applied)) \
            || {
                local err="${C_GREEN}${cmd_str}${S_RESET}"$'\n'"${err_restart}"
                errors+=("${err}")
                ((configurations_failed++))
            }
    fi

    ## Print a message about the number of configurations applied
    echo
    if [[
        ${configurations_applied} -eq 0
        && ${configurations_failed} -eq 0
    ]]; then
        echo "${C_YELLOW}No configurations applied${S_RESET}"
    else
        echo -n "${C_GREEN}${configurations_applied}${S_RESET} configurations applied"
        if [[ ${configurations_failed} -gt 0 ]]; then
            echo " and ${C_RED}${configurations_failed} ${S_BOLD}configurations failed${S_RESET}"
        else
            echo
        fi
    fi


    ## Post-config hooks #######################################################
    ############################################################################

    if [[ ${#POST_CONFIG_COMMANDS[@]} -gt 0 ]]; then
        header "Post-configuration commands"

        for post_hook in "${POST_CONFIG_COMMANDS[@]}"; do
            debug "running post-config command: '${post_hook}'"
            # Print the hook
            echo "> ${C_GREEN}${S_BOLD}${post_hook}${S_RESET}"
            printf '%s' "${changelog_data}" \
                | sudo -u "${AS_USER}" bash -c "${post_hook}" \
                |& sed -e 's/^/  /'
        done
    fi


    ## Summary #################################################################
    ############################################################################

    # Print a summary of changes and configurations
    if ${DO_PRINT_SUMMARY}; then
        header "Summary"

        header --markdown --level 2 -B 0 "Changes"
        if ${DO_USE_CHANGELOG}; then
            # Calculate the total number of files changed
            local total_changes=0
            for count in "${CHANGE_MODE_COUNTS[@]}"; do
                ((total_changes+=count))
            done

            for mode in "${!CHANGE_MODE_COUNTS[@]}"; do
                count="${CHANGE_MODE_COUNTS["${mode}"]}"
                mode=$(git-status-name "${mode}")
                if [[ ${count} -gt 0 ]]; then
                    echo "  ${mode}: ${C_COUNT}${count}${S_RESET}"
                fi
            done
            echo "  total: ${C_CYAN}${total_changes}${S_RESET}"

            header -B 1 --markdown --level 2 "Change Categories"
            for category in "${!CHANGE_CATEGORY_COUNTS[@]}"; do
                count="${CHANGE_CATEGORY_COUNTS["${category}"]}"
                if [[ ${count} -gt 0 ]]; then
                    echo "  ${category}: ${C_COUNT}${count}${S_RESET}"
                fi
            done
        else
            echo "  ${C_YELLOW}No changelog used${S_RESET}"
        fi
        
        header -B 1 --markdown --level 2 "Errors"
        if [[ ${#errors[@]} -gt 0 ]]; then
            for error in "${errors[@]}"; do
                local is_first=true
                while read -r line; do
                    if ${is_first}; then
                        echo "  - ${line}"
                        is_first=false
                    else
                        echo "    ${line}"
                    fi
                done <<< "${error}"
            done
        else
            echo "  ${C_GREEN}No errors${S_RESET}"
        fi
    fi

    # Return the number of failed configurations
    return ${configurations_failed}
}


## run #########################################################################
################################################################################

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && main "${@}"
