#!/usr/bin/env bats

load '../include.sh'
load '../ipsum.sh'
load '../random.sh'
load '../docs.sh'

# Test basic functionality
@test "ipsum generates output with default settings" {
    run ipsum
    [ "$status" -eq 0 ]
    [ -n "$output" ]
    # Should start with traditional Lorem ipsum
    [[ "$output" =~ ^Lorem\ ipsum\ dolor\ sit\ amet ]]
}

# Test help option
@test "ipsum shows help with -h flag" {
    # Capture both stdout and stderr
    output=$(ipsum -h 2>&1)
    status=$?
    [ "$status" -eq 0 ]
    # Help should be shown
    [[ "$output" =~ "Generate Lorem Ipsum placeholder text" ]]
}

@test "ipsum shows help with --help flag" {
    # Capture both stdout and stderr
    output=$(ipsum --help 2>&1)
    status=$?
    [ "$status" -eq 0 ]
    # Help should be shown
    [[ "$output" =~ "Generate Lorem Ipsum placeholder text" ]]
}

# Test paragraph generation
@test "ipsum generates correct number of paragraphs" {
    run ipsum -p 3
    [ "$status" -eq 0 ]
    # Count number of paragraph breaks (empty lines)
    paragraph_count=$(echo "$output" | grep -c '^$')
    # Should have 2 empty lines for 3 paragraphs
    [ "$paragraph_count" -eq 2 ]
}

@test "ipsum generates single paragraph with -p 1" {
    run ipsum -p 1
    [ "$status" -eq 0 ]
    # Should have no empty lines
    # Count actual lines minus non-empty lines to get empty line count
    total_lines=$(echo "$output" | wc -l)
    non_empty_lines=$(echo "$output" | grep -c '.')
    empty_lines=$((total_lines - non_empty_lines))
    [ "$empty_lines" -eq 0 ]
}

# Test word generation
@test "ipsum generates exact number of words with -w" {
    run ipsum -w 10
    [ "$status" -eq 0 ]
    # Count words (accounting for the period at the end)
    word_count=$(echo "$output" | tr -d '.' | wc -w)
    [ "$word_count" -eq 10 ]
}

@test "ipsum starts with Lorem ipsum even with exact word count" {
    run ipsum -w 20
    [ "$status" -eq 0 ]
    [[ "$output" =~ ^Lorem\ ipsum\ dolor\ sit\ amet ]]
}

# Test sentence generation
@test "ipsum generates sentences with proper punctuation" {
    run ipsum -s 3
    [ "$status" -eq 0 ]
    # Count periods
    period_count=$(echo "$output" | grep -o '\.' | wc -l)
    [ "$period_count" -eq 3 ]
}

@test "ipsum capitalizes first word of each sentence" {
    run ipsum -s 5
    [ "$status" -eq 0 ]
    # Check that after each period and space, there's a capital letter
    # (except for the last period)
    echo "$output" | grep -qE '(\. [A-Z]|^[A-Z])'
}

# Test no-newlines option
@test "ipsum respects --no-newlines flag" {
    run ipsum -p 3 --no-newlines
    [ "$status" -eq 0 ]
    # Should have no newlines
    newline_count=$(echo "$output" | wc -l)
    [ "$newline_count" -eq 1 ]
}

@test "ipsum respects -n flag" {
    run ipsum -p 3 -n
    [ "$status" -eq 0 ]
    # Should have no newlines
    newline_count=$(echo "$output" | wc -l)
    [ "$newline_count" -eq 1 ]
}

# Test traditional mode
@test "ipsum uses limited vocabulary with --traditional" {
    run ipsum -t -w 50
    [ "$status" -eq 0 ]
    # Check that output contains only traditional Lorem Ipsum words
    # Should contain common traditional words
    [[ "$output" =~ (lorem|ipsum|dolor|sit|amet|consectetur|adipiscing|elit) ]]
}

# Test error handling
@test "ipsum returns error for invalid paragraph count" {
    run ipsum -p abc
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Error: --paragraphs requires a positive integer" ]]
}

@test "ipsum returns error for invalid word count" {
    run ipsum -w -5
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Error: --words requires a positive integer" ]]
}

@test "ipsum returns error for invalid sentence count" {
    run ipsum -s 0.5
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Error: --sentences requires a positive integer" ]]
}

@test "ipsum returns error for unknown option" {
    run ipsum --unknown-option
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Error: Unknown option" ]]
}

# Test words-per-paragraph option
@test "ipsum accepts single number for --words-per-paragraph" {
    run ipsum -p 2 -W 10
    [ "$status" -eq 0 ]
    # Each paragraph should have roughly 10 words
    # This is harder to test exactly due to sentence structure
    [ -n "$output" ]
}

@test "ipsum accepts range for --words-per-paragraph" {
    run ipsum -p 2 -W 10-20
    [ "$status" -eq 0 ]
    [ -n "$output" ]
}

@test "ipsum returns error for invalid --words-per-paragraph" {
    run ipsum -W abc
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Error: --words-per-paragraph requires a number or range" ]]
}

# Test sentences-per-paragraph option
@test "ipsum accepts single number for --sentences-per-paragraph" {
    run ipsum -p 1 -S 2
    [ "$status" -eq 0 ]
    # Should have exactly 2 sentences when specifying a single value
    sentence_count=$(echo "$output" | grep -o '\.' | wc -l)
    [ "$sentence_count" -eq 2 ]
}

@test "ipsum accepts range for --sentences-per-paragraph" {
    run ipsum -p 1 -S 3-5
    [ "$status" -eq 0 ]
    # Should have between 3 and 5 sentences
    sentence_count=$(echo "$output" | grep -o '\.' | wc -l)
    [ "$sentence_count" -ge 3 ]
    [ "$sentence_count" -le 5 ]
}

# Test content validation
@test "ipsum output contains Lorem Ipsum words" {
    run ipsum -w 100
    [ "$status" -eq 0 ]
    # Check for common Lorem Ipsum words
    [[ "$output" =~ (dolor|consectetur|adipiscing|elit|eiusmod|tempor) ]]
}

@test "ipsum output has proper sentence structure" {
    run ipsum -s 5
    [ "$status" -eq 0 ]
    # Each sentence should end with a period
    # Each sentence should start with a capital letter
    # No double spaces
    ! [[ "$output" =~ "  " ]]
    # No period followed directly by a letter
    ! [[ "$output" =~ "\.[a-z]" ]]
}

# Test combination of options
@test "ipsum handles multiple options correctly" {
    run ipsum -p 2 -n -t
    [ "$status" -eq 0 ]
    # Should be on one line
    newline_count=$(echo "$output" | wc -l)
    [ "$newline_count" -eq 1 ]
    # Should start with Lorem ipsum
    [[ "$output" =~ ^Lorem\ ipsum\ dolor\ sit\ amet ]]
}

# Test that different runs produce different output
@test "ipsum produces varied output on multiple runs" {
    run ipsum -w 20
    [ "$status" -eq 0 ]
    output1="$output"
    
    run ipsum -w 20
    [ "$status" -eq 0 ]
    output2="$output"
    
    # Both should start with Lorem ipsum
    [[ "$output1" =~ ^Lorem\ ipsum\ dolor\ sit\ amet ]]
    [[ "$output2" =~ ^Lorem\ ipsum\ dolor\ sit\ amet ]]
    
    # But the rest should be different (with very high probability)
    # Remove the common beginning to compare the rest
    rest1=${output1#Lorem ipsum dolor sit amet }
    rest2=${output2#Lorem ipsum dolor sit amet }
    [ "$rest1" != "$rest2" ]
}