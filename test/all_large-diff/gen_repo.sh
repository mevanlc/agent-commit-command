#!/usr/bin/env bash
# Generate a repo with changes that create a diff > 28000 characters
# This tests the externalized diff file handling
set -euo pipefail
TARGET="${1:-./repo}"
mkdir -p "$TARGET" && cd "$TARGET"
git init -q
git config user.name "Test User"
git config user.email "test@example.com"

# Initial commit with a small file
echo "initial" > file.txt
git add file.txt
git commit -q -m "Initial commit"

# Create a large file that will produce a diff > 28000 chars
# Each line is ~80 chars, so ~400 lines should give us ~32000 chars
for i in $(seq 1 400); do
  echo "This is line $i of a large file used to test the externalized diff handling in commit-tool"
done > large_file.txt
