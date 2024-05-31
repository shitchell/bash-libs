#!/usr/bin/env bash
: '
Functions for manipulating and using branch flow files.

Branch flow files are graphviz-based configuration files describing how git
branches flow together, e.g.:

    * -> *                [cherrypick=false, pr=true, feature-merge=true]
    feature/* -> dev
    dev -> test
    test -> stage
    stage -> main         [feature-merge=false]

Note: glob patterns are allowed, and options can be provided for each merge. In
the example, we declare 3 default options for all merges (from "*" any branch
to "*" any branch): cherrypick=false, pr=true, feature-merge=true. Your
scripts can interpret these options however they like; I would suggest that this
means: no cherry-picking features, only Pull Requests and feature branches are
allowed for moving code between branches. Then, at the stage to main step, we
disable merging feature branches, which means only a Pull Request can move code
from stage to main
'

include-source 'debug'
include-source 'shell'

# @description Reduce a branch flow file to single lines
# @usage _normalize_branch_flow <branch-flow-file>
# @usage echo "${branch_flow}" | _normalize_branch_flow
function _normalize_branch_flow() {
    local branch_flow_file="${1:-/dev/stdin}"

    cat "${branch_flow_file}" \
        | sed -e 's/;/\n/g;s/\]/]\n/g' \
        | awk '{
            if ($0 ~ /->/) {
                # If the line contains a "->", remove space around it and quotes
                # around the branches
                source_branch = $0
                gsub(/\s+->\s+.*/, "", source_branch)
                gsub(/^\s*/, "", source_branch)
                gsub(/"/, "", source_branch)

                target_branch = $0
                gsub(/.*->\s+/, "", target_branch)
                gsub(/\s+.*$/, "", target_branch)
                gsub(/"/, "", target_branch)

                eol = $0
                gsub(/.*->\s+[^ ;]+/, "", eol)
                gsub(/^\s*/, "", eol)
                gsub(/\s*$/, "", eol)

                $0 = source_branch " -> " target_branch " " eol
            } else {
                # Just remove leading/trailing whitespace
                gsub(/^\s*/, "", $0)
                gsub(/\s*$/, "", $0)
            }
            if ($0 == "") {
                next
            } else if ($0 ~ /\[/ && $0 !~ /]/) {
                in_multiline = 1
                printf "%s", $0
            } else if ($0 ~ /]/ && in_multiline) {
                in_multiline = 0
                print $0
            } else if (in_multiline) {
                printf "%s", $0
            } else {
                print $0
            }
        }'
}

# @description Convert a branch flow file to a digraph file
# @usage branch-flow-to-digraph <branch-flow-file>
function branch-flow-to-digraph() {
    local branch_flow_file="${1}"
    local flow_content
    local line_regex="([^ ]+) -> ([^ ]+)( +)?(.*)?"

    if [[ "${branch_flow_file}" == "-" ]]; then
        branch_flow_file="/dev/stdin"
    fi

    if [[ -z "${branch_flow_file}" ]]; then
        echo "usage: branch-flow-to-digraph <branch-flow-file>"
        return 1
    fi

    flow_content=$(
        _normalize_branch_flow "${branch_flow_file}" \
            | sed -E 's/^([[:space:]]*)\*([[:space:]]+)/\1node\2/'
    )

    echo "digraph G {"
    echo "  node [shape=box, fontname=Arial];"
    while read -r line; do
        # If the line contains a "->", then it's a branch flow line, so
        # extract the source and target branches and quote them
        if [[ "${line}" =~ ${line_regex} ]]; then
            source_branch="${BASH_REMATCH[1]}"
            target_branch="${BASH_REMATCH[2]}"
            eol="${BASH_REMATCH[4]}"
            printf '  "%s" -> "%s"' "${source_branch}" "${target_branch}"
            [[ -n "${eol}" ]] && printf ' %s' "${eol}"
            echo
        else
            # Otherwise, just print the line
            echo "  ${line}"
        fi
    done <<< "${flow_content}"
    echo "}"
}

# @description Convert a branch flow file to an image (requires graphviz)
# @usage branch-flow-to-image <branch-flow-file> <image-file>
function branch-flow-to-image() {
    local branch_flow_file="${1}"
    local image_file="${2:-/dev/stdout}"
    local extension digraph
    
    require dot

    if [[ -z "${branch_flow_file}" || -z "${image_file}" ]]; then
        echo "usage: branch-flow-to-image <branch-flow-file> <image-file>"
        return 1
    fi

    extension="${image_file##*.}"
    [[ "${extension}" == "${image_file}" ]] && extension="svg"
    digraph=$(
        branch-flow-to-digraph "${branch_flow_file}" \
            | sed -E 's/cherrypick="?true"?/cherrypick="true", style="dashed"/g' \
            | grep -Fv ' -> "*"'
    )

    echo "${branch_flow_file} -> ${image_file}"
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

    debug-vars branch_name flow_file

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

# @description Get branch settings from a branch flow file
# @usage get-branch-option [-eESiVpP] [-s <source-branch>] [-t <target-branch>] [-o <option>] [-f <flow-file>]
function get-branch-option() {
    local line_regex="([^ ]+) -> ([^ ]+)( +)?(.*)?"

    # Default values
    local source_branch_name=""
    local target_branch_name=""
    local do_value_only=false
    local do_pretty=false
    local do_show_all_matches=false # don't uniquify results
    local option_name=""
    local flow_file="./branches.gv"

    # Parse options
    do_value_only_specified=false
    while [[ $# -gt 0 ]]; do
        case "${1}" in
            -s | --source-branch)
                source_branch_name="${2}"
                shift 2
                ;;
            -t | --target-branch)
                target_branch_name="${2}"
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
            -k | --show-keys)
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

    debug-vars source_branch_name target_branch_name option_name flow_file \
        do_regex do_strict do_pretty do_value_only do_value_only_specified

    if ${do_value_only} && ! ${do_strict}; then
        echo "error: --value-only must be used with --strict"
    fi

    if [[ -n "${option_name}" ]] && ! ${do_value_only_specified}; then
        do_value_only=true
    fi

    if [[ "${flow_file}" == "-" ]]; then
        flow_file="/dev/stdin"
    fi

    # Read the branch flow file, attempting to account for multiline options
    local flow_content=$(_normalize_branch_flow "${flow_file}")

    local line_source_branch line_target_branch line_options
    readarray -t matching_options < <(
        while read -r line; do
            debug "processing line: ${line}"
            if [[ "${line}" =~ ${line_regex} ]]; then
                line_source_branch="${BASH_REMATCH[1]}"
                line_target_branch="${BASH_REMATCH[2]}"
                line_options="${BASH_REMATCH[4]}"
            else
                debug "line does not match regex, skipping"
                continue
            fi

            # Use glob matching
            if [[ ${source_branch_name} == ${line_source_branch} ]]; then
                debug "source branch matches"
            else
                debug "source branch does not match"
                continue
            fi

            if [[ ${target_branch_name} == ${line_target_branch} ]]; then
                debug "target branch matches"
            else
                debug "target branch does not match"
                continue
            fi

            # Parse the options, trimming leading/trailing whitespace and brackets,
            # and replacing commas with newlines
            line_options=$(
                echo "${line_options}" \
                    | sed -E 's/^ *\[//;s/\] *$//' \
                    | sed -Ee :1 -e 's/^(([^",]|"[^"]*")*),/\1\n/;t1' \
                    | sed 's/^ *//;s/ *$//'
            )
            debug "all options for source/target branch: ${line_options}"

            if [[ -n "${option_name}" ]]; then
                # Filter only the options matching the given option name
                line_options=$(
                    awk -F '=' -v option="${option_name}" '
                        $1 == option {
                            print $0
                        }
                    ' <<< "${line_options}")
                debug "filtered options for source/target branch: ${line_options}"
            fi
            [[ -n "${line_options}" ]] && echo "${line_options}"
        done <<< "${flow_content}" \
            | awk -F '=' '
                # For each option, store only the last value
                {
                    options[$1] = $0
                }
                END {
                    for (option in options) {
                        print options[option]
                    }
                }
            '
    )
    debug "parsed matching options: ${matching_options[@]}"

    # If value-only mode is enabled, only the value should be returned
    if ${do_value_only}; then
        debug "do_value_only=${do_value_only}, stripping option names"
        readarray -t matching_options < <(
            printf '%s\n' "${matching_options[@]}" | sed -E 's/^[^=]+=//'
        )
        debug "updated matching options: ${matching_options[@]}"
    fi

    local opt val
    for matching_option in "${matching_options[@]}"; do
        debug "parsing option: ${matching_option}"
        val="${matching_option#*=}"
        opt="${matching_option%%=*}"
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
