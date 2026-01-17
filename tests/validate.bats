#!/usr/bin/env bats

# Load the validate library
setup() {
    load test_helpers
    source "${BATS_TEST_DIRNAME}/../validate.sh"
}

# Email validation tests
@test "validate-email: accepts valid email addresses" {
    run validate-email "user@example.com"
    [ "$status" -eq 0 ]

    run validate-email "john.doe@company.co.uk"
    [ "$status" -eq 0 ]

    run validate-email "user+tag@example.com"
    [ "$status" -eq 0 ]

    run validate-email "user_name@example-domain.com"
    [ "$status" -eq 0 ]

    run validate-email "123@example.com"
    [ "$status" -eq 0 ]
}

@test "validate-email: rejects invalid email addresses" {
    run validate-email ""
    [ "$status" -eq 1 ]
    [[ "$output" =~ "email address cannot be empty" ]]

    run validate-email "notanemail"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "invalid email address" ]]

    run validate-email "@example.com"
    [ "$status" -eq 1 ]

    run validate-email "user@"
    [ "$status" -eq 1 ]

    run validate-email "user@.com"
    [ "$status" -eq 1 ]

    run validate-email "user@example"
    [ "$status" -eq 1 ]

    run validate-email "user name@example.com"
    [ "$status" -eq 1 ]
}

@test "is-email: silent validation" {
    run is-email "user@example.com"
    [ "$status" -eq 0 ]
    [ -z "$output" ]

    run is-email "invalid"
    [ "$status" -eq 1 ]
    [ -z "$output" ]
}

# URL validation tests
@test "validate-url: accepts valid URLs" {
    run validate-url "http://example.com"
    [ "$status" -eq 0 ]

    run validate-url "https://www.example.com"
    [ "$status" -eq 0 ]

    run validate-url "https://example.com:8080"
    [ "$status" -eq 0 ]

    run validate-url "https://example.com/path/to/resource"
    [ "$status" -eq 0 ]

    run validate-url "https://example.com/path?query=value"
    [ "$status" -eq 0 ]

    run validate-url "https://example.com/path#anchor"
    [ "$status" -eq 0 ]

    run validate-url "ftp://files.example.com"
    [ "$status" -eq 0 ]

    run validate-url "https://user:pass@example.com"
    [ "$status" -eq 0 ]
}

@test "validate-url: rejects invalid URLs" {
    run validate-url ""
    [ "$status" -eq 1 ]
    [[ "$output" =~ "URL cannot be empty" ]]

    run validate-url "not a url"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "invalid URL" ]]

    run validate-url "example.com"
    [ "$status" -eq 1 ]

    run validate-url "://example.com"
    [ "$status" -eq 1 ]

    run validate-url "http:/example.com"
    [ "$status" -eq 1 ]

    run validate-url "ssh://example.com"
    [ "$status" -eq 1 ]
}

@test "is-url: silent validation" {
    run is-url "https://example.com"
    [ "$status" -eq 0 ]
    [ -z "$output" ]

    run is-url "invalid"
    [ "$status" -eq 1 ]
    [ -z "$output" ]
}

# IP validation tests
@test "validate-ipv4: accepts valid IPv4 addresses" {
    run validate-ipv4 "192.168.1.1"
    [ "$status" -eq 0 ]

    run validate-ipv4 "10.0.0.0"
    [ "$status" -eq 0 ]

    run validate-ipv4 "255.255.255.255"
    [ "$status" -eq 0 ]

    run validate-ipv4 "0.0.0.0"
    [ "$status" -eq 0 ]

    run validate-ipv4 "172.16.0.1"
    [ "$status" -eq 0 ]
}

@test "validate-ipv4: rejects invalid IPv4 addresses" {
    run validate-ipv4 ""
    [ "$status" -eq 1 ]
    [[ "$output" =~ "IPv4 address cannot be empty" ]]

    run validate-ipv4 "256.1.1.1"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "octet out of range" ]]

    run validate-ipv4 "192.168.1"
    [ "$status" -eq 1 ]

    run validate-ipv4 "192.168.1.1.1"
    [ "$status" -eq 1 ]

    run validate-ipv4 "192.168.-1.1"
    [ "$status" -eq 1 ]

    run validate-ipv4 "192.168.a.1"
    [ "$status" -eq 1 ]
}

@test "validate-ipv6: accepts valid IPv6 addresses" {
    run validate-ipv6 "2001:0db8:85a3:0000:0000:8a2e:0370:7334"
    [ "$status" -eq 0 ]

    run validate-ipv6 "2001:db8:85a3::8a2e:370:7334"
    [ "$status" -eq 0 ]

    run validate-ipv6 "::"
    [ "$status" -eq 0 ]

    run validate-ipv6 "::1"
    [ "$status" -eq 0 ]

    run validate-ipv6 "fe80::1%lo0"
    [ "$status" -eq 0 ]
}

@test "validate-ipv6: rejects invalid IPv6 addresses" {
    run validate-ipv6 ""
    [ "$status" -eq 1 ]
    [[ "$output" =~ "IPv6 address cannot be empty" ]]

    run validate-ipv6 "gggg::1"
    [ "$status" -eq 1 ]

    run validate-ipv6 ":::"
    [ "$status" -eq 1 ]

    run validate-ipv6 "2001:0db8:85a3::8a2e:370g:7334"
    [ "$status" -eq 1 ]
}

@test "validate-ip: accepts both IPv4 and IPv6" {
    run validate-ip "192.168.1.1"
    [ "$status" -eq 0 ]

    run validate-ip "2001:db8::1"
    [ "$status" -eq 0 ]

    run validate-ip "::1"
    [ "$status" -eq 0 ]
}

@test "validate-ip: rejects invalid IP addresses" {
    run validate-ip ""
    [ "$status" -eq 1 ]

    run validate-ip "not an ip"
    [ "$status" -eq 1 ]

    run validate-ip "999.999.999.999"
    [ "$status" -eq 1 ]
}

@test "is-ip: silent validation" {
    run is-ip "192.168.1.1"
    [ "$status" -eq 0 ]
    [ -z "$output" ]

    run is-ip "invalid"
    [ "$status" -eq 1 ]
    [ -z "$output" ]
}

# Path validation tests
@test "validate-path: accepts valid paths" {
    run validate-path "/home/user/file.txt"
    [ "$status" -eq 0 ]

    run validate-path "./relative/path"
    [ "$status" -eq 0 ]

    run validate-path "~/documents/file.pdf"
    [ "$status" -eq 0 ]

    run validate-path "/path with spaces/file.txt"
    [ "$status" -eq 0 ]

    run validate-path "file-name_123.txt"
    [ "$status" -eq 0 ]
}

@test "validate-path: rejects invalid paths" {
    run validate-path ""
    [ "$status" -eq 1 ]
    [[ "$output" =~ "path cannot be empty" ]]

    run validate-path "/path/../../../etc/passwd"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "path traversal detected" ]]

    run validate-path "/path/with|pipe"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "invalid characters" ]]

    run validate-path "/path/with\$variable"
    [ "$status" -eq 1 ]
}

@test "validate-path: validates path type when exists" {
    # Create test file and directory
    local test_file="${BATS_TEST_TMPDIR}/test.txt"
    local test_dir="${BATS_TEST_TMPDIR}/testdir"

    touch "${test_file}"
    mkdir -p "${test_dir}"

    # File type validation
    run validate-path "${test_file}" "file"
    [ "$status" -eq 0 ]

    run validate-path "${test_dir}" "file"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "not a file" ]]

    # Directory type validation
    run validate-path "${test_dir}" "dir"
    [ "$status" -eq 0 ]

    run validate-path "${test_file}" "dir"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "not a directory" ]]

    # Any type validation
    run validate-path "${test_file}" "any"
    [ "$status" -eq 0 ]

    run validate-path "${test_dir}" "any"
    [ "$status" -eq 0 ]

    # Invalid type
    run validate-path "${test_file}" "invalid"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "invalid type argument" ]]
}

# Number validation tests
@test "validate-number: accepts valid integers" {
    run validate-number "123" "int"
    [ "$status" -eq 0 ]

    run validate-number "-456" "int"
    [ "$status" -eq 0 ]

    run validate-number "0" "int"
    [ "$status" -eq 0 ]

    run validate-number "+789" "int"
    [ "$status" -eq 0 ]
}

@test "validate-number: rejects invalid integers" {
    run validate-number "" "int"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "number cannot be empty" ]]

    run validate-number "12.34" "int"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "not a valid integer" ]]

    run validate-number "abc" "int"
    [ "$status" -eq 1 ]

    run validate-number "12a" "int"
    [ "$status" -eq 1 ]
}

@test "validate-number: accepts valid floats" {
    run validate-number "123.45" "float"
    [ "$status" -eq 0 ]

    run validate-number "-67.89" "float"
    [ "$status" -eq 0 ]

    run validate-number "0.0" "float"
    [ "$status" -eq 0 ]

    run validate-number "123" "float"
    [ "$status" -eq 0 ]

    run validate-number "+1.23" "float"
    [ "$status" -eq 0 ]
}

@test "validate-number: accepts any number type" {
    run validate-number "123" "any"
    [ "$status" -eq 0 ]

    run validate-number "123.45" "any"
    [ "$status" -eq 0 ]

    run validate-number "-67" "any"
    [ "$status" -eq 0 ]
}

@test "validate-number: validates range" {
    run validate-number "5" "int" "1" "10"
    [ "$status" -eq 0 ]

    run validate-number "0" "int" "1" "10"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "less than minimum" ]]

    run validate-number "11" "int" "1" "10"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "greater than maximum" ]]

    # Float range if bc is available
    if command -v bc >/dev/null 2>&1; then
        run validate-number "5.5" "float" "1.0" "10.0"
        [ "$status" -eq 0 ]

        run validate-number "0.5" "float" "1.0" "10.0"
        [ "$status" -eq 1 ]
    fi
}

@test "is-number/is-int/is-float: silent validation" {
    run is-number "123"
    [ "$status" -eq 0 ]
    [ -z "$output" ]

    run is-int "123"
    [ "$status" -eq 0 ]
    [ -z "$output" ]

    run is-int "123.45"
    [ "$status" -eq 1 ]
    [ -z "$output" ]

    run is-float "123.45"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

# Date validation tests
@test "validate-date: accepts ISO format dates" {
    run validate-date "2023-12-31" "iso"
    [ "$status" -eq 0 ]

    run validate-date "2000-01-01" "iso"
    [ "$status" -eq 0 ]

    run validate-date "1999-12-31" "iso"
    [ "$status" -eq 0 ]
}

@test "validate-date: accepts US format dates" {
    run validate-date "12/31/2023" "us"
    [ "$status" -eq 0 ]

    run validate-date "01-01-2000" "us"
    [ "$status" -eq 0 ]
}

@test "validate-date: accepts EU format dates" {
    run validate-date "31/12/2023" "eu"
    [ "$status" -eq 0 ]

    run validate-date "01-01-2000" "eu"
    [ "$status" -eq 0 ]
}

@test "validate-date: accepts any common format" {
    run validate-date "2023-12-31" "any"
    [ "$status" -eq 0 ]

    run validate-date "12/31/2023" "any"
    [ "$status" -eq 0 ]

    run validate-date "12-10-2023" "any"
    [ "$status" -eq 0 ]
}

@test "validate-date: rejects invalid dates" {
    run validate-date "" "iso"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "date cannot be empty" ]]

    run validate-date "2023-13-01" "iso"
    [ "$status" -eq 1 ]

    run validate-date "not a date" "any"
    [ "$status" -eq 1 ]

    run validate-date "2023/12/31" "iso"
    [ "$status" -eq 1 ]

    run validate-date "invalid" "invalid"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "invalid format argument" ]]
}

@test "is-date: silent validation" {
    run is-date "2023-12-31"
    [ "$status" -eq 0 ]
    [ -z "$output" ]

    run is-date "invalid"
    [ "$status" -eq 1 ]
    [ -z "$output" ]
}