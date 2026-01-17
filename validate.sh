#!/usr/bin/env bash
: '
Input validation functions using regex patterns
'

function validate-email() {
    : 'Validate an email address

        @arg $1 Email address to validate
        @return 0 if valid, 1 if invalid
        @stdout Error message if invalid
    '
    local email="${1:-}"

    if [[ -z "${email}" ]]; then
        echo "error: email address cannot be empty" >&2
        return 1
    fi

    # RFC 5322 simplified regex for email validation
    # Allows: letters, numbers, dots, hyphens, underscores in local part
    # Requires: @ symbol
    # Allows: letters, numbers, dots, hyphens in domain
    # Requires: at least one dot in domain with 2+ chars after last dot
    local regex='^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'

    if [[ "${email}" =~ ${regex} ]]; then
        return 0
    else
        echo "error: invalid email address: ${email}" >&2
        return 1
    fi
}

function validate-url() {
    : 'Validate a URL

        @arg $1 URL to validate
        @return 0 if valid, 1 if invalid
        @stdout Error message if invalid
    '
    local url="${1:-}"

    if [[ -z "${url}" ]]; then
        echo "error: URL cannot be empty" >&2
        return 1
    fi

    # URL regex pattern
    # Supports: http, https, ftp schemes
    # Requires: :// after scheme
    # Allows: optional user:pass@
    # Allows: hostname or IP
    # Allows: optional :port
    # Allows: optional path, query, fragment
    local regex='^(https?|ftp)://([a-zA-Z0-9]+:[a-zA-Z0-9]+@)?([a-zA-Z0-9.-]+)(:[0-9]+)?(/[^?#]*)?(\?[^#]*)?(#.*)?$'

    if [[ "${url}" =~ ${regex} ]]; then
        return 0
    else
        echo "error: invalid URL: ${url}" >&2
        return 1
    fi
}

function validate-ip() {
    : 'Validate an IP address (IPv4 or IPv6)

        @arg $1 IP address to validate
        @return 0 if valid, 1 if invalid
        @stdout Error message if invalid
    '
    local ip="${1:-}"

    if [[ -z "${ip}" ]]; then
        echo "error: IP address cannot be empty" >&2
        return 1
    fi

    # Try IPv4 first
    if validate-ipv4 "${ip}" 2>/dev/null; then
        return 0
    fi

    # Try IPv6
    if validate-ipv6 "${ip}" 2>/dev/null; then
        return 0
    fi

    echo "error: invalid IP address: ${ip}" >&2
    return 1
}

function validate-ipv4() {
    : 'Validate an IPv4 address

        @arg $1 IPv4 address to validate
        @return 0 if valid, 1 if invalid
        @stdout Error message if invalid
    '
    local ip="${1:-}"

    if [[ -z "${ip}" ]]; then
        echo "error: IPv4 address cannot be empty" >&2
        return 1
    fi

    # IPv4 regex - exactly 4 octets separated by dots
    local regex='^([0-9]{1,3}\.){3}[0-9]{1,3}$'

    if [[ ! "${ip}" =~ ${regex} ]]; then
        echo "error: invalid IPv4 format: ${ip}" >&2
        return 1
    fi

    # Validate each octet is 0-255
    local IFS='.'
    local octets=($ip)
    local octet

    for octet in "${octets[@]}"; do
        # Remove leading zeros for comparison
        octet=$((10#${octet}))
        if (( octet > 255 )); then
            echo "error: IPv4 octet out of range (0-255): ${octet}" >&2
            return 1
        fi
    done

    return 0
}

function validate-ipv6() {
    : 'Validate an IPv6 address

        @arg $1 IPv6 address to validate
        @return 0 if valid, 1 if invalid
        @stdout Error message if invalid
    '
    local ip="${1:-}"

    if [[ -z "${ip}" ]]; then
        echo "error: IPv6 address cannot be empty" >&2
        return 1
    fi

    # Simplified IPv6 regex
    # Supports full form, compressed form (::), and mixed IPv4 notation
    local regex='^(([0-9a-fA-F]{1,4}:){7}[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,7}:|([0-9a-fA-F]{1,4}:){1,6}:[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,5}(:[0-9a-fA-F]{1,4}){1,2}|([0-9a-fA-F]{1,4}:){1,4}(:[0-9a-fA-F]{1,4}){1,3}|([0-9a-fA-F]{1,4}:){1,3}(:[0-9a-fA-F]{1,4}){1,4}|([0-9a-fA-F]{1,4}:){1,2}(:[0-9a-fA-F]{1,4}){1,5}|[0-9a-fA-F]{1,4}:((:[0-9a-fA-F]{1,4}){1,6})|:((:[0-9a-fA-F]{1,4}){1,7}|:)|fe80:(:[0-9a-fA-F]{0,4}){0,4}%[0-9a-zA-Z]{1,}|::(ffff(:0{1,4}){0,1}:){0,1}((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])|([0-9a-fA-F]{1,4}:){1,4}:((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9]))$'

    if [[ "${ip}" =~ ${regex} ]]; then
        return 0
    else
        echo "error: invalid IPv6 address: ${ip}" >&2
        return 1
    fi
}

function validate-path() {
    : 'Validate a file system path

        @arg $1 Path to validate
        @arg $2 Optional type: "file", "dir", "any" (default: "any")
        @return 0 if valid, 1 if invalid
        @stdout Error message if invalid
    '
    local path="${1:-}"
    local type="${2:-any}"

    if [[ -z "${path}" ]]; then
        echo "error: path cannot be empty" >&2
        return 1
    fi

    # Check for invalid characters in path
    # Allow: alphanumeric, spaces, and common path characters
    local regex='^[a-zA-Z0-9 ._/~-]+$'

    if [[ ! "${path}" =~ ${regex} ]]; then
        echo "error: path contains invalid characters: ${path}" >&2
        return 1
    fi

    # Check for path traversal attempts
    if [[ "${path}" =~ \.\. ]]; then
        echo "error: path traversal detected in path: ${path}" >&2
        return 1
    fi

    # Validate based on type if path exists
    if [[ -e "${path}" ]]; then
        case "${type}" in
            file)
                if [[ ! -f "${path}" ]]; then
                    echo "error: path exists but is not a file: ${path}" >&2
                    return 1
                fi
                ;;
            dir)
                if [[ ! -d "${path}" ]]; then
                    echo "error: path exists but is not a directory: ${path}" >&2
                    return 1
                fi
                ;;
            any)
                # Path exists and type doesn't matter
                ;;
            *)
                echo "error: invalid type argument: ${type} (expected: file, dir, any)" >&2
                return 1
                ;;
        esac
    fi

    return 0
}

function validate-number() {
    : 'Validate a number (integer or float)

        @arg $1 Number to validate
        @arg $2 Optional type: "int", "float", "any" (default: "any")
        @arg $3 Optional minimum value
        @arg $4 Optional maximum value
        @return 0 if valid, 1 if invalid
        @stdout Error message if invalid
    '
    local number="${1:-}"
    local type="${2:-any}"
    local min="${3:-}"
    local max="${4:-}"

    if [[ -z "${number}" ]]; then
        echo "error: number cannot be empty" >&2
        return 1
    fi

    # Remove leading + sign if present
    number="${number#+}"

    local is_valid=false

    case "${type}" in
        int)
            # Integer: optional minus, then digits
            if [[ "${number}" =~ ^-?[0-9]+$ ]]; then
                is_valid=true
            else
                echo "error: not a valid integer: ${number}" >&2
                return 1
            fi
            ;;
        float)
            # Float: optional minus, digits, optional decimal point and more digits
            if [[ "${number}" =~ ^-?[0-9]+(\.[0-9]+)?$ ]]; then
                is_valid=true
            else
                echo "error: not a valid float: ${number}" >&2
                return 1
            fi
            ;;
        any)
            # Accept both int and float
            if [[ "${number}" =~ ^-?[0-9]+(\.[0-9]+)?$ ]]; then
                is_valid=true
            else
                echo "error: not a valid number: ${number}" >&2
                return 1
            fi
            ;;
        *)
            echo "error: invalid type argument: ${type} (expected: int, float, any)" >&2
            return 1
            ;;
    esac

    # Validate range if specified
    if [[ -n "${min}" ]] || [[ -n "${max}" ]]; then
        # Use bc for comparison to handle floats
        if command -v bc >/dev/null 2>&1; then
            if [[ -n "${min}" ]]; then
                if (( $(echo "${number} < ${min}" | bc -l) )); then
                    echo "error: number ${number} is less than minimum ${min}" >&2
                    return 1
                fi
            fi
            if [[ -n "${max}" ]]; then
                if (( $(echo "${number} > ${max}" | bc -l) )); then
                    echo "error: number ${number} is greater than maximum ${max}" >&2
                    return 1
                fi
            fi
        else
            # Fallback for integer comparison only
            if [[ "${type}" == "int" ]] || [[ ! "${number}" =~ \. ]]; then
                if [[ -n "${min}" ]] && (( ${number%.*} < ${min%.*} )); then
                    echo "error: number ${number} is less than minimum ${min}" >&2
                    return 1
                fi
                if [[ -n "${max}" ]] && (( ${number%.*} > ${max%.*} )); then
                    echo "error: number ${number} is greater than maximum ${max}" >&2
                    return 1
                fi
            else
                echo "warning: bc not available, range validation skipped for float" >&2
            fi
        fi
    fi

    return 0
}

function validate-date() {
    : 'Validate a date string

        @arg $1 Date string to validate
        @arg $2 Optional format: "iso", "us", "eu", "any" (default: "any")
        @return 0 if valid, 1 if invalid
        @stdout Error message if invalid
    '
    local date="${1:-}"
    local format="${2:-any}"

    if [[ -z "${date}" ]]; then
        echo "error: date cannot be empty" >&2
        return 1
    fi

    local year month day
    local is_valid=false

    case "${format}" in
        iso)
            # ISO format: YYYY-MM-DD
            if [[ "${date}" =~ ^([0-9]{4})-([0-9]{2})-([0-9]{2})$ ]]; then
                year="${BASH_REMATCH[1]}"
                month="${BASH_REMATCH[2]}"
                day="${BASH_REMATCH[3]}"
                is_valid=true
            else
                echo "error: not a valid ISO date (YYYY-MM-DD): ${date}" >&2
                return 1
            fi
            ;;
        us)
            # US format: MM/DD/YYYY or MM-DD-YYYY
            if [[ "${date}" =~ ^([0-9]{2})[/-]([0-9]{2})[/-]([0-9]{4})$ ]]; then
                month="${BASH_REMATCH[1]}"
                day="${BASH_REMATCH[2]}"
                year="${BASH_REMATCH[3]}"
                is_valid=true
            else
                echo "error: not a valid US date (MM/DD/YYYY): ${date}" >&2
                return 1
            fi
            ;;
        eu)
            # EU format: DD/MM/YYYY or DD-MM-YYYY
            if [[ "${date}" =~ ^([0-9]{2})[/-]([0-9]{2})[/-]([0-9]{4})$ ]]; then
                day="${BASH_REMATCH[1]}"
                month="${BASH_REMATCH[2]}"
                year="${BASH_REMATCH[3]}"
                is_valid=true
            else
                echo "error: not a valid EU date (DD/MM/YYYY): ${date}" >&2
                return 1
            fi
            ;;
        any)
            # Accept common formats
            if [[ "${date}" =~ ^([0-9]{4})-([0-9]{2})-([0-9]{2})$ ]]; then
                # ISO format
                year="${BASH_REMATCH[1]}"
                month="${BASH_REMATCH[2]}"
                day="${BASH_REMATCH[3]}"
                is_valid=true
            elif [[ "${date}" =~ ^([0-9]{2})[/-]([0-9]{2})[/-]([0-9]{4})$ ]]; then
                # Could be US or EU, assume US for validation
                month="${BASH_REMATCH[1]}"
                day="${BASH_REMATCH[2]}"
                year="${BASH_REMATCH[3]}"
                is_valid=true
            else
                echo "error: not a valid date: ${date}" >&2
                return 1
            fi
            ;;
        *)
            echo "error: invalid format argument: ${format} (expected: iso, us, eu, any)" >&2
            return 1
            ;;
    esac

    # Basic date component validation
    if ${is_valid} && [[ -n "${year}" ]] && [[ -n "${month}" ]] && [[ -n "${day}" ]]; then
        # Remove leading zeros for arithmetic comparison
        month=$((10#${month}))
        day=$((10#${day}))

        # Validate month
        if (( month < 1 || month > 12 )); then
            echo "error: invalid month (1-12): ${month}" >&2
            return 1
        fi

        # Validate day based on month
        local max_day
        case ${month} in
            1|3|5|7|8|10|12) max_day=31 ;;
            4|6|9|11) max_day=30 ;;
            2)
                # Check for leap year
                if (( (year % 4 == 0 && year % 100 != 0) || (year % 400 == 0) )); then
                    max_day=29
                else
                    max_day=28
                fi
                ;;
        esac

        if (( day < 1 || day > max_day )); then
            echo "error: invalid day (1-${max_day}) for month ${month}: ${day}" >&2
            return 1
        fi
    fi

    return 0
}

# Convenience functions for common validations
function is-email() {
    : 'Check if string is a valid email (silent)

        @arg $1 Email address to check
        @return 0 if valid email, 1 if invalid
    '
    validate-email "${1}" 2>/dev/null
}

function is-url() {
    : 'Check if string is a valid URL (silent)

        @arg $1 URL to check
        @return 0 if valid URL, 1 if invalid
    '
    validate-url "${1}" 2>/dev/null
}

function is-ip() {
    : 'Check if string is a valid IP address (silent)

        @arg $1 IP address to check
        @return 0 if valid IP, 1 if invalid
    '
    validate-ip "${1}" 2>/dev/null
}

function is-number() {
    : 'Check if string is a valid number (silent)

        @arg $1 Number to check
        @return 0 if valid number, 1 if invalid
    '
    validate-number "${1}" 2>/dev/null
}

function is-int() {
    : 'Check if string is a valid integer (silent)

        @arg $1 Integer to check
        @return 0 if valid integer, 1 if invalid
    '
    validate-number "${1}" "int" 2>/dev/null
}

function is-float() {
    : 'Check if string is a valid float (silent)

        @arg $1 Float to check
        @return 0 if valid float, 1 if invalid
    '
    validate-number "${1}" "float" 2>/dev/null
}

function is-date() {
    : 'Check if string is a valid date (silent)

        @arg $1 Date to check
        @return 0 if valid date, 1 if invalid
    '
    validate-date "${1}" 2>/dev/null
}