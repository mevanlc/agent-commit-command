#!/usr/bin/env bash
# Generate a repo with staged changes that create a diff > 8000 lines
# This tests the "DIFF TOO LARGE" handling in --staged mode, which is the one
# compose_diff_* path the other cases never reach.
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

# Create and stage a file with more lines than the inline threshold allows
for i in $(seq 1 9000); do
  echo "line $i"
done > huge_file.txt
git add huge_file.txt
