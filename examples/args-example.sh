#!/usr/bin/env bash
# Example script demonstrating args.sh library usage

# Source the library
source "$(dirname "$0")/../include.sh"
include-source 'args.sh'

# Initialize the argument parser
args-init "Example script demonstrating args.sh library usage"

# Add flags (boolean arguments)
args-add-flag "-v/--verbose" "Enable verbose output"
args-add-flag "-d/--debug" "Enable debug mode"
args-add-flag "--dry-run" "Perform a dry run without making changes"
args-add-flag "--color" "Enable colored output" "true"  # Default to true

# Add options (arguments that take values)
args-add-option "-f/--file" "FILE" "Input file to process"
args-add-option "-o/--output" "DIR" "Output directory" "/tmp"  # With default
args-add-option "-n/--number" "NUM" "Number of iterations" "10"
args-add-option "--format" "FMT" "Output format (json|xml|text)" "text"

# Add positional arguments
args-add-positional "source" "Source directory" "required"
args-add-positional "destination" "Destination directory (optional)"

# Parse command line arguments
if ! args-parse "$@"; then
    exit 1
fi

# Check if help was requested (args-parse returns 2 for help)
if [[ $? -eq 2 ]]; then
    exit 0
fi

# Validate required arguments
if ! args-validate; then
    echo "Error: Missing required arguments" >&2
    echo "Try '$0 --help' for more information." >&2
    exit 1
fi

# Access parsed values using various methods

# Method 1: Direct array access
echo "=== Direct array access ==="
echo "Verbose flag: ${ARGS_FLAGS[verbose]}"
echo "Debug flag: ${ARGS_FLAGS[debug]}"
echo "Dry run flag: ${ARGS_FLAGS[dry_run]}"  # Note: dash converted to underscore
echo "Color flag: ${ARGS_FLAGS[color]}"
echo
echo "File option: ${ARGS_OPTIONS[file]:-<not set>}"
echo "Output dir: ${ARGS_OPTIONS[output]}"
echo "Number: ${ARGS_OPTIONS[number]}"
echo "Format: ${ARGS_OPTIONS[format]}"
echo
echo "Source: ${ARGS_POSITIONAL[0]}"
echo "Destination: ${ARGS_POSITIONAL[1]:-<not set>}"
echo

# Method 2: Using helper functions
echo "=== Using helper functions ==="
echo "Verbose: $(args-get-flag verbose)"
echo "Debug: $(args-get-flag debug)"
echo "Dry run: $(args-get-flag dry-run)"  # Can use original dash format
echo

if args-has-option "file"; then
    echo "File specified: $(args-get-option file)"
else
    echo "No file specified"
fi

echo "Output directory: $(args-get-option output || echo "<default>")"
echo

# Method 3: Conditional logic based on arguments
echo "=== Conditional logic ==="

# Check flags
if args-has-flag "verbose"; then
    echo "[VERBOSE] Verbose mode enabled"
fi

if [[ "$(args-get-flag debug)" == "true" ]]; then
    echo "[DEBUG] Debug mode active"
fi

if [[ "$(args-get-flag dry-run)" == "true" ]]; then
    echo "[DRY RUN] No changes will be made"
fi

# Process based on format
case "$(args-get-option format)" in
    json)
        echo "Will output in JSON format"
        ;;
    xml)
        echo "Will output in XML format"
        ;;
    text|*)
        echo "Will output in plain text format"
        ;;
esac

# Work with positional arguments
echo
echo "=== Processing ==="
source_dir="$(args-get-positional 0)"
dest_dir="$(args-get-positional 1 || echo "$source_dir.backup")"

echo "Processing from: $source_dir"
echo "Output to: $dest_dir"

# Demonstrate number validation
num_iterations="$(args-get-option number)"
if [[ ! "$num_iterations" =~ ^[0-9]+$ ]]; then
    echo "Error: --number must be a positive integer" >&2
    exit 1
fi
echo "Will perform $num_iterations iterations"

# Show all remaining/positional arguments
echo
echo "=== All positional arguments ==="
for i in "${!ARGS_POSITIONAL[@]}"; do
    echo "  [$i]: ${ARGS_POSITIONAL[$i]}"
done

# Example of actual script logic
echo
echo "=== Script would do actual work here ==="
if [[ "$(args-get-flag dry-run)" != "true" ]]; then
    echo "(In a real script, processing would happen here)"
else
    echo "(Dry run - no actual processing)"
fi