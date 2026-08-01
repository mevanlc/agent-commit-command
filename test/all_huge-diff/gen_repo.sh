#!/usr/bin/env bash
# Generate a repo with unstaged changes that create a diff > 8000 lines once
# staged. This tests the "DIFF TOO LARGE" handling in --all mode; the file is
# left unstaged so --all's own `git add -A` is what produces the large diff.
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

# Create a file with more lines than the inline threshold allows
for i in $(seq 1 9000); do
  echo "line $i"
done > huge_file.txt
