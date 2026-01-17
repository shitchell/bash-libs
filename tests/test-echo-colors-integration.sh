#!/usr/bin/env bash
# Test script to demonstrate echo.sh and colors.sh integration

# Get the directory of this script
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(cd "$TEST_DIR/.." && pwd)"

# Source include.sh first
source "$LIB_DIR/include.sh"

# Source the libraries
include-source 'echo.sh'
include-source 'colors.sh'

echo "=== Testing echo.sh and colors.sh Integration ==="
echo

echo "1. Testing echo-formatted with various colors:"
echo-formatted -r "This is red text"
echo-formatted -g "This is green text"
echo-formatted -b "This is blue text"
echo-formatted -B "This is bold text"
echo-formatted -U "This is underlined text"
echo

echo "2. Testing echo-run:"
echo-run "echo 'Hello from echo-run'"
echo

echo "3. Testing other echo functions:"
echo-comment "This is a comment"
echo-command "git status"
echo-warning "This is a warning"
echo-success "This is a success message"
echo

echo "4. Testing with ECHO_FORMATTED environment variable:"
ECHO_FORMATTED=never echo-formatted -r "This should not be colored"
ECHO_FORMATTED=always echo-formatted -g "This should always be colored" | cat
echo

echo "5. Testing print-header:"
print-header --border "Bordered Header"
print-header --markdown --level 2 "Markdown Header Level 2"
print-header --underline "Underlined Header"
echo

echo "6. Demonstrating color variables are available:"
echo "Direct color usage: ${C_CYAN}Cyan text${S_RESET}"
echo "Bold and color: ${S_BOLD}${C_MAGENTA}Bold magenta${S_RESET}"
echo

echo "=== Integration Test Complete ==="