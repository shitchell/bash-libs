: '
This library provides functions that are specific to WSL.
'

include-source 'debug'

function quote-powershell() {
    :  'Escape a string for use in a Powershell command with single quotes

        @usage
            <string>

        @stdin
            The string to escape

        @stdout
            The escaped string wrapped in single quotes
    '
    local string="${1:-$(cat -)}"

    # Escape single quotes and wrap the string in single quotes
    echo "'${string//\'/\'\'}'"
}

function set-clipboard() {
    :  'Set the clipboard contents

        @usage
            [-a/--append] [-v/--verbose] [--debug] <content>

        @optarg -a/--append
            Append the content to the clipboard instead of replacing it

        @optarg -v/--verbose
            Use the Set-Clipboard command with the Verbose flag

        @optarg --debug
            Use the Set-Clipboard command with the Debug flag

        @arg <content>
            The content to set as the clipboard contents
    '
    local do_append=false
    local do_html=false
    local do_verbose=false
    local do_debug=false
    local content quoted_content
    local cmd_args=()

    # Parse the arguments
    while [[ ${#} -gt 0 ]]; do
        case "${1}" in
            -a | --append)
                do_append=true
                shift 1
                ;;
            -v | --verbose)
                do_verbose=true
                shift 1
                ;;
            --debug)
                do_debug=true
                shift 1
                ;;
            -*)
                echo "error: unknown option: ${1}" >&2
                return ${E_ERROR}
                ;;
            *)
                content="${1}"
                shift 1
                ;;
        esac
    done

    # If no content is provided, read from stdin
    if [[ -z "${content}" ]]; then
        content=$(cat -)
    fi

    quoted_content=$(quote-powershell "${content}")
    ${do_append} && cmd_args+=( -Append )
    ${do_verbose} && cmd_args+=( -Verbose )
    ${do_debug} && cmd_args+=( -Debug )

    debug-vars do_append do_html do_verbose do_debug content quoted_content \
        cmd_args
    debug "Running: powershell.exe -command \"Set-Clipboard -Value ${quoted_content} ${cmd_args[*]}\""

    powershell.exe \
        -command "Set-Clipboard -Value ${quoted_content} ${cmd_args[*]}"
}

function get-clipboard() {
    :  'Get the clipboard contents

        @usage
            [-r/--raw] [-t/--text] [-u/--unicode] [-H/--html] [-m/--md]
            [-R/--rtf] [-c/--csv] [-s/--strip-crlf] [-S/--no-strip-crlf]
            [-p/--pandoc <format>] [-i/--image] [-a/--audio]
            [-v/--verbose] [--debug]

        @optarg -r/--raw
            Output the clipboard contents as is

        @optarg -t/--text
            Output the clipboard contents as plain text

        @optarg -u/--unicode
            Output the clipboard contents as Unicode text

        @optarg -H/--html
            Output the clipboard contents as HTML

        @optarg -m/--md
            Output the clipboard contents as Markdown

        @optarg -R/--rtf
            Output the clipboard contents as RTF

        @optarg -c/--csv
            Output the clipboard contents as CSV

        @optarg -p/--pandoc <format>
            Convert the clipboard contents from HTML to the specified Pandoc
            format (see https://pandoc.org/MANUAL.html#option--to)

        @optarg -s/--strip-crlf
            Strip carriage return characters from the clipboard contents

        @optarg -S/--no-strip-crlf
            Do not strip carriage return characters from the clipboard contents

        @optarg -i/--image
            Output the clipboard contents as an image

        @optarg -a/--audio
            Output the clipboard contents as audio

        @optarg -v/--verbose
            Use the Get-Clipboard command with the Verbose flag

        @optarg --debug
            Use the Get-Clipboard command with the Debug flag

        @stdout
            The clipboard contents

        @stderr
            An error message if the clipboard is empty

        @return
            0 if the clipboard is not empty, 1 otherwise
    '
    local format=""
    local text_format=""  # Text, UnicodeText, Rtf, Html, CommaSeparatedValue
    local default_format="text"
    local default_markdown="gfm"
    local pandoc_format=""  # convert HTML to any pandoc format
    local do_verbose=false
    local do_debug=false
    local do_strip_crlf=true
    local cmd_args=()

    # Parse the arguments
    while [[ ${#} -gt 0 ]]; do
        case "${1}" in
            -r | --raw)
                format="raw"
                shift 1
                ;;
            -t | --text)
                format="text"
                text_format="Text"
                shift 1
                ;;
            -u | --unicode)
                format="text"
                text_format="UnicodeText"
                shift 1
                ;;
            -H | --html)
                format="text"
                text_format="Html"
                shift 1
                ;;
            -m | --md)
                format="text"
                text_format="Html"
                pandoc_format="${default_markdown}"
                shift 1
                ;;
            -R | --rtf)
                format="text"
                text_format="Rtf"
                shift 1
                ;;
            -c | --csv)
                format="text"
                shift 1
                ;;
            -p | --pandoc)
                format="text"
                text_format="Html"
                pandoc_format="${2}"
                shift 2
                ;;
            -s | --strip-crlf)
                do_strip_crlf=true
                shift 1
                ;;
            -S | --no-strip-crlf)
                do_strip_crlf=false
                shift 1
                ;;
            -i | --image)
                format="image"
                shift 1
                ;;
            -a | --audio)
                format="audio"
                shift 1
                ;;
            -v | --verbose)
                do_verbose=true
                shift 1
                ;;
            --debug)
                do_debug=true
                shift 1
                ;;
            -*)
                echo "error: unknown option: ${1}" >&2
                return ${E_ERROR}
                ;;
            *)
                shift 1
                ;;
        esac
    done

    # Set the default format if none is provided
    [[ -z "${format}" ]] && format="${default_format}"

    # Validate pandoc_format
    if [[ -n "${pandoc_format}" ]]; then
        # Check that the format is "Text" and the text_format is "Html"
        if [[ "${format}" != "text" || "${text_format}" != "Html" ]]; then
            echo "fatal: the -p/--pandoc option cannot be used with other" >&2
            echo "       text formats" >&2
            return ${E_ERROR}
        fi

        # Check that pandoc is installed
        if ! command -v pandoc &> /dev/null; then
            echo "fatal: pandoc is not installed" >&2
            return ${E_ERROR}
        fi

        # Check that the pandoc format is valid
        if ! pandoc --list-output-formats | grep -q "^${pandoc_format}$"; then
            echo "fatal: invalid pandoc format: ${pandoc_format}" >&2
            return ${E_ERROR}
        fi
    fi

    # Set the command arguments
    case "${format}" in
        raw)
            cmd_args+=( -Raw )
            ;;
        text)
            cmd_args+=( -Format "Text" )
            ;;
        image)
            cmd_args+=( -Format "Image" )
            ;;
        audio)
            cmd_args+=( -Format "Audio" )
            ;;
    esac

    if [[ "${format}" == "text" && -n "${text_format}" ]]; then
        cmd_args+=( -TextFormatType "${text_format}" )
    fi

    ${do_verbose} && cmd_args+=( -Verbose )
    ${do_debug} && cmd_args+=( -Debug )

    debug-vars format text_format pandoc_format cmd_args
    debug "Running: powershell.exe -command \"Get-Clipboard ${cmd_args[*]}\""

    powershell.exe -command "Get-Clipboard ${cmd_args[*]}" |& {
        if [[ "${text_format}" == "Html" ]]; then
            # Exclude the Powershell header -- only start at the <html> tag
            awk '/<html>/,0'
        else
            cat
        fi
    } | {
        if [[ -n "${pandoc_format}" ]]; then
            debug "Converting HTML to ${pandoc_format} with Pandoc"
            pandoc \
                --from html \
                --to "${pandoc_format}-raw_html-fenced_code_attributes+backtick_code_blocks" \
                --strip-comments \
                --no-highlight
        else
            cat
        fi
    } | {
        if ${do_strip_crlf}; then
            tr -d '\r'
        else
            cat
        fi
    }
}
