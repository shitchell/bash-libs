#!/usr/bin/env bash
#
# Trinoor Deployments - Cherry-Pick
#
# @author Shaun Mitchell
# @date   2023-06-06
#
# This script will accept a commit hash and produce a `git log --name-status`
# style list of filepaths. For Pull Requests, this will be the list of files
# changed in the PR. For cherry-picks (commits with a single file in the root of
# the repo whose name matches the feature branch naming pattern), this will be a
# list of files which have been associated with the feature since the last time
# the feature was checked into the target branch. For all other commits, this
# will check to see if a cherry-pick was attempted and, if so, it will simply
# delete the cherry-pick trigger file.
#
# Creating a tar file will generate the following structure:
# - ${BUILD_DIR}/
#   - files
#     - tdeploy_changelog.txt
#     - ${changelog_files[@]}
#   - tdeploy.tar
# ${BUILD_DIR} defaults to ${REPO_ROOT}/_build
#
# TODO: align variables with tdconfig.as.sh and tdeploy.sh
# TODO: restructure to align with tdconfig.as.sh and tdeploy.sh


## imports #####################################################################
################################################################################

# Ensure the `include-source` function is available
# Ensure the `include-source` function is available
[[ -z "${INCLUDE_SOURCE}" ]] && {
    source "${BASH_LIB_PATH%%:*}/include.sh" || {
        echo "error: cannot source required libraries" >&2
        exit 1
    }
}

include-source 'shell.sh'
include-source 'echo.sh'
include-source 'git.sh'
include-source 'as-common.sh'
include-source 'debug.sh'


## exit codes ##################################################################
################################################################################

EXIT_SUCCESS=0                 # success
EXIT_FAILURE=1                 # generic failure
EXIT_NO_CHANGES=0              # no changed files were found, exit status 2 if --error-on-no-changes is set
EXIT_INVALID_ARGS=3            # invalid arguments passed to the script
EXIT_GIT_ERROR=4               # generic git command failure
EXIT_GIT_AUTH_ERROR=5          # could not authenticate with remote repo
EXIT_CONFLICTS=6               # cherry-pick conflicts were found


## usage function ##############################################################
################################################################################
# @section usage function
# @description Functions related to command line arguments and help

function help-epilogue() {
    echo "cherry-pick and promote features"
}

# @description
#   Parse the arguments passed to the script. Options are loaded from:
#     1. environment variables
#     2. the config file specified by the -c/--config-file option
#     3. command line arguments
# @set DEBUG
# @set COMMIT_HASH
# @set REPO_ROOT
# @set FEATURE_NAMES
# @set FEATURE_PATTERN
# @set METADATA_SOURCE
# @set PROGRESS_BAR_STEPS
# @set PROGRESS_BAR_MIN_INTERVAL
# @set LIB_DIR
# @set LOG_DIR
# @set DEFAULT_LOG
# @set CONFIG_FILE
# @set GIT_USER_NAME
# @set GIT_USER_ADDR
# @set SOURCE_BRANCH
# @set TARGET_BRANCH
# @set DO_TAR_ARCHIVE
# @set DO_DEPLOY
# @set DO_PROMOTE
# @set DO_METADATA_UPDATE
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
    DEBUG="${DEBUG:-false}"
    GIT_REF="HEAD"
    COMMIT_HASH=""
    REPO_ROOT="${REPO_ROOT}"
    FEATURE_NAMES=()
    FEATURE_PATTERN="${FEATURE_PATTERN:-^[A-Z]+-[0-9]+}"
    METADATA_SOURCE="${METADATA_SOURCE:-git}" # "git" or "metadata" (metadata to be implemented)
    LIB_DIR="${LIB_DIR}"
    [[ -z "${LIB_DIR}" ]] && LIB_DIR="${BASH_LIB_PATH%%:*}"
    [[ -z "${LIB_DIR}" ]] && LIB_DIR=$(dirname "${BASH_SOURCE[0]}/lib")

    # Taken from original as_deploy.sh
    LOG_DIR="${LOG_DIR}" # if not set by an argument, will be set using `mktemp`
    DEFAULT_LOG="${DEFAULT_LOG}" # if not set, will be set to "${LOG_DIR}/tdeploy.log"
    PREVIEW_LINES=5 # number of lines to show when displaying previews of datums (e.g. merged commits in a PR)
    MULTI_CHERRY_PICK_FILE="${MULTI_CHERRY_PICK_FILE:-cherry-pick.txt}" # if this file is added, multiple feature names will be read line by line
    CONFIG_FILE_BRANCHES="${CONFIG_FILE_BRANCHES:-./devops/branches.gv}"
    GIT_USER_NAME="${GIT_USER_NAME:-AS Deploy}"
    GIT_USER_ADDR="${GIT_USER_ADDR:-devops@trinoor}"
    SOURCE_BRANCHES=()
    TARGET_BRANCH=""

    # Script behavior
    DO_TAR_ARCHIVE=$([[ -n "${TAR_PATH}" ]] && echo true || echo false)
    BUILD_DIR="${BUILD_DIR:-./_build}"
    BUILD_FILES_DIR=""
    BUILD_CHANGELOG_FILE=""
    TAR_PATH="${TAR_PATH}"
    DO_DEPLOY=${DO_DEPLOY:-false}
    DO_PROMOTE=${DO_PROMOTE:-false}
    DO_METADATA_UPDATE=${DO_METADATA_UPDATE:-false}
    DO_PULL_REQUEST_CHECK=${DO_PULL_REQUEST_CHECK:-true}
    DO_CHERRY_PICK_CHECK=${DO_CHERRY_PICK_CHECK:-true}
    DO_EXIT_ON_CONFLICTS=${DO_EXIT_ON_CONFLICTS:-true}
    DO_REMOVE_MULTI_CHERRY_PICK_FILE=${DO_REMOVE_MULTI_CHERRY_PICK_FILE:-true}
    USE_COLORS="${USE_COLORS:-true}"

    # Not to be set by arguments
    TDEPLOY_VERSION="2.0.0"

    # Loop over the arguments
    while [[ ${#} -gt 0 ]]; do
        case ${1} in
            -h)
                help-usage
                help-epilogue
                exit 0
                ;;
            --help)
                help-full
                exit 0
                ;;
            --config-file)
                shift 1
                ;;
            --debug)
                DEBUG=true
                ;;
            --no-debug)
                DEBUG=false
                ;;
            --repo-root)
                REPO_ROOT="${2}"
                shift 1
                ;;
            --error-no-changes)
                EXIT_NO_CHANGES=2
                ;;
            --no-error-no-changes)
                EXIT_NO_CHANGES=0
                ;;
            --exit-on-conflicts)
                DO_EXIT_ON_CONFLICTS=true
                ;;
            --no-exit-on-conflicts)
                DO_EXIT_ON_CONFLICTS=false
                ;;
            --target-branch)
                TARGET_BRANCH="${2}"
                shift 1
                ;;
            --feature-pattern)
                FEATURE_PATTERN="${2}"
                shift 1
                ;;
            --release-pattern)
                RELEASE_PATTERN="${2}"
                shift 1
                ;;
            --pick-pattern)
                CHERRY_PICK_PATTERN="${2}"
                shift 1
                ;;
            --merge-pattern)
                MERGE_PATTERN="${2}"
                shift 1
                ;;
            --log-dir)
                LOG_DIR="${2}"
                shift 1
                ;;
            --log-file)
                DEFAULT_LOG="${2}"
                shift 1
                ;;
            --lib-dir)
                LIB_DIR="${2}"
                shift 1
                ;;
            --git-user-name)
                GIT_USER_NAME="${2}"
                shift 1
                ;;
            --git-user-addr)
                GIT_USER_ADDR="${2}"
                shift 1
                ;;
            --tar)
                DO_TAR_ARCHIVE=true
                ;;
            --no-tar)
                DO_TAR_ARCHIVE=false
                ;;
            --promote)
                DO_PROMOTE=true
                ;;
            --no-promote)
                DO_PROMOTE=false
                ;;
            --tar-file)
                DO_TAR_ARCHIVE=true
                TAR_PATH="${2}"
                TAR_NAME=$(basename "${TAR_PATH}")
                TAR_DIR=$(dirname "${TAR_PATH}")
                shift 1
                ;;
            --mcp-file)
                MULTI_CHERRY_PICK_FILE="${2}"
                shift 1
                ;;
            --remove-mcp-file)
                DO_REMOVE_MULTI_CHERRY_PICK_FILE=true
                ;;
            --no-remove-mcp-file)
                DO_REMOVE_MULTI_CHERRY_PICK_FILE=false
                ;;
            --build-dir)
                BUILD_DIR="${2}"
                shift 1
                ;;
            --build-files-dir)
                BUILD_FILES_DIR="${2}"
                shift 1
                ;;
            --metadata-source)
                METADATA_SOURCE="${2}"
                shift 1
                ;;
        esac
        shift 1
    done

    # After BUILD_DIR has been set, set other stuff
    BUILD_FILES_DIR="${BUILD_DIR}/files"
    BUILD_CHANGELOG_FILE="${BUILD_FILES_DIR}/tdeploy_changelog.txt"
    TAR_PATH="${TAR_PATH:-${BUILD_DIR}/tdeploy.tar}"

    # If the tar path is empty, set it to the default
    [[ -z "${TAR_PATH}" ]] && TAR_PATH="${BUILD_DIR}/tdeploy.tar"

    # Convert the git ref to a commit hash if a commit hash was not provided
    if [[ -z "${COMMIT_HASH}" ]]; then
        COMMIT_HASH=$(git rev-parse "${GIT_REF}")
    elif [[ ${#COMMIT_HASH} -ne 40 ]]; then
        # If the provided commit hash was not a full hash, convert it to one
        COMMIT_HASH=$(git rev-parse "${COMMIT_HASH}")
    fi
    # Determine the proper short hash
    COMMIT_HASH_SHORT=$(git rev-parse --short "${COMMIT_HASH}")

    # If the repo root is not set, set it to the current working directory
    if [[ -z "${REPO_ROOT}" ]]; then
        REPO_ROOT=$(git rev-parse --show-toplevel)
        if [[ -z "${REPO_ROOT}" ]]; then
            echo "ERROR: Could not determine the repo root. Please set the REPO_ROOT environment variable,"
            echo "       use the --repo-root option, or run this script from within the repo."
            return ${EXIT_GIT_ERROR}
        fi
    fi

    # If the log directory is not set, set it to a temporary directory
    if [[ -z "${LOG_DIR}" ]]; then
        LOG_DIR=$(mktemp --directory -t "tdeploy.$(date '+%Y%m%d-%H%M%S').XXXXX")
    fi

    # If the default log file is not set, set it to tdeploy.log in the log directory
    if [[ -z "${DEFAULT_LOG}" ]]; then
        DEFAULT_LOG="tdeploy.log"
    fi

    # If DEFAULT_LOG is not absolute, set it relative to LOG_DIR
    if [[ "${DEFAULT_LOG}" != /* ]]; then
        DEFAULT_LOG="${LOG_DIR}/${DEFAULT_LOG}"
    fi

    # If the target branch is not set, set it to the current branch
    if [[ -z "${TARGET_BRANCH}" ]]; then
        TARGET_BRANCH=$(git rev-parse --abbrev-ref HEAD)
    fi

    # Set the tar directory path
    TAR_DIR=$(dirname "${TAR_PATH}")

    # Validate true/false options
    if [[ "${USE_COLORS}" != "true" && "${USE_COLORS}" != "false" ]]; then
        USE_COLORS=false
    fi

    # Set up colors if enabled
    if ${USE_COLORS}; then
        C_VAR="${C_GREEN}"
        C_VAL="${C_CYAN}"
        C_FILEPATH="${C_CYAN}${S_BOLD}"
        C_FEATURE="${C_MAGENTA}${S_BOLD}"
        C_REPO="${C_BLUE}${S_BOLD}"
        C_BRANCH="${C_BLUE}"
        C_HASH="${C_YELLOW}"
        C_TIMESTAMP="${C_CYAN}"
        C_USER="${C_CYAN}${C_BOLD}"
        C_COUNT="${C_YELLOW}${S_BOLD}"
        C_SUCCESS="${C_GREEN}"
        C_FAILURE="${C_RED}"
        C_WARNING="${C_YELLOW}"
        C_BOLD="${S_BOLD}"
        C_RESET="${S_RESET}"
    else
        export ECHO_FORMATTED=false # decolorize `echo-formatted` function
    fi
}

function help-usage() {
    echo "usage: $(basename "${0}") [-h] "
}

function help-full() {
    help-usage
    help-epilogue
}


## helpful functions ###########################################################
################################################################################
# @section helpful functions
# @description Functions which are helpful for other functions

# @description Set the git user name and email
# @arg $1 string The git user name
# @arg $2 string The git user email
# @example
#     set-git-user "AS Deploy" "devops@trinoor"
function set-git-user() {
    local name="${1}"
    local addr="${2}"
    [[ -z "${name}" ]] && return 1
    git config --local user.name "${name}"
    [[ -n "${addr}" ]] && git config --local user.email "${addr}"
}

# @description Print a variable and its value using colors if enabled
# @arg $1 string The variable name
# @arg $2 string The variable value
# @usage echo-var <var_name> [<var_value>]
# @example echo-var foo bar
# @example echo-var foo
function echo-var() {
    local var_name="${1}"
    local var_value="${2}"
    [[ -z "${var_name}" ]] && return 1
    if [[ -z "${var_value}" ]] && declare -p "${var_name}" 2>&1 >/dev/null; then
        var_value="${!var_name}"
    else
        var_value="<unset>"
    fi
    echo -e "${C_VAR}${var_name}${C_RESET} = ${C_VAL}${var_value}${C_RESET}"
}

## main function ###############################################################
################################################################################
# @section main function
# @description The main function of the script

function main() {
    parse-args "${@}" || return ${?}

    local shell_version is_merge=false is_cherry_pick=false is_direct=false is_multi_cherry_pick=false
    local commit_status commit_summary commit_files commit_file_status commit_file
    local feature_names feature_name last_target_ts after_ts before_ts
    local promotion_files promotion_pattern release_message pick_message merge_message
    local remote
    local source_branches=()
    local changelog_commit_hashes
    local changelog_files=() changelog_files_deleted=() changelog_files_updated=()
    local changelog_file
    local changelog_file_status
    local file_str
    local features_with_changes=() feature_files_deleted=() feature_files_updated=()
    local s

    # Display tdeploy header
    ## OS
    [[ -f "/etc/os-release" ]] \
        && awk '/PRETTY_NAME=/ {gsub(/^\w+="/, ""); gsub(/"$/, ""); printf $0}' /etc/os-release
    ## Shell
    shell_version=$(${shell} --version 2>/dev/null | head -n 1)
    [[ -n "${shell_version}" ]] && echo " | ${shell_version}" || echo
    ## Script
    print-header "Trinoor Deployments v${TDEPLOY_VERSION}"

    # Now that the debug lib is loaded, debug some variables
    debug-vars \
        DEBUG COMMIT_HASH REPO_ROOT FEATURE_NAMES FEATURE_PATTERN \
        METADATA_SOURCE PROGRESS_BAR_STEPS PROGRESS_BAR_MIN_INTERVAL LIB_DIR \
        LOG_DIR DEFAULT_LOG CONFIG_FILE GIT_USER_NAME GIT_USER_ADDR \
        SOURCE_BRANCHES TARGET_BRANCH TAR_PATH DO_TAR_ARCHIVE DO_DEPLOY \
        DO_PROMOTE DO_METADATA_UPDATE USER

    # Set the git user name and email
    check-command "set-git-user '${GIT_USER_NAME}' '${GIT_USER_ADDR}'" \
        "Setting git user to '${GIT_USER_NAME} <${GIT_USER_ADDR}>'"
    check-command "git config push.default current" \
        "Setting git push.default to 'current'"

    # Some some basic run information
    cd "${REPO_ROOT}"
    echo-var "COMMIT" "${COMMIT_HASH_SHORT}"
    echo-var "TARGET BRANCH" "${TARGET_BRANCH}"

    # Determine the commit type. If this is a cherry-pick, we'll determine
    # futher down whether it's a single or multi cherry-pick.
    local commit_type
    if is-merge-commit "${COMMIT_HASH}"; then
        is_merge=true
        commit_type="MERGE"
        echo-var "COMMIT TYPE" "${commit_type}"
    else
        is_merge=false
        commit_type="DIRECT"
    fi

    # We will need to generate a `changelog_files` array which contains a
    # `git --name-status` style array of every changed object and its change
    # status. This will be used to determine which changelog files to update
    # and how to update them. e.g.:
    #     changelog_files=("M\tCHANGELOG.md" "A\tREADME.md" "D\tLICENSE")
    
    # If this is a merge, then display the merged commits
    if ${is_merge}; then
        printf "Generating list of merged commits ... "
        readarray -t changelog_commit_hashes < <(
            git -c color.ui=always log "${COMMIT_HASH}^..${COMMIT_HASH}" \
                --format='%H%x09%ae%x09%s' \
                    | awk -F $'\t' -v commit="${COMMIT_HASH}" -v email="${GIT_USER_ADDR}" '
                        # Do not process the merge commit itself
                        $1 !~ commit {
                            # Do not process commits from the build agent
                            # EXCEPT when the commit message starts with:
                            # "Cherry-picking for ..." or "Revert ..."
                            # OR when the commit message ends with:
                            # " Release"
                            # TODO: update this to use the cherry-pick and release patterns
                            if ($2 != email || $3 ~ /^(Cherry-picking for|Revert) /) {
                                # gsub(/@.*/, "", $2);
                                # printf "  - %s %s %-18s  %s\n", $1, $2, tolower(email), $3;
                                print $1;
                            }
                        }
                    '
        )
        echo-formatted -g "${#changelog_commit_hashes[@]} commits"
        for commit_hash in "${changelog_commit_hashes[@]}"; do
            git -c color.ui=always log -1 "${commit_hash}" \
                --date=format-local:'%Y-%m-%d %H:%M:%S' \
                --format='%C(green)%h%x09%C(magenta)%ad%C(yellow)%x09%ae%x09%C(reset)%s'
        done | column -t -s $'\t' | sed -e 's/^/  - /'

        # TODO: Update metadata file by looping over each commit in the PR

        # Now determine the changelog based on the merged files
        # array format:
        #   git_name_status \t filepath \t commit_hash \t commit_ts_epoch \t commit_ts_readable \t "pull_request" \t commit_message
        echo -n "Generating changelog for merged commits ... "
        readarray -t changelog_files < <(
            git log -1 "${COMMIT_HASH}" \
                --pretty=format:"[commit]%x09%H%x09%at%x09%ad%x09pull_request%x09%s" \
                --date=format-local:'%Y-%m-%d %H:%M:%S' \
                --name-status \
                --no-renames \`
                --first-parent -m \
                    | awk -F $'\t' -v commit_hash="${COMMIT_HASH}" '{
                        if ($1 == "[commit]") {
                            commit_hash=$2;
                            commit_ts_epoch=$3;
                            commit_ts_readable=$4;
                            pull_request=$5;
                            commit_message=$6;
                        } else {
                            print $0 "\t" commit_hash "\t" commit_ts_epoch "\t" commit_ts_readable "\t" "pull_request" "\t" commit_message;
                        }
                    }'
        )
        echo-formatted -g "${#changelog_files[@]} objects"
    else
        # This is a direct commit, so determine if this is a cherry-pick
        
        # If this is a cherry-pick, then determine through either git history
        # or the metadata file what files should be included in the changelog
        # We'll want to determine what this branch's parent/s is/are and then
        # determine what files were changed in those commits since the last
        # cherry-pick to this branch
        
        # This will be a cherry-pick if there is only one file added in the root
        # of the repo with a name which matches $FEATURE_PATTERN
        readarray -t commit_status < <(git log -1 "${COMMIT_HASH}" --name-status --no-renames --format="%s")
        commit_summary="${commit_status[0]}"
        commit_files=("${commit_status[@]:2}")
        # If there was a single changelog file added which matches the feature
        # name pattern, then this is a cherry-pick
        commit_file_status=$(echo "${commit_files[0]}" | awk -F $'\t' '{print $1}')
        commit_file=$(echo "${commit_files[0]}" | awk -F $'\t' '{print $2}')
        if [[
            "${commit_file_status}" == "A"
            && "${commit_file}" =~ ${FEATURE_PATTERN} 
            && "${#commit_files[@]}" -eq 1
        ]]; then
            # this is a cherry-pick of a single feature
            commit_type+=" (cherry-pick)"
            feature_names=("${commit_file}")
            is_cherry_pick=true
        elif [[
            "${commit_file_status}" =~ ^"A|M"$
            && "${commit_file}" == "${MULTI_CHERRY_PICK_FILE}" 
            && "${#commit_files[@]}" -eq 1
        ]]; then
            # this is a cherry-pick of multiple features
            readarray -t feature_names < <(
                git show "${COMMIT_HASH}:${MULTI_CHERRY_PICK_FILE}" \
                    | grep -Ev '^#|^$'
            )
            commit_type+=" (multi cherry-pick)"
            is_cherry_pick=true
            is_multi_cherry_pick=true
        else
            echo-formatted -g " COMMIT"
            is_direct=true
        fi

        # Go ahead and display the commit type
        echo-var "COMMIT TYPE" "${commit_type}"
        s=$([[ ${#feature_names[@]} -gt 0 ]] && echo "S" || echo "")
        echo-var "CHERRY-PICK FEATURE${s}" "${feature_names[*]}"

        if ${is_cherry_pick}; then
            changelog_files=()
            # Determine the parent branch(es) and all files promoted since the
            # last cherry-pick to this branch.
            if [[ ${#SOURCE_BRANCHES[@]} -gt 0 ]]; then
                # If source branches were manually specified, then use those...
                source_branches=("${SOURCE_BRANCHES[@]}")
            else
                # ...else read them from the branch config file
                readarray -t source_branches < <(
                    get-parent-branches "${TARGET_BRANCH}" -f "${CONFIG_FILE_BRANCHES}"
                )
            fi

            # Print the source branches
            echo-formatted -y "SOURCE BRANCHES" -- "=" -c "${source_branches[*]}"

            # Loop over the parent branches, determine the appropriate
            # cherry-pick date range, and then determine the files that were
            # promoted in that range.
            remote=$(git remote)
            echo -n "Determining changelog files ... "
            for feature_name in "${feature_names[@]}"; do
                release_message=$(generate-release-message "${feature_name}")
                pick_message=$(generate-pick-message "${feature_name}")
                merge_message=$(generate-merge-message "${feature_name}")
                promotion_pattern="^${release_message}|${pick_message}|${merge_message}$"
                last_target_ts=$(
                    get-last-promotion "${feature_name}" "${TARGET_BRANCH}" \
                        | awk '{print $1}'
                )
                for source_branch in "${source_branches[@]}"; do
                    # after_ts -- the lower bound of the cherry-pick date range
                    # this will be the timestamp of the last promotion from the
                    # parent branch prior to the last promotion to the target
                    # branch
                    git rev-parse --verify "${remote}/${source_branch}" >/dev/null 2>&1 || continue
                    after_ts=$(
                        get-last-promotion \
                            "${feature_name}" \
                            "${source_branch}" \
                            --before "${last_target_ts}" \
                            2>/dev/null \
                                | awk '{print $1}'
                    )
                    # before_ts -- the upper bound of the cherry-pick date range
                    # this will be the timestamp of the last promotion to the
                    # source branch
                    before_ts=$(
                        get-last-promotion "${feature_name}" "${source_branch}" \
                            | awk '{print $1}'
                    )
                    # Get the list of files promoted in the cherry-pick date range
                    # array format:
                    #   git_name_status \t filepath \t commit_hash \t commit_ts_epoch \t commit_ts_readable \t feature_name \t source_branch
                    readarray -t promotion_files < <(
                        git log \
                            --pretty=format:"[commit]%x09%H%x09%at%x09%ad%x09${feature_name}%x09${source_branch}" \
                            --date=format-local:'%Y-%m-%d %H:%M:%S' \
                            --name-status \
                            --no-renames \
                            --after="${after_ts}" \
                            --before="${before_ts}" \
                            --first-parent -m \
                            -E --grep="${promotion_pattern}" \
                            "${remote}/${source_branch}" \
                                | awk -F $'\t' -v feature_name="${feature_name}" '{
                                    if ($1 == "[commit]") {
                                        commit_hash=$2;
                                        commit_ts_epoch=$3;
                                        commit_ts_readable=$4;
                                        feature_name=$5;
                                        branch=$6;
                                    } else {
                                        # print $0 "\t" commit_hash "\t" commit_ts_epoch "\t" commit_ts_readable "\t" feature_name "\t" branch;
                                        printf("%s\t%s\t%s\t%s\t%s\t%s\n",
                                               $0,
                                               commit_hash,
                                               commit_ts_epoch,
                                               commit_ts_readable,
                                               feature_name,
                                               branch);
                                    }
                                }'
                    )
                    if [[ ${#promotion_files[@]} -gt 0 ]]; then
                        changelog_files+=("${promotion_files[@]}")
                    fi
                    debug-vars feature_name source_branch after_ts before_ts promotion_files
                done
            done
        fi
    fi

    # Print the changelog files if we have any
    if [[ ${#changelog_files[@]} -gt 0 ]]; then
        echo -e "${C_COUNT}${C_SUCCESS}${#changelog_files[@]} file changes${C_RESET}"
        for changelog_file in "${changelog_files[@]}"; do
            file_path=$(echo "${changelog_file}" | awk -F $'\t' '{print $2}')
            file_str="${file_path}"
            if ${is_cherry_pick}; then
                # Get the feature branch
                feature_name=$(echo "${changelog_file}" | awk -F $'\t' '{print $6}')
                file_str="(${feature_name}) ${file_str}"
            fi
            echo "  - ${file_str}"
        done
    else
        # No changes found, exit
        echo -e "${C_COUNT}${C_FAILURE}0 file changes${C_RESET}"
        echo -e "${C_FAILURE}No changes found, exiting${C_RESET}"
        return ${EXIT_NO_CHANGES}
    fi

    # Update the changelog array:
    # - sort by timestamp > filepath with the oldest first
    # - remove duplicates (keeping the newest version of each duplicate occurence of a file)
    readarray -t changelog_files < <(
        printf "%s\n" "${changelog_files[@]}" \
            | sort -n -k 4,4 -k 2,2 \
            | awk -F $'\t' '!seen[$2]++'
    )
    ## get the list of deleted files...
    readarray -t changelog_files_deleted < <(
        printf "%s\n" "${changelog_files[@]}" \
            | awk -F $'\t' '$1 == "D" {print}'
    )
    ## ...and everything else (updated, added, renamed, etc)
    readarray -t changelog_files_updated < <(
        printf "%s\n" "${changelog_files[@]}" \
            | awk -F $'\t' '$1 != "D" {print}'
    )
    # Collect a list of each feature name with changes
    readarray -t features_with_changes < <(
        printf "%s\n" "${changelog_files[@]}" \
            | awk -F $'\t' '{print $6}' \
            | sort -u
    )
    debug-vars \
        changelog_files changelog_files_deleted \
        changelog_files_updated features_with_changes

    # If we're creating a tar archive or promoting cherry-picked files, we need
    # to checkout each file to the build directory, then update their timestamps
    if ${DO_TAR_ARCHIVE} || (${is_cherry_pick} && ${DO_PROMOTE}); then
        print-header -B 1 "CHECKOUT FILES"

        # If $BUILD_FILES_DIR already exists, then delete it
        if [[ -d "${BUILD_FILES_DIR}" ]]; then
            rm -rf "${BUILD_FILES_DIR}"
        fi

        # Make sure the tar and build directories exist
        mkdir -p "${TAR_DIR}"
        mkdir -p "${BUILD_DIR}"
        mkdir -p "${BUILD_FILES_DIR}"

        # Check out each file to the build directory, then update their
        # timestamps and executable bits
        echo -n "Checking out files to build directory '${BUILD_FILES_DIR}' ... "
        for file_info in "${changelog_files_updated[@]}"; do
            # changelog formats:
            ## merged commit:
            ###   git_name_status \t filepath \t commit_hash \t commit_ts_epoch \t commit_ts_readable \t "pull_request" \t commit_message
            ## cherry-pick commit:
            ###   git_name_status \t filepath \t commit_hash \t commit_ts_epoch \t commit_ts_readable \t feature_name \t source_branch

            # Get the filepath, commit hash, and timestamp
            file_status=$(echo "${file_info}" | awk -F $'\t' '{print $1}')
            file_path=$(echo "${file_info}" | awk -F $'\t' '{print $2}')
            file_commit_hash=$(echo "${file_info}" | awk -F $'\t' '{print $3}')
            file_ts_epoch=$(echo "${file_info}" | awk -F $'\t' '{print $4}')

            # Set up the destination build directory and file path
            file_dest="${BUILD_FILES_DIR}/${file_path}"
            file_dest_dir=$(dirname "${file_dest}")
            mkdir -p "${file_dest_dir}"

            # Check out the file
            git show "${file_commit_hash}:${file_path}" > "${file_dest}"

            # Update the timestamp
            touch -d "@${file_ts_epoch}" "${file_dest}"

            # Update the file mode
            file_mode=$(git-file-mode "${file_path}" "${file_commit_hash}")
            if [[ "${file_mode}" == 755 ]]; then
                chmod +x "${file_dest}"
            fi
        done
        echo -e "${C_SUCCESS}done${C_RESET}"
    fi

    # Create a tar archive
    if ${DO_TAR_ARCHIVE}; then
        print-header -B 1 "ARCHIVING CHANGES"
        echo -e "Creating tar archive '${C_FILEPATH}${TAR_PATH}${C_RESET}' ... "

        tar -cf "${TAR_PATH}" -C "${REPO_ROOT}" "${BUILD_FILES_DIR}" --transform "s:^${BUILD_FILES_DIR}/::"

        # Create a text file with the changelog
        echo "# $(date)" > "${BUILD_CHANGELOG_FILE}"
        printf "%s\n" "${changelog_files[@]}" > "${BUILD_CHANGELOG_FILE}"

        # Add the changelog to the root of the tar archive
        # tar -rf "${TAR_PATH}" -C "${TAR_DIR}" "${BUILD_CHANGELOG_FILE}"
        tar \
            -rf "${TAR_PATH}" \
            -C "${REPO_ROOT}" \
            --transform "s,^.*/,," \
            "${BUILD_CHANGELOG_FILE}"
        
        # Remove the build directory from the tar archive
        tar --delete -f "${TAR_PATH}" "${BUILD_FILES_DIR}"

        echo -e "${C_SUCCESS}done${C_RESET}"
    fi

    if ${is_cherry_pick}; then
        print-header -B 1 "CONFLICT CHECK"

        local valid_conflicts=()
        local conflict_git_args=()

        ## 1. source_branches = get source branches for the target branch
        ## 2. changelog_files = all files being promoted
        ## 3. features_with_changes = all features being promoted
        ## 4. for file in changelog_files:
            ## 5. last_promotion_time = last time `file` was promoted to the target branch
            ## 6. for source_branch in source_branches:
                ## 7. conflicts = get all promotions for `file` to `source_branch` since `last_promotion_time`
                ## 8. for conflict in conflicts:
                    ##  9. feature_name = extract feature name from conflict
                    ## 10. if feature_name not in features_with_changes:
                        ## 11. print filename, feature_name, conflicting commit, conflicting branch

        for changelog_file in "${changelog_files[@]}"; do
            # get the filepath
            file_path=$(echo "${changelog_file}" | awk -F $'\t' '{print $2}')
            file_feature=$(echo "${changelog_file}" | awk -F $'\t' '{print $6}')

            # get the last promotion time to the target branch
            conflict_git_args=()
            last_promotion_time=$(
                git log -1 "${TARGET_BRANCH}" --format="%at" -- "${file_path}"
            )
            [[ -n "${last_promotion_time}" ]] && conflict_git_args+=("--since=${last_promotion_time}")

            # check the source branches for conflicts
            for source_branch in "${source_branches[@]}"; do
                debug "checking for conflicts on file '${file_path}' from branch '${source_branch}'"
                debug-vars last_promotion_time conflict_git_args

                readarray -t conflicts < <(
                    git log \
                        "${conflict_git_args[@]}" \
                        --first-parent -m \
                        --format="%h%x09%an%x09%ae%x09%ad%x09${source_branch}%x09%s" \
                        --date=format:'%Y-%m-%d %H:%M:%S' \
                        --no-renames \
                        "${remote}/${source_branch}" \
                        -- "${file_path}" 2>/dev/null
                )

                # exclude any conflicts that are included in the current promotion list (for multi-cherry-picks)
                for conflict_info in "${conflicts[@]}"; do
                    # attempt to extract a feature name from the commit message
                    local conflict_commit_message=$(
                        cut -d$'\t' -f6- <<< "${conflict_info}"
                    )
                    local conflict_feature_name=$(
                        echo "${conflict_commit_message}" | grep -Eo "${FEATURE_PATTERN}"
                    )

                    # if a feature name was found, check whether it's in the list
                    if ! is-in "${conflict_feature_name}" "${features_with_changes[@]}"; then
                        # if the feature name is not in the list, this is a conflict
                        valid_conflicts+=("${conflict_info}")
                    fi
                done

                # loop over and print all valid conflicts for this file
                if [[ ${#valid_conflicts[@]} -gt 0 ]]; then
                    echo -e  "${C_FAILURE}${C_BOLD}== CONFLICT ==${C_RESET}"
                    echo-formatted "The file '${C_FILEPATH}${file_path}${C_RESET}' (${C_FEATURE}${file_feature}${C_RESET}) was also modified by:"
                    for valid_conflict in "${valid_conflicts[@]}"; do
                        conflict_hash=$(cut -d$'\t' -f1 <<< "${valid_conflict}")
                        conflict_author_name=$(cut -d$'\t' -f2 <<< "${valid_conflict}")
                        conflict_author_email=$(cut -d$'\t' -f3 <<< "${valid_conflict}")
                        conflict_timestamp=$(cut -d$'\t' -f4 <<< "${valid_conflict}")
                        conflict_branch=$(cut -d$'\t' -f5 <<< "${valid_conflict}")
                        conflict_commit_message=$(
                            cut -d$'\t' -f6- <<< "${valid_conflict}"
                        )
                        local conflict_str
                        conflict_str="[${C_HASH}${conflict_hash}${C_RESET}  ${C_TIMESTAMP}${conflict_timestamp}${C_RESET}] "
                        conflict_str+="${C_USER}${conflict_author_name} <${conflict_author_email}>${C_RESET}"
                        conflict_str+=" on branch '${C_BRANCH}${conflict_branch}${C_RESET}' "
                        conflict_str+="-- ${conflict_commit_message}"
                        echo -e "- ${conflict_str}"
                        echo # space between each conflict
                    done
                    echo # space between last conflict and conflict summary
                fi
            done
        done

        # Print a summary of the conflicts
        local summary_color=$([[ ${#valid_conflicts[@]} -gt 0 ]] && echo "${C_FAILURE}" || echo "${C_SUCCESS}")
        echo -e "${summary_color}${C_BOLD}== CONFLICT SUMMARY ==${C_RESET}"
        if [[ ${#valid_conflicts[@]} -gt 0 ]]; then
            s=$([[ ${#valid_conflicts[@]} -ne 1 ]] && echo "s")
            # echo-formatted -Br "${#valid_conflicts[@]}" -- -r "conflict${s} found"
            echo -e "${C_FAILURE}${C_COUNT}${#valid_conflicts[@]}${C_RESET} ${C_FAILURE}conflict${s} found${C_RESET}"

            if ${DO_EXIT_ON_CONFLICTS}; then
                echo -e "${C_FAILURE}Exiting due to conflicts${C_RESET}"
                echo "Please use a multi cherry-pick to promote all conflicting features"
                return ${EXIT_CONFLICTS}
            fi
        else
            echo -e "${C_SUCCESS}No conflicts found${C_RESET}"
        fi
    fi

    # Promote the files to the target branch
    if ${is_cherry_pick} && ${DO_PROMOTE}; then
        print-header -B 1 "PROMOTE TO ${TARGET_BRANCH}"

        # Check out the target branch and sync it with the remote
        git checkout -f "${TARGET_BRANCH}"
        git-sync

        echo "Promoting files to ${TARGET_BRANCH} ..."

        # Loop over each feature name and promote its files
        for feature_name in "${features_with_changes[@]}"; do
            echo "  - ${feature_name} ... "

            # Get an array of deleted files for this feature
            readarray -t feature_files_deleted < <(
                printf "%s\n" "${changelog_files_deleted[@]}" \
                    | awk -F $'\t' -v feature_name="${feature_name}" '$6 == feature_name {print}'
            )

            # Get an array of updated files for this feature
            readarray -t feature_files_updated < <(
                printf "%s\n" "${changelog_files_updated[@]}" \
                    | awk -F $'\t' -v feature_name="${feature_name}" '$6 == feature_name {print}'
            )

            debug-vars feature_files_deleted feature_files_updated

            {
                # Delete the files that need deleting
                for file_info in "${feature_files_deleted[@]}"; do
                    file_path=$(echo "${file_info}" | awk -F $'\t' '{print $2}')
                    rm -vf "${file_path}"
                    git add -- "${file_path}"
                done

                # Update the files that need updating
                for file_info in "${feature_files_updated[@]}"; do
                    # Get the filepath, commit hash, and timestamp
                    file_path=$(echo "${file_info}" | awk -F $'\t' '{print $2}')
                    file_commit_hash=$(echo "${file_info}" | awk -F $'\t' '{print $3}')

                    # Check out the file from the commit
                    git checkout "${file_commit_hash}" -- "${file_path}"
                    git add -- "${file_path}"
                done

                # Delete the trigger file(s)
                if ! ${is_multi_cherry_pick}; then
                    if [[ -f "${feature_name}" ]]; then
                        rm -v "${feature_name}"
                        git add -- "${feature_name}"
                    fi
                fi

                # Set up the commit message
                commit_message=$(generate-pick-message "${feature_name}")
                git commit -m "${commit_message}"
                git push
            } 2>&1 | sed -e 's/^/    /'
        done

        # If this was a multi-cherry-pick, then delete the trigger file
        if ${is_multi_cherry_pick} and ${DO_REMOVE_MULTI_CHERRY_PICK_FILE}; then
            echo "  - removing trigger file '${MULTI_CHERRY_PICK_FILE}'"
            {
                rm -v "${MULTI_CHERRY_PICK_FILE}"
                git add -- "${MULTI_CHERRY_PICK_FILE}"
                git commit -m "Delete ${MULTI_CHERRY_PICK_FILE}"
                git push
            } 2>&1 | sed -e 's/^/    /'
        fi
    fi
}


## run #########################################################################
################################################################################

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && main "${@}"
