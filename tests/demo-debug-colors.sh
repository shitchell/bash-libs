#!/usr/bin/env bash

# Demonstration of debug.sh with colors.sh integration

# Source the libraries
source "$(dirname "$0")/../include.sh"
include-source 'debug.sh'

echo "=== Debug.sh with Colors.sh Integration Demo ==="
echo

echo "1. Basic debug messages with different levels:"
DEBUG=30
debug 1 "This is a level 1 debug message"
debug 10 "This is a level 10 debug message"
debug 20 "This is a level 20 debug message"
debug 30 "This is a level 30 debug message"
debug 40 "This won't show (level too high)"
echo

echo "2. Debug messages with log level labels (colored):"
DEBUG=40
debug error "ERROR: This is an error message (red)"
debug warn "WARNING: This is a warning message (yellow)"
debug info "INFO: This is an info message (blue)"
debug success "SUCCESS: This is a success message (green)"
debug debug "DEBUG: This is a debug message (gray/dim)"
echo

echo "3. Debug with colors disabled:"
DEBUG_COLOR=false
DEBUG=1
debug error "ERROR: This error has no color"
debug warn "WARNING: This warning has no color"
echo

echo "4. Debug variables demonstration:"
DEBUG_COLOR=""  # Re-enable colors
export TEST_VAR_1="Hello World"
export TEST_VAR_2=42
local_array=(one two three)
debug-vars TEST_VAR_1 TEST_VAR_2 local_array
echo

echo "5. Debug with multiple lines:"
DEBUG=1
debug "Line 1" "Line 2" "Line 3"
echo

echo "6. Debug log file demonstration:"
DEBUG_LOG="/tmp/debug-demo.log"
unset DEBUG
debug "This goes to the log file"
debug error "This error also goes to the log file"
echo "Contents of debug log:"
cat "$DEBUG_LOG"
rm -f "$DEBUG_LOG"
echo

echo "7. Print-escaped demonstration:"
echo -n "Original: "
echo $'Hello\tWorld\nNew Line'
echo -n "Escaped: "
print-escaped $'Hello\tWorld\nNew Line'
echo
echo

echo "=== Demo Complete ==="