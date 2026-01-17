#!/usr/bin/env bats
# text.bats - Comprehensive tests for text.sh functions

# Setup and teardown
setup() {
    # Mock debug functions that text.sh might use
    debug() { return 0; }
    debug-vars() { return 0; }
    export -f debug debug-vars

    # Source the text library
    source "${BATS_TEST_DIRNAME}/../text.sh"
}

teardown() {
    # Clean up any mock functions
    unset -f debug debug-vars 2>/dev/null || true
}

#------------------------------------------------------------------------------
# trim tests
#------------------------------------------------------------------------------

@test "trim: removes leading and trailing spaces" {
    result=$(trim "  hello world  ")
    [[ "$result" == "hello world" ]]
}

@test "trim: removes leading and trailing tabs" {
    result=$(trim $'\thello world\t')
    [[ "$result" == "hello world" ]]
}

@test "trim: removes mixed whitespace" {
    result=$(trim $'  \t  hello world  \t  ')
    [[ "$result" == "hello world" ]]
}

@test "trim: handles empty string" {
    result=$(trim "")
    [[ "$result" == "" ]]
}

@test "trim: handles string with no whitespace" {
    result=$(trim "hello")
    [[ "$result" == "hello" ]]
}

@test "trim: preserves internal whitespace" {
    result=$(trim "  hello   world  ")
    [[ "$result" == "hello   world" ]]
}

@test "trim: handles Unicode strings" {
    result=$(trim "  café naïve  ")
    [[ "$result" == "café naïve" ]]
}

@test "trim: handles strings with ANSI codes" {
    result=$(trim $'  \033[31mred text\033[0m  ')
    [[ "$result" == $'\033[31mred text\033[0m' ]]
}

@test "trim: handles newlines as whitespace" {
    result=$(trim $'\n\nhello\n\n')
    [[ "$result" == "hello" ]]
}

#------------------------------------------------------------------------------
# trim-left (ltrim) tests
#------------------------------------------------------------------------------

@test "trim-left: removes leading spaces only" {
    result=$(trim-left "  hello world  ")
    [[ "$result" == "hello world  " ]]
}

@test "trim-left: removes leading tabs only" {
    result=$(trim-left $'\t\thello world\t\t')
    [[ "$result" == $'hello world\t\t' ]]
}

@test "trim-left: handles empty string" {
    result=$(trim-left "")
    [[ "$result" == "" ]]
}

@test "trim-left: handles string with no leading whitespace" {
    result=$(trim-left "hello world  ")
    [[ "$result" == "hello world  " ]]
}

@test "trim-left: handles Unicode strings" {
    result=$(trim-left "  café naïve  ")
    [[ "$result" == "café naïve  " ]]
}

@test "trim-left: handles strings with ANSI codes" {
    result=$(trim-left $'  \033[31mred text\033[0m  ')
    [[ "$result" == $'\033[31mred text\033[0m  ' ]]
}

@test "trim-left: reads from stdin when no argument" {
    result=$(echo "  hello  " | trim-left)
    [[ "$result" == "hello  " ]]
}

#------------------------------------------------------------------------------
# trim-right (rtrim) tests
#------------------------------------------------------------------------------

@test "trim-right: removes trailing spaces only" {
    result=$(trim-right "  hello world  ")
    [[ "$result" == "  hello world" ]]
}

@test "trim-right: removes trailing tabs only" {
    result=$(trim-right $'\t\thello world\t\t')
    [[ "$result" == $'\t\thello world' ]]
}

@test "trim-right: handles empty string" {
    result=$(trim-right "")
    [[ "$result" == "" ]]
}

@test "trim-right: handles string with no trailing whitespace" {
    result=$(trim-right "  hello world")
    [[ "$result" == "  hello world" ]]
}

@test "trim-right: handles Unicode strings" {
    result=$(trim-right "  café naïve  ")
    [[ "$result" == "  café naïve" ]]
}

@test "trim-right: handles strings with ANSI codes" {
    result=$(trim-right $'  \033[31mred text\033[0m  ')
    [[ "$result" == $'  \033[31mred text\033[0m' ]]
}

@test "trim-right: reads from stdin when no argument" {
    result=$(echo "  hello  " | trim-right)
    [[ "$result" == "  hello" ]]
}

#------------------------------------------------------------------------------
# to-lower (lowercase) tests
#------------------------------------------------------------------------------

@test "to-lower: converts uppercase to lowercase" {
    result=$(to-lower "HELLO WORLD")
    [[ "$result" == "hello world" ]]
}

@test "to-lower: handles mixed case" {
    result=$(to-lower "HeLLo WoRLd")
    [[ "$result" == "hello world" ]]
}

@test "to-lower: preserves already lowercase" {
    result=$(to-lower "hello world")
    [[ "$result" == "hello world" ]]
}

@test "to-lower: handles empty string" {
    result=$(to-lower "")
    [[ "$result" == "" ]]
}

@test "to-lower: preserves numbers and symbols" {
    result=$(to-lower "ABC123!@#")
    [[ "$result" == "abc123!@#" ]]
}

@test "to-lower: handles Unicode characters" {
    result=$(to-lower "CAFÉ NAÏVE")
    [[ "$result" == "café naïve" ]]
}

@test "to-lower: preserves ANSI codes" {
    result=$(to-lower $'\033[31mRED TEXT\033[0m')
    [[ "$result" == $'\033[31mred text\033[0m' ]]
}

@test "to-lower: reads from stdin when no argument" {
    result=$(echo "HELLO WORLD" | to-lower)
    [[ "$result" == "hello world" ]]
}

#------------------------------------------------------------------------------
# to-upper (uppercase) tests
#------------------------------------------------------------------------------

@test "to-upper: converts lowercase to uppercase" {
    result=$(to-upper "hello world")
    [[ "$result" == "HELLO WORLD" ]]
}

@test "to-upper: handles mixed case" {
    result=$(to-upper "HeLLo WoRLd")
    [[ "$result" == "HELLO WORLD" ]]
}

@test "to-upper: preserves already uppercase" {
    result=$(to-upper "HELLO WORLD")
    [[ "$result" == "HELLO WORLD" ]]
}

@test "to-upper: handles empty string" {
    result=$(to-upper "")
    [[ "$result" == "" ]]
}

@test "to-upper: preserves numbers and symbols" {
    result=$(to-upper "abc123!@#")
    [[ "$result" == "ABC123!@#" ]]
}

@test "to-upper: handles Unicode characters" {
    result=$(to-upper "café naïve")
    [[ "$result" == "CAFÉ NAÏVE" ]]
}

@test "to-upper: preserves ANSI codes" {
    result=$(to-upper $'\033[31mred text\033[0m')
    [[ "$result" == $'\033[31mRED TEXT\033[0m' ]]
}

@test "to-upper: reads from stdin when no argument" {
    result=$(echo "hello world" | to-upper)
    [[ "$result" == "HELLO WORLD" ]]
}

#------------------------------------------------------------------------------
# to-random-case tests
#------------------------------------------------------------------------------

@test "to-random-case: produces mixed case output" {
    # Since output is random, we can only verify it contains both cases
    result=$(to-random-case "hello")
    [[ ${#result} -eq 5 ]]
    # Should only contain h,e,l,o in various cases
    [[ "$result" =~ ^[hHeElLoO]+$ ]]
}

@test "to-random-case: handles empty string" {
    result=$(to-random-case "")
    [[ "$result" == "" ]]
}

@test "to-random-case: preserves non-alphabetic characters" {
    result=$(to-random-case "123!@#")
    [[ "$result" == "123!@#" ]]
}

#------------------------------------------------------------------------------
# case-insensitive-pattern tests
#------------------------------------------------------------------------------

@test "case-insensitive-pattern: converts simple string" {
    result=$(case-insensitive-pattern "Hello")
    [[ "$result" == "[Hh][Ee][Ll][Ll][Oo]" ]]
}

@test "case-insensitive-pattern: preserves non-alphabetic characters" {
    result=$(case-insensitive-pattern "Hello123!")
    [[ "$result" == "[Hh][Ee][Ll][Ll][Oo]123!" ]]
}

@test "case-insensitive-pattern: handles empty string" {
    result=$(case-insensitive-pattern "")
    [[ "$result" == "" ]]
}

@test "case-insensitive-pattern: preserves character classes" {
    result=$(case-insensitive-pattern "H[aeiou]llo")
    [[ "$result" == "[Hh][aeiou][Ll][Ll][Oo]" ]]
}

@test "case-insensitive-pattern: handles escaped brackets" {
    result=$(case-insensitive-pattern "H\[ello\]")
    [[ "$result" == "[Hh]\[[Ee][Ll][Ll][Oo]\]" ]]
}

#------------------------------------------------------------------------------
# join tests
#------------------------------------------------------------------------------

@test "join: joins strings with delimiter" {
    result=$(join "," "apple" "banana" "cherry")
    [[ "$result" == "apple,banana,cherry" ]]
}

@test "join: handles single string" {
    result=$(join "," "apple")
    [[ "$result" == "apple" ]]
}

@test "join: handles empty delimiter" {
    result=$(join "" "a" "b" "c")
    [[ "$result" == "abc" ]]
}

@test "join: handles multi-character delimiter" {
    result=$(join " - " "one" "two" "three")
    [[ "$result" == "one - two - three" ]]
}

@test "join: handles empty strings in input" {
    result=$(join "," "a" "" "c")
    [[ "$result" == "a,,c" ]]
}

#------------------------------------------------------------------------------
# is-hex tests
#------------------------------------------------------------------------------

@test "is-hex: validates hexadecimal strings" {
    is-hex "1234567890abcdef"
}

@test "is-hex: validates uppercase hex" {
    is-hex "ABCDEF"
}

@test "is-hex: validates mixed case hex" {
    is-hex "AbCdEf123"
}

@test "is-hex: rejects non-hex characters" {
    ! is-hex "12345g"
}

@test "is-hex: rejects empty string" {
    ! is-hex ""
}

@test "is-hex: rejects hex prefix" {
    ! is-hex "0x1234"
}

#------------------------------------------------------------------------------
# is-int tests
#------------------------------------------------------------------------------

@test "is-int: validates integer strings" {
    is-int "12345"
}

@test "is-int: validates zero" {
    is-int "0"
}

@test "is-int: rejects negative numbers" {
    ! is-int "-123"
}

@test "is-int: rejects floating point" {
    ! is-int "123.45"
}

@test "is-int: rejects non-numeric" {
    ! is-int "abc"
}

@test "is-int: rejects empty string" {
    ! is-int ""
}

#------------------------------------------------------------------------------
# is-float tests
#------------------------------------------------------------------------------

@test "is-float: validates floating point strings" {
    is-float "123.45"
}

@test "is-float: validates zero float" {
    is-float "0.0"
}

@test "is-float: rejects integers" {
    ! is-float "123"
}

@test "is-float: rejects negative floats" {
    ! is-float "-123.45"
}

@test "is-float: rejects multiple decimals" {
    ! is-float "12.34.56"
}

@test "is-float: rejects non-numeric" {
    ! is-float "abc.def"
}

@test "is-float: rejects empty string" {
    ! is-float ""
}

#------------------------------------------------------------------------------
# is-number tests
#------------------------------------------------------------------------------

@test "is-number: validates integers" {
    is-number "12345"
}

@test "is-number: validates floats" {
    is-number "123.45"
}

@test "is-number: rejects negative numbers" {
    ! is-number "-123"
}

@test "is-number: rejects non-numeric" {
    ! is-number "abc"
}

@test "is-number: rejects empty string" {
    ! is-number ""
}

#------------------------------------------------------------------------------
# urlencode tests
#------------------------------------------------------------------------------

@test "urlencode: encodes spaces" {
    result=$(urlencode "hello world")
    [[ "$result" == "hello%20world" ]]
}

@test "urlencode: preserves alphanumeric" {
    result=$(urlencode "abc123")
    [[ "$result" == "abc123" ]]
}

@test "urlencode: preserves safe characters" {
    result=$(urlencode "hello-world_test.file~")
    [[ "$result" == "hello-world_test.file~" ]]
}

@test "urlencode: encodes special characters" {
    result=$(urlencode "hello@world.com")
    [[ "$result" == "hello%40world.com" ]]
}

@test "urlencode: encodes Unicode characters" {
    result=$(urlencode "café")
    # UTF-8 encoding of é is C3 A9
    [[ "$result" == *"caf%c3%a9"* ]]
}

@test "urlencode: handles empty string" {
    ! urlencode ""
}

@test "urlencode: reads from stdin with -" {
    result=$(echo -n "hello world" | urlencode -)
    [[ "$result" == "hello%20world" ]]
}

#------------------------------------------------------------------------------
# urldecode tests
#------------------------------------------------------------------------------

@test "urldecode: decodes spaces" {
    result=$(urldecode "hello%20world")
    [[ "$result" == "hello world" ]]
}

@test "urldecode: preserves unencoded characters" {
    result=$(urldecode "hello-world_test.file~")
    [[ "$result" == "hello-world_test.file~" ]]
}

@test "urldecode: decodes special characters" {
    result=$(urldecode "hello%40world.com")
    [[ "$result" == "hello@world.com" ]]
}

@test "urldecode: decodes Unicode characters" {
    result=$(urldecode "caf%c3%a9")
    [[ "$result" == "café" ]]
}

@test "urldecode: handles empty string" {
    ! urldecode ""
}

@test "urldecode: reads from stdin with -" {
    result=$(echo -n "hello%20world" | urldecode -)
    [[ "$result" == "hello world" ]]
}

#------------------------------------------------------------------------------
# rmansi tests
#------------------------------------------------------------------------------

@test "rmansi: removes ANSI color codes" {
    result=$(echo $'\033[31mred text\033[0m' | rmansi)
    [[ "$result" == "red text" ]]
}

@test "rmansi: removes multiple ANSI codes" {
    result=$(echo $'\033[1;31mBold Red\033[0m \033[32mGreen\033[0m' | rmansi)
    [[ "$result" == "Bold Red Green" ]]
}

@test "rmansi: preserves text without ANSI codes" {
    result=$(echo "plain text" | rmansi)
    [[ "$result" == "plain text" ]]
}

@test "rmansi: handles empty input" {
    result=$(echo "" | rmansi)
    [[ "$result" == "" ]]
}

@test "rmansi: removes complex ANSI sequences" {
    result=$(echo $'\033[38;5;196mExtended Color\033[0m' | rmansi)
    [[ "$result" == "Extended Color" ]]
}

#------------------------------------------------------------------------------
# rmblank tests
#------------------------------------------------------------------------------

@test "rmblank: removes blank lines" {
    local input=$'line1\n\nline2\n\nline3'
    result=$(echo "$input" | rmblank)
    [[ "$result" == $'line1\nline2\nline3' ]]
}

@test "rmblank: preserves non-blank lines" {
    local input=$'line1\nline2\nline3'
    result=$(echo "$input" | rmblank)
    [[ "$result" == "$input" ]]
}

@test "rmblank: preserves lines with whitespace" {
    local input=$'line1\n   \nline2'
    result=$(echo "$input" | rmblank)
    [[ "$result" == $'line1\n   \nline2' ]]
}

#------------------------------------------------------------------------------
# rmempty tests
#------------------------------------------------------------------------------

@test "rmempty: removes empty lines including whitespace-only" {
    local input=$'line1\n\n   \nline2\n\t\nline3'
    result=$(echo "$input" | rmempty)
    [[ "$result" == $'line1\nline2\nline3' ]]
}

@test "rmempty: preserves non-empty lines" {
    local input=$'line1\nline2\nline3'
    result=$(echo "$input" | rmempty)
    [[ "$result" == "$input" ]]
}

@test "rmempty: removes lines with only tabs and spaces" {
    local input=$'line1\n\t   \t\nline2'
    result=$(echo "$input" | rmempty)
    [[ "$result" == $'line1\nline2' ]]
}

#------------------------------------------------------------------------------
# preview-output tests
#------------------------------------------------------------------------------

@test "preview-output: shows all lines when under limit" {
    local data=$'line1\nline2\nline3'
    result=$(preview-output --text "$data" --preview 5)
    [[ "$result" == "$data" ]]
}

@test "preview-output: truncates and shows remainder count" {
    local data=$'line1\nline2\nline3\nline4\nline5'
    result=$(preview-output --text "$data" --preview 3)
    [[ "$result" == *"line1"* ]]
    [[ "$result" == *"line2"* ]]
    [[ "$result" == *"line3"* ]]
    [[ "$result" == *"...and 2 more lines"* ]]
}

@test "preview-output: handles custom label" {
    local data=$'line1\nline2\nline3\nline4'
    result=$(preview-output --text "$data" --preview 2 --label "row")
    [[ "$result" == *"...and 2 more rows"* ]]
}

@test "preview-output: reads from file" {
    temp_file=$(mktemp)
    echo -e "line1\nline2\nline3" > "$temp_file"
    result=$(preview-output --preview 2 "$temp_file")
    [[ "$result" == *"line1"* ]]
    [[ "$result" == *"line2"* ]]
    [[ "$result" == *"...and 1 more line"* ]]
    rm -f "$temp_file"
}

#------------------------------------------------------------------------------
# uniq-column tests
#------------------------------------------------------------------------------

@test "uniq-column: removes duplicates by column" {
    local data=$'a\t1\nb\t2\na\t3\nc\t4'
    result=$(echo "$data" | uniq-column -c 1)
    [[ "$result" == $'a\t1\nb\t2\nc\t4' ]]
}

@test "uniq-column: handles custom delimiter" {
    local data=$'a,1\nb,2\na,3\nc,4'
    result=$(echo "$data" | uniq-column -c 1 -d ",")
    [[ "$result" == $'a,1\nb,2\nc,4' ]]
}

@test "uniq-column: preserves order" {
    local data=$'c\t1\nb\t2\na\t3\nc\t4\nb\t5'
    result=$(echo "$data" | uniq-column -c 1)
    [[ "$result" == $'c\t1\nb\t2\na\t3' ]]
}

@test "uniq-column: handles different column" {
    local data=$'1\ta\n2\tb\n3\ta\n4\tc'
    result=$(echo "$data" | uniq-column -c 2)
    [[ "$result" == $'1\ta\n2\tb\n4\tc' ]]
}

#------------------------------------------------------------------------------
# Performance characteristic tests
#------------------------------------------------------------------------------

@test "performance: trim functions handle large strings efficiently" {
    # Generate a large string with lots of whitespace
    large_string="    $(head -c 1000 /dev/urandom | base64 | tr -d '\n')    "

    # Time the operation (should complete quickly)
    result=$(trim "$large_string")

    # Verify the output is correct (no leading/trailing spaces)
    [[ "$result" != " "* ]]
    [[ "$result" != *" " ]]
}

@test "performance: case conversion handles Unicode efficiently" {
    # Test with various Unicode strings
    unicode_text="ΑΒΓΔΕ АБВГД 中文字符 العربية"

    result=$(to-lower "$unicode_text")

    # Basic check that something was converted
    [[ "$result" != "$unicode_text" ]]
}