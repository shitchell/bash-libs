: '
Functions for working with CSV files
'

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
            -d | --delimiter)
                delimiter="${2}"
                shift 2
                ;;
            *)
                [ -z "${item}" ] && item="${1}"
                shift 1
                ;;
        esac
    done

    # If no item is provided and stdin is available, read from stdin
    if [ -z "${item}" ] && ! [ -t 0 ]; then
        item=$(cat)
    fi

    # If item is still empty, return an error
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

function csv-unquote {
    :  'Unquote a string from a CSV file

        @usage
            <string>

        @arg string
            The string to unquote

        @option -d/--delimiter <delimiter>
            Use <delimiter> as the field separator (default: ,)

        @stdout
            The unquoted string

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
            -d | --delimiter)
                delimiter="${2}"
                shift 2
                ;;
            *)
                [ -z "${item}" ] && item="${1}"
                shift 1
                ;;
        esac
    done

    # If no item is provided and stdin is available, read from stdin
    if [ -z "${item}" ] && ! [ -t 0 ]; then
        item=$(cat)
    fi

    # If item is still empty, return an error
    if [ -z "${item}" ]; then
        return 1
    fi

    # If $item is quoted, remove the outer quotes and replace double quotes with a single quote
    if [[ "${item}" =~ ^\".*\"$ ]]; then
        # Remove outer quotes
        item="${item:1:-1}"
        # Replace double quotes with a single quote
        item="${item//\"\"/\"}"
    fi

    # Print the unquoted item
    printf '%s' "${item}"
}

function csv-split {
    :  'Split a CSV row into an array of fields

        @usage
            [-d/--delimeter <delimeter>] <row> [name]

        @option -d/--delimiter <delimiter>
            Use <delimiter> as the field separator (default: ,)

        @arg row
            The CSV row to split
        
        @optarg name
            The name of the array to store the fields in (default: FIELDS)

        @stdout
            The array of fields

        @return 0
            Successful completion

        @return 1
            If the row is empty
    '

    # Parse the arguments
    local delimiter=","
    local row
    local name="FIELDS"

    while [ ${#} -gt 0 ]; do
        case "${1}" in
            -d | --delimiter)
                delimiter="${2}"
                shift 2
                ;;
            *)
                if [[ -z "${row}" ]]; then
                    row="${1}"
                else
                    name="${1}"
                fi
                shift 1
                ;;
        esac
    done

    # We cannot read from stdin for this one since it needs to set an array
    # variable, and we cannot set an array variable in the current shell from a
    # subshell (i.e.: from a pipe)
    # If row is still empty, return an error
    if [[ -z "${row}" ]]; then
        return 1
    fi

    # Set up the array
    declare -n array="${name}"
    array=()

    local IFS=$'\n'
    local regex="((\"([^\"]|\"\")*\")|[^${delimiter}]*)${delimiter}"

    while [[ $row =~ $regex ]]; do
        local field="${BASH_REMATCH[1]}"
        row="${row:${#BASH_REMATCH[0]}}"

        # Remove surrounding quotes and unescape double quotes if field is quoted
        if [[ "$field" =~ ^\".*\"$ ]]; then
            field="${field:1:-1}"
            field="${field//\"\"/\"}"
        fi

        array+=("$field")
    done

    # Handle the last field
    if [ -n "$row" ]; then
        # Remove surrounding quotes and unescape double quotes if field is quoted
        if [[ "$row" =~ ^\".*\"$ ]]; then
            row="${row:1:-1}"
            row="${row//\"\"/\"}"
        fi
        array+=("$row")
    fi

    return 0
}

function csv-join {
    :  'Print an array as a comma-separated list with quotes as needed

        @usage
            [-d/--delimeter <delimeter] [-n/--no-newline] <arg1> [<arg2> ...]

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

# Alias for csv-join for backwards compatibility
function csv-echo() { csv-join "${@}"; }

function csv-column-index() {
    :  'Get the index of a column given its name

    @usage
        csv-column-index [-f/--file <file>] <name>
        cat <file> | csv-column-index <name>

    @option -f/--file <file>
        The CSV file to read from

    @arg name
        The name of the column to find

    @stdout
        The index of the column

    @return 0
        Successful completion

    @return 1
        If the column is not found

    @return 2
        If the file could not be read (does not exist, no permissions, etc.)
    '
    local column_name
    local filepath
    local data
    local header

    # Parse the arguments
    while [ ${#} -gt 0 ]; do
        case "${1}" in
            -f | --file)
                filepath="${2}"
                shift 2
                ;;
            *)
                column_name="${1}"
                shift
                ;;
        esac
    done

    # If the filepath is empty and stdin is available, read from stdin
    if [ -z "${filepath}" ] && ! [ -t 0 ]; then
        data=$(cat)
    elif [ -n "${filepath}" ]; then
        data=$(cat "${filepath}")
    else
        return 2
    fi

    if [ -z "${data}" ]; then
        return 2
    fi

    if [ -z "${column_name}" ]; then
        return 1
    fi

    # Split the first row of the data
    csv-split -d , "${data}" header

    # Find the index of the column
    for i in "${!header[@]}"; do
        if [ "${header[$i]}" == "${column_name}" ]; then
            echo "${i}"
            return 0
        fi
    done
}

# WIP: this function is not even remotely complete yet
function csv-get() {
    :  'Get rows, columns, or cells from a CSV file

        @usage
            csv-get [-f/--file <file>] [-r/--row <row>] [-c/--column <column>]
                    [-d/--delimiter <delimiter>] [-n/--no-header] [-h/--header]
                    [-l/--limit <limit>] [-D/--output-delimiter <delimiter>]
                    [-u/--unique[=<column>]] [-w/--where <where>]
            cat <file> | csv-get [options]

        @option -f/--file <file>
            The CSV file to read from

        @option -r/--row <row>
            The row to get. Can be a single row number, a range (e.g., 1-5), or
            a comma-separated list of row numbers or ranges (e.g., 1,3,5-7)

        @option -c/--column <column>
            The column(s) to get. Can be a single column number, a range
            (e.g., 1-5), or a comma-separated list of column numbers or ranges
            (e.g., 1,3,5-7). Can also be a column name if the -h/--header option
            is used.

        @option -d/--delimiter <delimiter>
            The delimiter to use (default: ,)

        @option -n/--no-header
            Do not treat the first row as a header

        @option -h/--header
            Treat the first row as a header (default). This is required when
            selecting columns by name.

        @option -l/--limit <limit>
            Limit the output to <limit> rows

        @option -D/--output-delimeter <delimiter>
            The delimiter to use when outputting the results (default: ,)

        @option -u/--unique[=<column>]
            Remove duplicate rows, optionally specifying a column to use for
            comparison. If no column is specified, all columns are used.

        @option -w/--where <where>
            A condition to filter rows. The condition is a string that will be
            evaluated by the `test` command. The row will be included in the
            output if the condition is true. Columns can be referenced by their
            name ("${column_name}") or by their index ("${0}"). The condition
            can be a simple comparison (e.g., "${0} -eq 5") or a more complex
            expression (e.g., `"${City}" = "Atlanta" -o "${1}" -gt 10`).

        @stdout
            The selected rows, columns, or cells

        @return 0
            Successful completion

        @return 1
            If the file could not be read (does not exist, no permissions, etc.)

        @return 2
            If the file is empty

        @return 3
            If the row or column is not found
        '
    local -- filepath
    local -- data
    local -- row
    local -- row_indices=()
    local -- column
    local -- column_indices=()
    local -- tmp_indices=()
    local -- delimiter=","
    local -- has_header=true
    local -- header
    local -- limit
    local -- output_delimiter=","
    local -- do_unique=false
    local -- unique_column
    local -- where_conditions=()
    local -- results=()
    local -- fields=()
    local -i index
    local -- include=false

    # Parse the arguments
    while [ ${#} -gt 0 ]; do
        case "${1}" in
            -f | --file)
                filepath="${2}"
                shift 2
                ;;
            -r | --row)
                row="${2}"
                shift 2
                ;;
            -c | --col | --column)
                column="${2}"
                shift 2
                ;;
            -d | --delimiter)
                delimiter="${2}"
                shift 2
                ;;
            -n | --no-header)
                has_header=false
                shift
                ;;
            -h | --header)
                has_header=true
                shift
                ;;
            -l | --limit)
                limit="${2}"
                shift 2
                ;;
            -D | --output-delimiter)
                output_delimiter="${2}"
                shift 2
                ;;
            -u | --unique)
                do_unique=true
                if [[ "${1}" == "--unique="* ]]; then
                    unique_column="${1#--unique=}"
                else
                    unique_column=""
                fi
                ;;
            -w | --where)
                where_conditions+=("${2}")
                shift 2
                ;;
            *)
                shift
                ;;
        esac
    done

    # If the filepath is empty and stdin is available, read from stdin
    if [[ -z "${filepath}" ]] && ! [ -t 0 ]; then
        data=$(cat)
    elif [[ -n "${filepath}" ]]; then
        data=$(cat "${filepath}")
    else
        return 1
    fi

    if [[ -z "${data}" ]]; then
        return 2
    fi

    # If a header is present, split the first row
    # NOTE: this will fail if a field in the header contains a newline
    if ${has_header}; then
        header=$(head -n 1 <<< "${data}")
        csv-split -d "${delimiter}" "${header}" header
    fi
    declare -p header

    # Convert the rows from the format "1,3,5-7" to an array of integers
    if [[ -n "${row}" ]]; then
        # Split the string on the comma, and then replace any ranges with the
        # individual numbers
        IFS=, read -ra row_indices <<< "${row}"
        for i in "${!row_indices[@]}"; do
            if [[ "${row_indices[$i]}" =~ ^([0-9]+)-([0-9]+)$ ]]; then
                row_indices[$i]=$(seq "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}")
            fi
        done
        # Flatten the array
        row_indices=( ${row_indices[@]} )
        # Validate the array
        for i in "${row_indices[@]}"; do
            if ! [[ "${i}" =~ ^[0-9]+$ ]]; then
                echo "error: invalid row index: ${i}" >&2
                return 3
            fi
        done
    fi
    declare -p row_indices

    # Convert the columns from the format "1,3,5-7,Name" to an array of integers
    if [[ -n "${column}" ]]; then
        # Split the string on the comma, and then replace any ranges with the
        # individual numbers
        csv-split "${column}" tmp_indices
        for item in "${tmp_indices[@]}"; do
            if [[ "${item}" =~ ^([0-9]+)-([0-9]+)$ ]]; then
                ## 5-7 -> 5 6 7
                column_indices+=( $(seq "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}") )
            elif [[ "${item}" =~ ^[0-9]+$ ]]; then
                ## 5 -> 5
                column_indices+=( "${item}" )
            else
                ## Name -> 6 (if Name is the 6th column)
                # If the column is not a number, find the index of the column
                if [[ -z "${header}" ]] || ! ${has_header}; then
                    echo "error: column name provided but no header found" >&2
                    return 3
                fi
                for i in "${!header[@]}"; do
                    if [ "${header[$i]}" == "${item}" ]; then
                        column_indices+=( "${i}" )
                        break
                    fi
                done
            fi
        done
        # Validate the array
        for i in "${column_indices[@]}"; do
            if ! [[ "${i}" =~ ^[0-9]+$ ]]; then
                echo "error: invalid column index: ${i}" >&2
                return 3
            fi
        done
    fi
    declare -p column_indices

    # Loop over the rows
    index=0
    while read -r row; do
        csv-split -d "${delimiter}" "${row}" fields

        # Determine if the row should be included
        include=false
        ## by index
        if [[ -n "${row_indices[@]}" ]]; then
            for i in "${row_indices[@]}"; do
                if [[ "${index}" -eq "${i}" ]]; then
                    include=true
                    break
                fi
            done
        fi
        ## by condition
        if ! ${include} && [[ -n "${where_conditions[@]}" ]]; then
            # Set up the variables for the condition
            ## by column name
            if [[ -n "${header}" ]]; then
                for i in "${!header[@]}"; do
                    eval "${header[$i]}=${fields[$i]}" 2>/dev/null
                done
            fi
            ## by index
            set -- "${fields[@]}"

            # Evaluate the conditions
            for condition in "${where_conditions[@]}"; do
                if eval "test ${condition}"; then
                    include=true
                    break
                fi
            done
        fi

        # If the row should be included, process it
        if ${include}; then
            # If the row is unique, check if it has been seen before
            if ${do_unique}; then
                # Set up the variables for the comparison
                ## by column name
                if [[ -n "${header}" ]]; then
                    for i in "${!header[@]}"; do
                        eval "${header[$i]}=${fields[$i]}" 2>/dev/null
                    done
                fi
                ## by index
                set -- "${fields[@]}"

                # Evaluate the comparison
                if [[ -n "${unique_column}" ]]; then
                    if eval "test ${unique_column}"; then
                        if [[ ! " ${results[@]} " =~ " ${row} " ]]; then
                            results+=( "${row}" )
                        fi
                    fi
                else
                    if [[ ! " ${results[@]} " =~ " ${row} " ]]; then
                        results+=( "${row}" )
                    fi
                fi
            else
                results+=( "${row}" )
            fi
        fi
    done <<< "${data}"
    declare -p results
}