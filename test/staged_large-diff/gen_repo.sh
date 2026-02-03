#!/usr/bin/env bash
# Generate a repo with staged changes that create a diff > 28000 characters
# This tests the externalized diff file handling in --staged mode
set -euo pipefail
TARGET="${1:-./repo}"
mkdir -p "$TARGET" && cd "$TARGET"
git init -q
git config user.name "Test User"
git config user.email "test@example.com"

# Initial commit
echo "initial" > file.txt
git add file.txt
git commit -q -m "Initial commit"

# Create and stage a large file
for i in $(seq 1 400); do
  echo "This is line $i of a large file used to test the externalized diff handling in commit-tool"
done > large_file.txt
git add large_file.txt
