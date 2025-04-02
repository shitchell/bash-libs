# This library facilitates standardised versioning.

include-source debug

## Helper regexes
__REGEX_PREFIX_DELIMITER="[-_]"
__REGEX_PREFIX_CHARS="[A-Za-z]+"
__REGEX_PREFIX="(${__REGEX_PREFIX_CHARS})(${__REGEX_PREFIX_DELIMITER})?"
# => v, v_, v-, version_
__REGEX_MAIN="([0-9]+)\.([0-9]+)(\.([0-9]+))?(\.([0-9]+))?"
# => 1.23, 1.23.45, 1.23.45.0006
__REGEX_SUFFIX_DELIMITER="[-_]"
__REGEX_SUFFIX_CHARS="[A-Za-z]+"
__REGEX_SUFFIX="(${__REGEX_SUFFIX_DELIMITER})?((${__REGEX_SUFFIX_CHARS})([0-9]+)?)"
# => -rc1, -rc2, -beta1, -beta2, -alpha1, -alpha2

function build-version-regex() {
    :  'Build a version regex pattern.

        @usage
            [--prefix-delimiter <pattern>] [--prefix-chars <pattern>]
            [--main <pattern>]
            [--suffix-delimiter <pattern>] [--suffix-chars <pattern>]
        
        @stdout
            The version regex pattern
    '
    local __prefix_delimiter="${__REGEX_PREFIX_DELIMITER}"
    local __prefix_chars="${__REGEX_PREFIX_CHARS}"
    local __prefix=""
    local __main="${__REGEX_MAIN}"
    local __suffix_delimiter="${__REGEX_SUFFIX_DELIMITER}"
    local __suffix_chars="${__REGEX_SUFFIX_CHARS}"
    local __suffix=""

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "${1}" in
            --prefix-delimiter)
                __prefix_delimiter="${2}"
                shift
                ;;
            --prefix-chars)
                __prefix_chars="${2}"
                shift
                ;;
            --main)
                __main="${2}"
                shift
                ;;
            --suffix-delimiter)
                __suffix_delimiter="${2}"
                shift
                ;;
            --suffix-chars)
                __suffix_chars="${2}"
                shift
                ;;
            *)
                echo "fatal: unknown argument: ${1}" >&2
                return 1
                ;;
        esac
        shift
    done

    # Build regex
    __prefix="(${__prefix_chars})(${__prefix_delimiter})?"
    __suffix="(${__suffix_delimiter})?((${__suffix_chars})([0-9]+))?"
    debug-vars \
        __prefix_chars __prefix_delimiter __prefix \
        __main __suffix_chars __suffix_delimiter
    echo "(${__prefix})?(${__main})(${__suffix})?"
}

function parse-version() {
    :  'Parse a version string into its components.

        @usage
            [-v/--verbose] [--exact] [--no-exact]
            [--prefix-delimiter <pattern>] [--prefix-chars <pattern>]
            [--main <pattern>]
            [--suffix-delimiter <pattern>] [--suffix-chars <pattern>]
            <version>
        
        @option -v
            Print the parsed version components

        @option --exact
            Require an exact match
        
        @option --no-exact
            Do not require an exact match (extract a version from a string)

        @env
            VERSION_STRING
            VERSION_PREFIX
            VERSION_PREFIX_DELIMITER
            VERSION_MAIN
            VERSION_MAJOR
            VERSION_MINOR
            VERSION_PATCH
            VERSION_BUILD
            VERSION_SUFFIX
            VERSION_SUFFIX_DELIMITER
            VERSION_SUFFIX_TYPE
            VERSION_SUFFIX_NUMBER
    '
    local __regex_prefix_delimiter="${__REGEX_PREFIX_DELIMITER}"
    local __regex_prefix_chars="${__REGEX_PREFIX_CHARS}"
    local __regex_main="${__REGEX_MAIN}"
    local __regex_suffix_delimiter="${__REGEX_SUFFIX_DELIMITER}"
    local __regex_suffix_chars="${__REGEX_SUFFIX_CHARS}"
    local __regex_version=""
    local __do_verbose=false
    local __do_quiet=false
    local __do_exact=true
    local __version=""

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "${1}" in
            -v | --verbose | --print)
                __do_verbose=true
                __do_quiet=false
                ;;
            -q | --quiet)
                __do_quiet=true
                __do_verbose=false
                ;;
            --exact)
                __do_exact=true
                ;;
            --no-exact)
                __do_exact=false
                ;;
            --prefix-delimiter)
                __regex_prefix_delimiter="${2}"
                shift
                ;;
            --prefix-chars)
                __regex_prefix_chars="${2}"
                shift
                ;;
            --main)
                __regex_main="${2}"
                shift
                ;;
            --suffix-delimiter)
                __regex_suffix_delimiter="${2}"
                shift
                ;;
            --suffix-chars)
                __regex_suffix_chars="${2}"
                shift
                ;;
            *)
                __version="${1}"
                ;;
        esac
        shift
    done

    __regex_version=$(
        build-version-regex \
            --prefix-delimiter "${__regex_prefix_delimiter}" \
            --prefix-chars "${__regex_prefix_chars}" \
            --main "${__regex_main}" \
            --suffix-delimiter "${__regex_suffix_delimiter}" \
            --suffix-chars "${__regex_suffix_chars}"
    )
    if ${do_exact}; then
        __regex_version="^${__regex_version}$"
    fi

    # Parse version
    if [[ "${__version}" =~ ${__regex_version} ]]; then
        VERSION_MATCHES=("${BASH_REMATCH[@]}")
        VERSION_STRING="${__version}"
        VERSION_PREFIX="${BASH_REMATCH[2]}"
        VERSION_PREFIX_DELIMITER="${BASH_REMATCH[3]}"
        VERSION_MAIN="${BASH_REMATCH[4]}"
        VERSION_MAJOR="${BASH_REMATCH[5]}"
        VERSION_MINOR="${BASH_REMATCH[6]}"
        VERSION_PATCH="${BASH_REMATCH[8]}"
        VERSION_BUILD="${BASH_REMATCH[10]}"
        VERSION_SUFFIX_DELIMITER="${BASH_REMATCH[12]}"
        VERSION_SUFFIX="${BASH_REMATCH[13]}"
        VERSION_SUFFIX_TYPE="${BASH_REMATCH[14]}"
        VERSION_SUFFIX_NUMBER="${BASH_REMATCH[15]}"
        VERSION_REGEX="${__regex_version}"
    else
        ! ${do_quiet} && echo "fatal: invalid version string: ${__version}" >&2
        return 1
    fi

    # Print version components
    if ${__do_verbose}; then
        declare -p \
            VERSION_REGEX VERSION_MATCHES VERSION_STRING \
            VERSION_PREFIX VERSION_PREFIX_DELIMITER \
            VERSION_MAIN VERSION_MAJOR VERSION_MINOR VERSION_PATCH VERSION_BUILD \
            VERSION_SUFFIX VERSION_SUFFIX_DELIMITER \
            VERSION_SUFFIX_TYPE VERSION_SUFFIX_NUMBER
    fi
}

function _test_parse-version() {
    __TEST_STRING_01="1.2.3"
    declare -A __TEST_ENV_01=(
        [VERSION_STRING]="1.2.3"
        [VERSION_MAIN]="1.2.3"
        [VERSION_MAJOR]="1"
        [VERSION_MINOR]="2"
        [VERSION_PATCH]="3"
    )
    __TEST_STRING_02="v1.2.3"
    declare -A __TEST_ENV_02=(
        [VERSION_STRING]="v1.2.3"
        [VERSION_PREFIX]="v"
        [VERSION_MAIN]="1.2.3"
        [VERSION_MAJOR]="1"
        [VERSION_MINOR]="2"
        [VERSION_PATCH]="3"
    )
    __TEST_STRING_03="1.2.3-beta1"
    declare -A __TEST_ENV_03=(
        [VERSION_STRING]="1.2.3-beta1"
        [VERSION_MAIN]="1.2.3"
        [VERSION_MAJOR]="1"
        [VERSION_MINOR]="2"
        [VERSION_PATCH]="3"
        [VERSION_SUFFIX]="beta1"
        [VERSION_SUFFIX_DELIMITER]="-"
        [VERSION_SUFFIX_TYPE]="beta"
        [VERSION_SUFFIX_NUMBER]="1"
    )
    __TEST_STRING_04="version_1.2.3-beta1"
    declare -A __TEST_ENV_04=(
        [VERSION_STRING]="version_1.2.3-beta1"
        [VERSION_PREFIX]="version"
        [VERSION_PREFIX_DELIMITER]="_"
        [VERSION_MAIN]="1.2.3"
        [VERSION_MAJOR]="1"
        [VERSION_MINOR]="2"
        [VERSION_PATCH]="3"
        [VERSION_SUFFIX]="beta1"
        [VERSION_SUFFIX_DELIMITER]="-"
        [VERSION_SUFFIX_TYPE]="beta"
        [VERSION_SUFFIX_NUMBER]="1"
    )
    __TEST_STRING_05="version_1.2.34.0005-beta12"
    declare -A __TEST_ENV_05=(
        [VERSION_STRING]="version_1.2.34.0005-beta12"
        [VERSION_PREFIX]="version"
        [VERSION_PREFIX_DELIMITER]="_"
        [VERSION_MAIN]="1.2.34.0005"
        [VERSION_MAJOR]="1"
        [VERSION_MINOR]="2"
        [VERSION_PATCH]="34"
        [VERSION_BUILD]="0005"
        [VERSION_SUFFIX]="beta12"
        [VERSION_SUFFIX_DELIMITER]="-"
        [VERSION_SUFFIX_TYPE]="beta"
        [VERSION_SUFFIX_NUMBER]="12"
    )

    for test in {01..05}; do
        __test_string_name="__TEST_STRING_${test}"
        __test_env_name="__TEST_ENV_${test}"
        __test_string="${!__test_string_name}"
        declare -n __test_env="${__test_env_name}"

        echo "* testing: ${__test_string}"
        (
            parse-version -v "${__test_string}"
            for key in "${!__test_env[@]}"; do
                if [[ "${!key}" != "${__test_env[$key]}" ]]; then
                    echo "failed: ${__test_string}: ${key} does not match"
                    echo
                    echo "expected: ${__test_env[$key]}"
                    echo "  actual: ${!key}"
                    return 1
                fi
            done
        ) 2>&1 | sed 's/^/  /'
    done
}

# Build the primary regex and export it
declare -x REGEX_VERSION="$(build-version-regex)"
