#!/usr/bin/env bash
:  '
Color variables using ANSI escape codes and functions to set them up.

Variables are set using ANSI-C escape sequences so that they can be used in any
context, including `echo` commands without needing to use the `-e` flag.

When the lib is sourced, it can optionally set up the color variables. The
options are:
- `--auto`: Set up colors only if stdout is a TTY
- `--setup-colors`: Always set up colors
- `--no-auto` or `--no-setup-colors`: Do not set up colors (but still load the
  functions)

The default is `--auto`.

# ANSI Color Code Reference

All color codes follow the format `\033[{code(s)}m`, where `{code(s)}` is a
single code or a semicolon-separated list of codes. For example:
- `\033[31m`: Red text
- `\033[31;1m`: Bold red text
- `\033[31;1;4m`: Bold red underlined text

## Style Codes
- 0: S_RESET: Reset all styles
- 1: S_BOLD: Bold
- 2: S_DIM: Dim
- 3: S_ITALIC: Italic (not widely supported)
- 4: S_UNDERLINE: Underline
- 5: S_BLINK: Blink (slow)
- 6: S_BLINK_FAST: Blink (fast)
- 7: S_REVERSE: Reverse
- 8: S_HIDDEN: Hidden (not widely supported)
- 9: S_STRIKETHROUGH: Strikethrough (not widely supported)
- 10: S_DEFAULT: Default font

## Foreground Color Codes
- 30-37: Standard colors
- 38: RGB color
    - followed by `;2;R;G;B`, e.g. `\033[38;2;255;0;0m` for red
    - followed by `;5;N` (0 <= N <= 255), e.g. `\033[38;5;196m` for red
        - This library generates C_(001-255) variables for these colors
- 39: Default foreground color

## Background Color Codes
- 40-47: Standard colors
- 48: RGB color
    - followed by `;2;R;G;B`, e.g. `\033[48;2;255;0;0m` for red
    - followed by `;5;N` (0 <= N <= 255), e.g. `\033[48;5;196m` for red
        - This library generates C_(001-255)_BG variables for these colors
- 49: Default background color

## Standard Colors
- 30: C_BLACK: Black
- 31: C_RED: Red
- 32: C_GREEN: Green
- 33: C_YELLOW: Yellow
- 34: C_BLUE: Blue
- 35: C_MAGENTA: Magenta
- 36: C_CYAN: Cyan
- 37: C_WHITE: White

## RGB Colors
- 38;2;R;G;B: Foreground color
    - e.g. `\033[38;2;255;0;0m`: Red
- 48;2;R;G;B: Background color
    - e.g. `\033[48;2;255;0;0m`: Red

'

# Determine if FD 1 (stdout) is a terminal (used for auto-loading)
[ -t 1 ] && __IS_TTY=true || __IS_TTY=false

function setup-colors() {
    export C_BLACK=$'\033[30m'
    export C_RED=$'\033[31m'
    export C_GREEN=$'\033[32m'
    export C_YELLOW=$'\033[33m'
    export C_BLUE=$'\033[34m'
    export C_MAGENTA=$'\033[35m'
    export C_CYAN=$'\033[36m'
    export C_WHITE=$'\033[37m'
    export C_RGB=$'\033[38;2;%d;%d;%dm'
    export C_DEFAULT_FG=$'\033[39m'
    export C_BLACK_BG=$'\033[40m'
    export C_RED_BG=$'\033[41m'
    export C_GREEN_BG=$'\033[42m'
    export C_YELLOW_BG=$'\033[43m'
    export C_BLUE_BG=$'\033[44m'
    export C_MAGENTA_BG=$'\033[45m'
    export C_CYAN_BG=$'\033[46m'
    export C_WHITE_BG=$'\033[47m'
    export C_RGB_BG=$'\033[48;2;%d;%d;%dm'
    export C_DEFAULT_BG=$'\033[49m'
    export S_RESET=$'\033[0m'
    export S_BOLD=$'\033[1m'
    export S_DIM=$'\033[2m'
    export S_ITALIC=$'\033[3m'  # not widely supported, is sometimes "inverse"
    export S_UNDERLINE=$'\033[4m'
    export S_BLINK=$'\033[5m'  # slow blink
    export S_BLINK_FAST=$'\033[6m'  # fast blink
    export S_REVERSE=$'\033[7m'
    export S_HIDDEN=$'\033[8m'  # not widely supported
    export S_STRIKETHROUGH=$'\033[9m'  # not widely supported
    export S_DEFAULT=$'\033[10m'

    # Loop to set up `C_(001-255)` and `C_(001-255)_BG` variables
    for i in {0..255}; do
        local varname="00${i}"
        varname="C_${varname: -3}"
        export ${varname}=$'\033'"[38;5;${i}m"
        export ${varname}_BG=$'\033'"[48;5;${i}m"
    done
}

function unset-colors() {
    local color_vars=(
        C_BLACK C_RED C_GREEN C_YELLOW C_BLUE C_MAGENTA C_CYAN C_WHITE
        C_RGB C_DEFAULT_FG C_BLACK_BG C_RED_BG C_GREEN_BG C_YELLOW_BG
        C_BLUE_BG C_MAGENTA_BG C_CYAN_BG C_WHITE_BG C_RGB_BG C_DEFAULT_BG
        S_RESET S_BOLD S_DIM S_ITALIC S_UNDERLINE S_BLINK S_BLINK_FAST
        S_REVERSE S_HIDDEN S_STRIKETHROUGH S_DEFAULT
    )

    for i in {0..255}; do
        local varname="00${i}"
        varname="C_${varname: -3}"
        color_vars+=(${varname} ${varname}_BG)
    done

    unset ${color_vars[@]}
}


## run on source ###############################################################

if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    # When sourcing the script, allow some options to be passed in
    __load_colors="auto" # "auto", "true", "always", "yes", "false", "never", "no"

    # Parse the arguments
    while [[ ${#} -gt 0 ]]; do
        case "${1}" in
            --auto)
                __load_colors=auto
                ;;
            --setup-colors)
                __load_colors=true
                ;;
            --no-auto | --no-setup-colors)
                __load_colors=false
                ;;
            *)
                echo "$(basename "${BASH_SOURCE[0]}"): unknown option: ${1}" >&2
                return 1
                ;;
        esac
        shift 1
    done

    # Set up the colors
    case "${__load_colors}" in
        auto)
            # In the default "auto" mode, only set up colors if stdout is a TTY
            if ${__IS_TTY}; then
                setup-colors
            fi
            ;;
        true | always | yes)
            setup-colors
            ;;
        false | never | no)
            unset-colors
            ;;
    esac

    ## Export Functions ########################################################
    ############################################################################

    export -f setup-colors
    export -f unset-colors
fi
