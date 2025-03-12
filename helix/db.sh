: '
TASdb functions for helix
'

__TEMPLATE_VERSION_SQL="SET DEFINE OFF;

INSERT INTO {{TABLE}} (VERSION_TYPE, VERSION_VALUE)
VALUES ('{{VERSION_TYPE}}', '{{VERSION_VALUE}}');

COMMIT;"

function generate-version-sql() {
    local __table __version_type __version_value

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "${1}" in
            -T | --table)
                __table="${2}"
                shift
                ;;
            -t | --version-type)
                __version_type="${2}"
                shift
                ;;
            -v | --version-value)
                __version_value="${2}"
                shift
                ;;
            *)
                echo "fatal: unknown argument: ${1}"
                return 1
                ;;
        esac
        shift
    done

    # Check required arguments
    if [[ -z ${__table} || -z ${__version_type} || -z ${__version_value} ]]; then
        echo "fatal: missing required arguments" >&2
        return 1
    fi

    # Generate SQL
    awk -v table="${__table}" \
        -v type="${__version_type}" \
        -v value="${__version_value}" '{
            gsub("{{TABLE}}", table)
            gsub("{{VERSION_TYPE}}", type)
            gsub("{{VERSION_VALUE}}", value)
            print $0
    }' <<< "${__TEMPLATE_VERSION_SQL}"
}

function generate-base-version-sql() {
    generate-version-sql -T "TAS.LIB_VERSION" -t "HELIXBASE" -v "${1}"
}

function generate-patch-version-sql() {
    generate-version-sql -T "TAS.LIB_VERSION" -t "HELIXPATCH" -v "${1}"
}

function generate-tasrt-version-sql() {
    generate-version-sql -T "TASRT.LIB_VERSION" -t "HELIXRT" -v "${1}"
}
