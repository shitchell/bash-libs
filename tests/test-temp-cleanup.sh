#!/usr/bin/env bash
# Test script to verify temp.sh cleanup functionality

set -euo pipefail

# Source the library
source "$(dirname "$(dirname "$0")")/include.sh" --set-libdir
include-source 'temp.sh'

echo "=== Testing temp.sh cleanup functionality ==="
echo

echo "1. Creating temporary files..."
tmp1=$(temp-file)
tmp2=$(temp-file --suffix=.txt)
echo "   Created: $tmp1"
echo "   Created: $tmp2"

echo
echo "2. Creating temporary directories..."
tmpdir1=$(temp-dir)
tmpdir2=$(temp-dir --suffix=.test)
echo "   Created: $tmpdir1"
echo "   Created: $tmpdir2"

echo
echo "3. Adding content to temp resources..."
echo "test content" > "$tmp1"
echo "more content" > "$tmp2"
touch "$tmpdir1/file1.txt"
mkdir "$tmpdir2/subdir"
touch "$tmpdir2/subdir/file2.txt"

echo
echo "4. Current temp resources (${#__TEMP_RESOURCES[@]} total):"
for resource in "${__TEMP_RESOURCES[@]}"; do
    if [[ -d "$resource" ]]; then
        echo "   DIR:  $resource"
    else
        echo "   FILE: $resource"
    fi
done

echo
echo "5. Testing with-temp-dir..."
result=$(with-temp-dir 'echo "Working in temp dir: $PWD"; touch test.txt; ls')
echo "   Result: $result"

echo
echo "6. Verifying resources still exist before exit..."
for resource in "${__TEMP_RESOURCES[@]}"; do
    if [[ -e "$resource" ]]; then
        echo "   ✓ $resource exists"
    else
        echo "   ✗ $resource missing!"
    fi
done

echo
echo "7. Script will exit now. Resources should be cleaned up automatically..."
echo "   (Check that these files/dirs no longer exist after script exits)"

# List the resources one more time for manual verification
echo
echo "Resources to be cleaned up on exit:"
for resource in "${__TEMP_RESOURCES[@]}"; do
    echo "   $resource"
done