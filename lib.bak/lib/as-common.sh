LIB_DIR="${LIB_DIR:-$(dirname "${BASH_SOURCE[0]}")}"

# Load dependencies
source "${LIB_DIR}/git.sh"
source "${LIB_DIR}/debug.sh"
source "${LIB_DIR}/text.sh"

## Default values
[[ -z "${FEATURE_PATTERN}" ]] && FEATURE_PATTERN="AS9-[A-Z]{3,5}-[A-Z]{,5}-[0-9]{,4}"
[[ -z "${RELEASE_PATTERN}" ]] && RELEASE_PATTERN="{{feature}} Release"
[[ -z "${MERGE_PATTERN}" ]] && MERGE_PATTERN="Merged in {{feature}} .*"
[[ -z "${CHERRY_PICK_PATTERN}" ]] && CHERRY_PICK_PATTERN="Cherry-picking for {{feature}}"

# Load the above values from this project's config file if present
## look, in order, for:
## - an AS_CONFIG environment variable
## - a config file in {repo}/devops
## - a config file in the repo root (assuming we are in a repo)
## - a config file in the current directory
__AS_CONFIG_VAR="${AS_CONFIG}"
__AS_CONFIG_DVO=$(
    git rev-parse --is-inside-work-tree &>/dev/null &&
        root=$(git rev-parse --show-toplevel 2>/dev/null) &&
        echo "${root}/devops/.as-config.sh"
)
__AS_CONFIG_GIT=$(
    git rev-parse --is-inside-work-tree &>/dev/null &&
        root=$(git rev-parse --show-toplevel 2>/dev/null) &&
        echo "${root}/.as-config.sh"
)
__AS_CONFIG_DIR="./.as-config.sh"
AS_CONFIG="${__AS_CONFIG_VAR:-${__AS_CONFIG_DVO:-${__AS_CONFIG_GIT:-${__AS_CONFIG_DIR}}}}"
if [[ -f "${AS_CONFIG}" && -r "${AS_CONFIG}" ]]; then
    source "${AS_CONFIG}"
fi

# @description Generate a feature release commit message
# @usage generate-release-message <feature-name>
function generate-release-message() {
    local feature_name="${1}"
    if [[ -z "${feature_name}" ]]; then
        echo "usage: generate-release-message <feature-name>"
        return 1
    fi

    local release_message="${RELEASE_PATTERN}"
    release_message="${release_message//\{\{feature\}\}/${feature_name}}"
    echo "${release_message}"
}

# @description Generate a cherry-pick commit message
# @usage generate-cherry-pick-message <feature-name>
function generate-pick-message() {
    local feature_name="${1}"
    if [[ -z "${feature_name}" ]]; then
        echo "usage: generate-pick-message <feature-name>"
        return 1
    fi

    local cherry_pick_message="${CHERRY_PICK_PATTERN}"
    cherry_pick_message="${cherry_pick_message//\{\{feature\}\}/${feature_name}}"
    echo "${cherry_pick_message}"
}

# @description Generate a merge commit message
# @usage generate-merge-message <feature-name>
function generate-merge-message() {
    local feature_name="${1}"
    if [[ -z "${feature_name}" ]]; then
        echo "usage: generate-merge-message <feature-name>"
        return 1
    fi

    local merge_message="${MERGE_PATTERN}"
    merge_message="${merge_message//\{\{feature\}\}/${feature_name}}"
    echo "${merge_message}"
}

# @description Convert a branch flow file to a digraph file
# @usage branch-flow-to-digraph <branch-flow-file>
function branch-flow-to-digraph() {
    local branch_flow_file="${1}"
    if [[ "${branch_flow_file}" == "-" ]]; then
        branch_flow_file="/dev/stdin"
    fi

    if [[ -z "${branch_flow_file}" ]]; then
        echo "usage: branch-flow-to-digraph <branch-flow-file>"
        return 1
    fi

    local branch_flow=$(cat "${branch_flow_file}")

    echo "digraph G {"
    echo "  node [shape=box, fontname=Arial];"
    echo "${branch_flow}" \
        | tr -d '"' \
        | sed -E $'s/^[ \t]*([^ ]+)[ \t]*->[ \t]*([^ ]+)(.*)/  "\\1" -> "\\2"\\3/'
    echo "}"
}

# @description Convert a branch flow file to an image (requires graphviz)
# @usage branch-flow-to-image <branch-flow-file> <image-file>
function branch-flow-to-image() {
    local branch_flow_file="${1}"
    local image_file="${2:-/dev/stdout}"

    if [[ -z "${branch_flow_file}" || -z "${image_file}" ]]; then
        echo "usage: branch-flow-to-image <branch-flow-file> <image-file>"
        return 1
    fi

    local extension="${image_file##*.}"
    [[ "${extension}" == "${image_file}" ]] && extension="svg"
    local digraph=$(branch-flow-to-digraph "${branch_flow_file}")

    echo "${digraph}" | dot -T"${extension}" -o "${image_file}"
}

# @description Get the parent branches for a given branch
# @usage get-parent-branches [-f <flow-file>] <branch-name>
function get-parent-branches() {
    local branch_name
    local flow_file="./branches.gv"

    # Parse options
    while [[ $# -gt 0 ]]; do
        case "${1}" in
            -f | --flow-file)
                flow_file="${2}"
                shift 2
                ;;
            -*)
                echo "error: unknown option: ${1}" >&2
                return 1
                ;;
            *)
                [[ -z "${branch_name}" ]] && branch_name="${1}"
                shift
                ;;
        esac
    done

    debug "get-parent-branches: branch_name=${branch_name} flow_file=${flow_file}"

    if [[ -z "${branch_name}" ]]; then
        echo "usage: get-parent-branch <branch-name> [-f <flow-file>]"
        return 1
    fi

    local branch_flow=$(cat "${flow_file}")
    local parent_branch=$(
        echo "${branch_flow}" \
            | grep -E "[ \t]*->[ \t]*${branch_name}" \
            | sed -E 's/[ \t]*->[ \t]*.*//'
    )
    echo "${parent_branch}"
}

# @description Get the options for a merge given the source and target branches
# @usage get-merge-options [-eESiVpP] [-s <source-branch>] [-t <target-branch>] [-o <option>] [-f <flow-file>]
function get-branch-option() {
    # Default values
    local source_branch_regex=""
    local target_branch_regex=""
    local do_regex=false
    local do_strict=true
    local do_value_only=false
    local do_pretty=false
    local option_name=""
    local flow_file="./branches.gv"

    # Parse options
    do_value_only_specified=false
    while [[ $# -gt 0 ]]; do
        case "${1}" in
            -s | --source-branch)
                source_branch_regex="${2}"
                shift 2
                ;;
            -t | --target-branch)
                target_branch_regex="${2}"
                shift 2
                ;;
            -o | --option)
                option_name="${2}"
                shift 2
                ;;
            -f | --flow-file)
                flow_file="${2}"
                shift 2
                ;;
            -E | --regex)
                do_regex=true
                shift
                ;;
            -e | --no-regex)
                do_regex=false
                shift
                ;;
            -S | --strict)
                do_strict=true
                shift
                ;;
            --no-strict)
                do_strict=false
                shift
                ;;
            -p | --pretty)
                do_pretty=true
                shift
                ;;
            -P | --no-pretty)
                do_pretty=false
                shift
                ;;
            -V | --value-only)
                do_value_only=true
                do_strict=true
                do_value_only_specified=true
                shift
                ;;
            -i | --include-keys)
                do_value_only=false
                do_value_only_specified=true
                shift
                ;;
            *)
                echo "usage: get-branch-option [-s <source-branch>] [-t <target-branch>] [-o <option>] [-f <flow-file>]"
                return 1
                ;;
        esac
    done

    if ${do_value_only} && ! ${do_strict}; then
        echo "error: --value-only must be used with --strict"
    fi

    if [[ -n "${option_name}" ]] && ! ${do_value_only_specified}; then
        do_value_only=true
    fi

    if [[ "${flow_file}" == "-" ]]; then
        flow_file="/dev/stdin"
    fi
    local flow_content=$(cat "${flow_file}")

    readarray -t matching_options < <(
        echo "${flow_content}" | while read -r line; do
            local source_branch=$(echo "${line}" | sed -E 's/^[ \t]*([^ ]+)[ \t]*->[ \t]*([^ ]+)(.*)/\1/')
            local target_branch=$(echo "${line}" | sed -E 's/^[ \t]*([^ ]+)[ \t]*->[ \t]*([^ ]+)(.*)/\2/')
            local options=$(echo "${line}" | sed -E 's/^[ \t]*([^ ]+)[ \t]*->[ \t]*([^ ]+)(.*)/\3/')

            if [[ -n "${source_branch_regex}" ]]; then
                if ${do_regex}; then
                    ! [[ "${source_branch}" =~ ${source_branch_regex} ]] && continue
                else
                    [[ "${source_branch}" != "${source_branch_regex}" ]] && continue
                fi
            fi

            if [[ -n "${target_branch_regex}" ]]; then
                if ${do_regex}; then
                    ! [[ "${target_branch}" =~ ${target_branch_regex} ]] && continue
                else
                    [[ "${target_branch}" != "${target_branch_regex}" ]] && continue
                fi
            fi

            # Parse the options, trimming leading/trailing whitespace and brackets,
            # and replacing commas with newlines
            local options=$(
                echo "${options}" \
                    | sed -E 's/^ *\[//;s/\] *$//' \
                    | sed -Ee :1 -e 's/^(([^",]|"[^"]*")*),/\1\n/;t1' \
                    | sed 's/^ *//;s/ *$//'
            )
            debug "all options for source/target branch: ${options}"

            if [[ -n "${option_name}" ]]; then
                options=$(echo "${options}" | grep -E "^${option_name}=")
            fi
            [[ -n "${options}" ]] && echo "${options}"
        done
    )

    # If strict mode is enabled, there should only be one option
    if ${do_strict}; then
        if [[ "${#matching_options[@]}" -gt 1 ]]; then
            echo "error: multiple options found, use --no-strict to get all options"
            return 1
        fi
    fi

    # If value-only mode is enabled, only the value should be returned
    if ${do_value_only}; then
        debug "do_value_only=${do_value_only}, stripping option names"
        matching_options=($(printf '%s\n' "${matching_options[@]}" | sed -E 's/^[^=]+=//'))
    fi

    debug "matching options: ${matching_options[@]}"

    local opt val
    printf '%s\n' "${matching_options[@]}" | while read -r line; do
        debug "parsing option: ${line}"
        if ${do_value_only}; then
            val="${line}"
        else
            opt="${line%%=*}"
            val="${line#*=}"
        fi
        if ${do_pretty}; then
            debug "prettifying value"
            val="${val#\"}"
            val="${val%\"}"
            # Replace escaped characters
            val=$(printf '%b' "${val}" | sed 's/\\"/"/g')
        fi
        if ${do_value_only}; then
            echo "${val}"
        else
            echo "${opt}=${val}"
        fi
    done

}

# @description Get the timestamp, hash, and number of committed files for the last cherry-pick or release for a feature into a branch
# @usage get-last-promotion <feature> [--branch <branch>] [--before <date>] [--after <date>]
function get-last-promotion() {
    local branch feature before_ts after_ts
    local git_args=() remote
    local release_message pick_message merge_message promotion_pattern
    local promotion_list
    local found_promotion=false
    local use_trigger_ts=true trigger_ts_found=false

    # parse args
    while [[ $# -gt 0 ]]; do
        debug "processing arg: ${1}"
        case "${1}" in
            -r | --branch)
                shift 1
                branch="${1}"
                ;;
            -b | --before | --until)
                shift 1
                before_ts="${1}"
                ;;
            -a | --after | --since)
                shift 1
                after_ts="${1}"
                ;;
            --use-trigger-timestamp)
                use_trigger_ts=true
                ;;
            --no-use-trigger-timestamp)
                use_trigger_ts=false
                ;;
            *)
                if [[ -z "${feature}" ]]; then
                    feature="${1}"
                elif [[ -z "${branch}" ]]; then
                    branch="${1}"
                else
                    debug error "unknown argument: ${1}"
                    return 1
                fi
                ;;
        esac
        shift
    done

    [[ -z "${branch}" ]] && branch="$(git rev-parse --abbrev-ref HEAD)"
    [[ -z "${feature}" ]] && echo "fatal: no feature given" >&2 && return 1

    # Set up the git args for the log command
    [[ -n "${before_ts}" ]] && git_args+=("--before=${before_ts}")
    [[ -n "${after_ts}" ]] && git_args+=("--after=${after_ts}")

    remote=$(git config --get "branch.${branch}.remote" || git remote)
    release_message="$(generate-release-message "${feature}")"
    pick_message="$(generate-pick-message "${feature}")"
    merge_message="$(generate-merge-message "${feature}")"
    promotion_pattern="^${release_message}|${pick_message}|${merge_message}$"

    debug-vars branch feature remote before_ts after_ts git_args use_trigger_ts \
        release_message pick_message merge_message promotion_pattern

    # - Search for all promotions (releases and picks) for the feature into the
    #   branch
	# Generate a list of cherry-picks for the customization into the target branch with each file in that cherry-pick
	# on the same line delimited by a \x1e (Record Separator) character
	# e.g.:
	#   43169edc8\t1659555795\tCherry-picking for AS9-CUS-SDS-0009\x1eAS9-CUS-SDS-009\x1etailored/metadata/runtime/ui/VIEW/FANNS025-FANN-VIEW.xml\n
	#   c0bf3b73f\t1654542635\tCherry-picking for AS9-CUS-SDS-0009\x1eAS9-CUS-SDS-0009\n
	#   56b4912d5\t1646009697\tCherry-picking for AS9-CUS-SDS-0009\x1eAS9-CUS-SDS-0009\n
    readarray -t promotion_list < <(
        git log "${remote}/${branch}" \
            -n 15 -m \
            -E --grep="${promotion_pattern}" \
            --format=$'\1%h%x09%at%x09%s%x09' \
            --name-only \
            --raw \
            "${git_args[@]}" \
                | grep -v '^$' \
                | tr '\n' $'\x1e' \
                | sed $'s/.*/&\1/' \
                | tr '\1' '\n' \
                | sed 1d \
                | sed $'s/\x1e$//'
    )

    local last_promo_hash last_promo_time last_promo_mesg last_promo_files
    local last_promo_objs last_promo_type
	for promotion in "${promotion_list[@]}"; do
		# Extract the hash, timestamp, and pick files
		last_promo_hash=$(echo "${promotion}" | awk -F '\t' '{print $1}')
		last_promo_time=$(echo "${promotion}" | awk -F '\t' '{print $2}' | awk -F $'\x1e' '{print $1}')
        last_promo_mesg=$(echo "${promotion}" | awk -F '\t' '{print $3}')
		readarray -t last_promo_files < <(
            echo "${promotion}" | awk -F '\t' '{print $4}' | tr $'\x1e' '\n' | sed 1d
        )
		last_promo_objs=0
        debug "Determining promotion type for: ${last_promo_mesg}"
        debug-vars last_promo_mesg pick_message release_message merge_message
        last_promo_type=$(
            if [[ "${last_promo_mesg}" =~ ${pick_message} ]]; then
                echo "pick"
            elif [[ "${last_promo_mesg}" =~ ${release_message} ]]; then
                echo "release"
            elif [[ "${last_promo_mesg}" =~ ${merge_message} ]]; then
                echo "merge"
            else
                echo "unknown"
            fi
        )
        debug "last_promo_type: ${last_promo_type}"
        debug "Found ${last_promo_type} \"${last_promo_mesg}\" at ${last_promo_time} (${last_promo_hash})"
		# Loop through the files and check if any of them are not ignored
		for file in "${last_promo_files[@]}"; do
			# Check if the file is one we would pick
			if ! ignore-object -q "${file}"; then
				# This is a valid, cherry-pick file
				found_promotion=true
				let last_promo_objs++
			fi
		done
		if ${found_promotion}; then
            debug "Promotion found: ${last_promo_mesg} (${last_promo_hash})"
            break
        fi
	done

    # Update the timestamp for merges (use the timestamp of the merge commit)
    # and cherry-picks (use the timestamp of the cherry-pick trigger commit)
    local merge_commit promotion_hash promotion_files
    if ${found_promotion}; then
        # If this commit was merged into the target branch, then use the merge
        # commit's timestamp
        merge_commit=$(find-merge "${last_promo_hash}" "${remote}/${branch}" 2>/dev/null)
        if [[ -n "${merge_commit}" ]]; then
            last_promo_time=$(git log -1 --format=%at "${merge_commit}")
            debug "Using merge commit timestamp: ${merge_commit} (${last_promo_time})"
        elif [[ "${last_promo_type}" == "pick" ]] && ${use_trigger_ts}; then
            # If we're using the trigger timestamp, find the most recent commit
            # prior to the cherry-pick whose only commit object is a file with the
            # name of our feature
            debug "Searching for cherry-pick trigger timestamp"
            readarray -t promotion_list < <(
                git log "origin/${branch}" \
                    -n 15 -m \
                    --before "${last_promo_time}" \
                    --format=$'\1%h%x09%at%x09' \
                    --name-only \
                    --raw \
                        | grep -v '^$' \
                        | tr '\n' $'\x1e' \
                        | sed $'s/.*/&\1/' \
                        | tr '\1' '\n' \
                        | sed 1d \
                        | sed $'s/\x1e$//'
            )
            for promotion in "${promotion_list[@]}"; do
                # Check to see if the commit only contains the feature file
                promotion_hash=$(echo "${promotion}" | awk -F $'\t' '{print $1}')
                promotion_files=$(echo "${promotion}" | awk -F $'\t' '{print $3}' | tr -d $'\x1e')
                debug "Checking commit ${promotion_hash} for feature ${feature} -- ${promotion_files}"
                if [[ "${promotion_files}" == "${feature}" ]]; then
                    # This is the commit we want
                    last_promo_time=$(echo "${promotion}" | awk -F $'\t' '{print $2}')
                    debug "Using trigger timestamp: ${last_promo_time}"
                    trigger_ts_found=true
                    break
                fi
            done
            ! ${trigger_ts_found} && debug "Trigger timestamp not found, using cherry-pick timestamp ${last_promo_time}"
        fi
    else
        # No promotion found, so return an error
        debug error "No promotion found for feature '${feature}' on branch '${branch}'"
        return 1
    fi

    # Print information about the last promotion
    echo "${last_promo_time}" "${last_promo_hash}" "${last_promo_objs}"
}

# @description Determine whether a file should generally be handled by devops
# @usage ignore-object [--quiet] <object>
function ignore-object() {
	local obj obj_basedir
    local do_ignore=false
    local do_quiet=false

    # parse args
    while [[ $# -gt 0 ]]; do
        case "${1}" in
            -q | --quiet)
                do_quiet=true
                ;;
            *)
                if [[ -z "${obj}" ]]; then
                    obj="${1}"
                else
                    debug error "unknown argument: ${1}"
                    return 1
                fi
                ;;
        esac
        shift
    done

    debug info "checking if '${obj}' should be ignored (quiet=${do_quiet})"

    # Determine if the object should be ignored
    obj_basedir="${obj%%/*}"
    debug info "object base directory: ${obj_basedir}"
    case "${obj_basedir}" in
        nxa | tailored | database | app_config | helix)
            do_ignore=false
            ;;
        *)
            do_ignore=true
            ;;
    esac

    # Print and return the result
    if ${do_ignore}; then
        ! ${do_quiet} && echo "true"
        return 0
    else
        ! ${do_quiet} && echo "false"
        return 1
    fi   
}

# @description Return AssetSuite configuration settings
# @usage as-config <property name/pattern>
# @example as-config server.mode
# @example as-config "server\..*"
function as-config() {
    # Default values
    local key="$"
    local num_results=""
    local do_sort=false
    local do_show_filenames=true
    local do_show_keys=true
    local do_show_columns=true
    local properties_include=""
    local properties_exclude=""
    local grep_args=()
    local as_dir="${ASSETSUITE_DIR:-/abb/assetsuite}"
    local return_str=""
    local properties_files=() properties_files_unfiltered=()

    # Process arguments
    while [ $# -gt 0 ]; do
        case "$1" in
            -d|--as-dir)
                as_dir="$2"
                shift 2
                ;;
            -n|--num-results)
                # Check if the value is a number
                if [[ ! "$2" =~ ^[0-9]+$ ]]; then
                    echo "ERROR: The value '$2' is not a number" >&2
                    return 1
                fi
                num_results="$2"
                shift 2
                ;;
            -i|--include)
                properties_include="${1}"
                shift 2
                ;;
            -x|--exclude)
                properties_exclude="${1}"
                shift 2
                ;;
            -s|--sort)
                do_sort=true
                shift
                ;;
            -S|--no-sort)
                do_sort=false
                shift
                ;;
            -k|--show-keys)
                do_show_keys=true
                shift
                ;;
            -K|--no-show-keys)
                do_show_keys=false
                shift
                ;;
            -f|--show-filenames)
                do_show_filenames=true
                shift
                ;;
            -F|--no-show-filenames)
                do_show_filenames=false
                shift
                ;;
            -c|--columns)
                do_show_columns=true
                shift
                ;;
            -C|--no-columns)
                do_show_columns=false
                shift
                ;;
            *)
                key="$1"
                shift
                ;;
        esac
    done

    # Check if the AssetSuite directory exists
    if [[ ! -d "${as_dir}" ]]; then
        echo "ERROR: the AssetSuite directory '${as_dir}' does not exist" >&2
        return 1
    fi

    # Set up the grep args
    if ${do_show_filenames}; then
        grep_args+=("-H")
    else
        grep_args+=("-h")
    fi

    # Find all properties files, filtering based on the include/exclude patterns
    readarray -t properties_files < <(
        find "${as_dir}" -type f -name '*.properties' 2>/dev/null \
            | grep -E "${properties_include}" \
            | grep -vE "${properties_exclude}"
    )

    # Ensure we found properties files
    if [[ ${#properties_files[@]} -le 0 ]]; then
        echo "error: no properties files found under '${as_dir}'" >&2
        return 1
    fi

    # Get the key value(s)
    readarray -t results < <(
        grep --color=never -RoE "${grep_args[@]}" "^${key}\s*=\s*.*" "${properties_files[@]}"
    )

    # If no results were found, return an error
    if [[ ${#results[@]} -le 0 ]]; then
        echo "error: no results found for '${key}'" >&2
        return 1
    fi

    # Sort the array if requested
    if ${do_sort}; then
        readarray -t results < <(printf '%s\n' "${results[@]}" | sort)
    fi

    # Reduce the array size if requested
    if [[ -n "${num_results}" && ${num_results} -lt ${#results[@]} ]]; then
        readarray -t results < <(printf '%s\n' "${results[@]}" | head -n "${num_results}")
    fi

    # Remove key names if requested
    if ! ${do_show_keys}; then
        if ${do_show_filenames}; then
            readarray -t results < <(
                printf "${results[@]}" | sed -E 's/(^[^:]*:)[^=]*=/\1/'
            )
        else
            readarray -t results < <(
                printf "${results[@]}" | sed -E 's/^[^=]*=//'
            )
        fi
    fi

    # Set up the return string
    return_str=$(printf '%s\n' "${results[@]}")

    # Columnize the results if requested
    if ${do_show_columns}; then
        # If filenames are being shown, replace the first colon with a FS character
        if ${do_show_filenames}; then
            return_str=$(sed -E 's/:/\x1f/' <<< "${return_str}")
        fi
        # If key names are being shown, replace the first equals sign with a FS character
        if ${do_show_keys}; then
            return_str=$(sed -E 's/=/\x1f/' <<< "${return_str}")
        fi

        return_str=$(column -t -s $'\x1f' <<< "${return_str}")
    fi

    # Print the results
    echo "${return_str}"
}
