#!/usr/bin/env bash
: "
This module provides functions for generating Lorem Ipsum placeholder text.

Lorem Ipsum is pseudo-Latin text commonly used in the printing and typesetting
industry. This implementation generates random Lorem Ipsum text with customizable
length, paragraph count, and words per paragraph.
"

include-source 'random'
include-source 'docs'

function ipsum() {
    :  '[@summary] Generate Lorem Ipsum placeholder text
        
        @description
        Generate Lorem Ipsum placeholder text with customizable output format.
        By default, generates a single paragraph of Lorem Ipsum text. The first
        paragraph always starts with the traditional "Lorem ipsum dolor sit
        amet" opening.

        @usage
            [-h/--help] [-p/--paragraphs <count>] [-w/--words <count>]
            [-W/--words-per-paragraph <count>] [-s/--sentences <count>]
            [-S/--sentences-per-paragraph <count>] [-n/--no-newlines]
            [-t/--traditional]

        @option -h/--help
            Show this help message

        @option -p/--paragraphs <count>
            Number of paragraphs to generate (default: 1)

        @option -w/--words <count>
            Total number of words to generate. Overrides paragraphs option

        @option -W/--words-per-paragraph <count>
            Number of words per paragraph (default: 50-100)

        @option -s/--sentences <count>
            Total number of sentences to generate. Overrides paragraphs option

        @option -S/--sentences-per-paragraph <count>
            Number of sentences per paragraph (default: 3-7)

        @option -n/--no-newlines
            Output all text on a single line (no paragraph breaks)

        @option -t/--traditional
            Use only traditional Lorem Ipsum words (smaller vocabulary)

        @stdout
            Generated Lorem Ipsum text

        @return 0
            Success

        @return 1
            Invalid argument provided

        @example
            # Generate a single paragraph
            ipsum

        @example
            # Generate 3 paragraphs
            ipsum -p 3

        @example
            # Generate exactly 25 words
            ipsum -w 25

        @example
            # Generate 5 paragraphs with 30-50 words each
            ipsum -p 5 -W 30-50
    '
    
    # Lorem Ipsum word bank
    local -a LOREM_WORDS=(
        "lorem" "ipsum" "dolor" "sit" "amet" "consectetur" "adipiscing" "elit"
        "sed" "do" "eiusmod" "tempor" "incididunt" "ut" "labore" "et" "dolore"
        "magna" "aliqua" "enim" "ad" "minim" "veniam" "quis" "nostrud"
        "exercitation" "ullamco" "laboris" "nisi" "aliquip" "ex" "ea" "commodo"
        "consequat" "duis" "aute" "irure" "in" "reprehenderit" "voluptate"
        "velit" "esse" "cillum" "fugiat" "nulla" "pariatur" "excepteur" "sint"
        "occaecat" "cupidatat" "non" "proident" "sunt" "culpa" "qui" "officia"
        "deserunt" "mollit" "anim" "id" "est" "laborum" "perspiciatis" "unde"
        "omnis" "iste" "natus" "error" "voluptatem" "accusantium" "doloremque"
        "laudantium" "totam" "rem" "aperiam" "eaque" "ipsa" "quae" "ab" "illo"
        "inventore" "veritatis" "quasi" "architecto" "beatae" "vitae" "dicta"
        "explicabo" "nemo" "enim" "ipsam" "quia" "voluptas" "aspernatur" "aut"
        "odit" "fugit" "consequuntur" "magni" "dolores" "eos" "ratione"
        "sequi" "nesciunt" "neque" "porro" "quisquam" "dolorem" "adipisci"
        "numquam" "eius" "modi" "tempora" "magnam" "quaerat" "etiam"
    )
    
    # Traditional Lorem Ipsum words (smaller set)
    local -a TRADITIONAL_WORDS=(
        "lorem" "ipsum" "dolor" "sit" "amet" "consectetur" "adipiscing" "elit"
        "sed" "diam" "nonummy" "nibh" "euismod" "tincidunt" "ut" "laoreet"
        "dolore" "magna" "aliquam" "erat" "volutpat" "wisi" "enim" "ad" "minim"
        "veniam" "quis" "nostrud" "exerci" "tation" "ullamcorper" "suscipit"
        "lobortis" "nisl" "aliquip" "ex" "ea" "commodo" "consequat"
    )
    
    # Default values
    local paragraphs=1
    local words_total=""
    local words_per_paragraph=""
    local words_per_paragraph_min=50
    local words_per_paragraph_max=100
    local sentences_total=""
    local sentences_per_paragraph=""
    local sentences_per_paragraph_min=3
    local sentences_per_paragraph_max=7
    local no_newlines=false
    local use_traditional=false
    local help=false
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "${1}" in
            -h | --help)
                help=true
                shift
                ;;
            -p | --paragraphs)
                if [[ -z "${2}" ]] || ! [[ "${2}" =~ ^[0-9]+$ ]]; then
                    echo "Error: --paragraphs requires a positive integer" >&2
                    return 1
                fi
                paragraphs="${2}"
                shift 2
                ;;
            -w | --words)
                if [[ -z "${2}" ]] || ! [[ "${2}" =~ ^[0-9]+$ ]]; then
                    echo "Error: --words requires a positive integer" >&2
                    return 1
                fi
                words_total="${2}"
                shift 2
                ;;
            -W | --words-per-paragraph)
                if [[ -z "${2}" ]]; then
                    echo "Error: --words-per-paragraph requires a value" >&2
                    return 1
                fi
                if [[ "${2}" =~ ^([0-9]+)-([0-9]+)$ ]]; then
                    words_per_paragraph_min="${BASH_REMATCH[1]}"
                    words_per_paragraph_max="${BASH_REMATCH[2]}"
                elif [[ "${2}" =~ ^[0-9]+$ ]]; then
                    words_per_paragraph_min="${2}"
                    words_per_paragraph_max="${2}"
                else
                    echo "Error: --words-per-paragraph requires a number or range (e.g., 50 or 30-50)" >&2
                    return 1
                fi
                words_per_paragraph="${2}"
                shift 2
                ;;
            -s | --sentences)
                if [[ -z "${2}" ]] || ! [[ "${2}" =~ ^[0-9]+$ ]]; then
                    echo "Error: --sentences requires a positive integer" >&2
                    return 1
                fi
                sentences_total="${2}"
                shift 2
                ;;
            -S | --sentences-per-paragraph)
                if [[ -z "${2}" ]]; then
                    echo "Error: --sentences-per-paragraph requires a value" >&2
                    return 1
                fi
                if [[ "${2}" =~ ^([0-9]+)-([0-9]+)$ ]]; then
                    sentences_per_paragraph_min="${BASH_REMATCH[1]}"
                    sentences_per_paragraph_max="${BASH_REMATCH[2]}"
                elif [[ "${2}" =~ ^[0-9]+$ ]]; then
                    sentences_per_paragraph_min="${2}"
                    sentences_per_paragraph_max="${2}"
                else
                    echo "Error: --sentences-per-paragraph requires a number or range (e.g., 5 or 3-7)" >&2
                    return 1
                fi
                sentences_per_paragraph="${2}"
                shift 2
                ;;
            -n | --no-newlines)
                no_newlines=true
                shift
                ;;
            -t | --traditional)
                use_traditional=true
                shift
                ;;
            *)
                echo "Error: Unknown option '${1}'" >&2
                echo "Use --help for usage information" >&2
                return 1
                ;;
        esac
    done
    
    # Show help if requested
    if ${help}; then
        # TODO: Update this to use a more user-friendly help formatter once docs.sh
        # provides a function that generates traditional --help style output instead
        # of the current declare statement format
        generate-function-docstring "${FUNCNAME[0]}" >&2
        return 0
    fi
    
    # Select word bank
    local -a word_bank
    if ${use_traditional}; then
        word_bank=("${TRADITIONAL_WORDS[@]}")
    else
        word_bank=("${LOREM_WORDS[@]}")
    fi
    
    # Generate text
    local output=""
    local first_paragraph=true
    
    # Handle different generation modes
    if [[ -n "${words_total}" ]]; then
        # Generate exact number of words
        for ((i = 0; i < words_total; i++)); do
            if [[ ${i} -eq 0 ]] && ${first_paragraph}; then
                output+="Lorem ipsum dolor sit amet"
                i=4  # We've added 5 words
            else
                if [[ ${i} -gt 0 ]]; then
                    output+=" "
                fi
                output+="$(random-choice "${word_bank[@]}")"
            fi
        done
        output+="."
    elif [[ -n "${sentences_total}" ]]; then
        # Generate exact number of sentences
        for ((s = 0; s < sentences_total; s++)); do
            local sentence=""
            local words_in_sentence=$(random-int 5 15)
            
            for ((w = 0; w < words_in_sentence; w++)); do
                if [[ ${s} -eq 0 ]] && [[ ${w} -eq 0 ]] && ${first_paragraph}; then
                    sentence="Lorem ipsum dolor sit amet"
                    w=4  # We've added 5 words
                else
                    if [[ -n "${sentence}" ]]; then
                        sentence+=" "
                    fi
                    local word="$(random-choice "${word_bank[@]}")"
                    if [[ ${w} -eq 0 ]]; then
                        # Capitalize first word of sentence
                        word="${word^}"
                    fi
                    sentence+="${word}"
                fi
            done
            
            if [[ -n "${output}" ]]; then
                output+=" "
            fi
            output+="${sentence}."
        done
    else
        # Generate paragraphs
        for ((p = 0; p < paragraphs; p++)); do
            local paragraph=""
            local num_sentences=$(random-int "${sentences_per_paragraph_min}" "${sentences_per_paragraph_max}")
            
            for ((s = 0; s < num_sentences; s++)); do
                local sentence=""
                local words_in_sentence=$(random-int 5 15)
                
                for ((w = 0; w < words_in_sentence; w++)); do
                    if [[ ${p} -eq 0 ]] && [[ ${s} -eq 0 ]] && [[ ${w} -eq 0 ]] && ${first_paragraph}; then
                        sentence="Lorem ipsum dolor sit amet"
                        w=4  # We've added 5 words
                    else
                        if [[ -n "${sentence}" ]]; then
                            sentence+=" "
                        fi
                        local word="$(random-choice "${word_bank[@]}")"
                        if [[ ${w} -eq 0 ]]; then
                            # Capitalize first word of sentence
                            word="${word^}"
                        fi
                        sentence+="${word}"
                    fi
                done
                
                if [[ -n "${paragraph}" ]]; then
                    paragraph+=" "
                fi
                paragraph+="${sentence}."
            done
            
            if [[ -n "${output}" ]] && ! ${no_newlines}; then
                output+=$'\n\n'
            elif [[ -n "${output}" ]]; then
                output+=" "
            fi
            output+="${paragraph}"
            first_paragraph=false
        done
    fi
    
    echo "${output}"
}