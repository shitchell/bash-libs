: '
Functions for working with CSV files
'

function csv-echo {
    :  'Print an array as a comma-separated list with quotes as needed

        @usage
            <arg1> [<arg2> ...]

        @arg+
            The array to csv-quote and echo

        @option -n/--no-newline
            Do not print a newline at the end of the list

        @option -d/--delimiter <delimiter>
            Use <delimiter> as the field separator (default: ,)

        @stdout
            The array as a csv quoted, delimeted list

        @return 0
            Successful completion

        @return 1
            If the array is empty
    '

    # Parse the arguments
    local do_newline=true
    local delimiter=","
    declare -a items

    while [ ${#} -gt 0 ]; do
        case "${1}" in
            -n | --no-newline)
                do_newline=false
                shift
                ;;
            -d | --delimiter)
                delimiter="${2}"
                shift 2
                ;;
            *)
                items+=("${1}")
                shift
                ;;
        esac
    done

    local is_first=true
    for item in "${items[@]}"; do
        ${is_first} && is_first=false || printf '%s' "${delimiter}"

        csv-quote --delimeter "${delimeter}" "${item}"
    done

    ${do_newline} && echo
}

function csv-quote {
    :  'Quote a string for use in a CSV file

        @usage
            <string>

        @arg string
            The string to quote

        @option -d/--delimiter <delimiter>
            Use <delimiter> as the field separator (default: ,)

        @stdout
            The quoted string

        @return 0
            Successful completion

        @return 1
            If the string is empty
    '

    # Parse the arguments
    local delimiter=","
    local item

    while [ ${#} -gt 0 ]; do
        case "${1}" in
            -d|--delimiter)
                delimiter="${2}"
                shift 2
                ;;
            *)
                [ -z "${item}" ] && item="${1}"
                shift 1
                ;;
        esac
    done

    if [ -z "${item}" ]; then
        return 1
    fi

    # If $item contains whitespace, the delimeter, or a double quote, quote it
    if [[ "${item}" =~ [[:space:]${delimiter}\"] ]]; then
        # Replace double quotes with two double quotes
        item="${item//\"/\"\"}"
        printf '"%s"' "${item}"
    else
        # Otherwise, just print the item
        printf '%s' "${item}"
    fi
}
