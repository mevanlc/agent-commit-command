#!/usr/bin/env bash
set -euo pipefail
TARGET="${1:-./repo}"
mkdir -p "$TARGET" && cd "$TARGET"
git init -q
git config user.name "Test User"
git config user.email "test@example.com"
echo "initial" > file.txt
git add file.txt
git commit -q -m "Initial commit"
# Now change the name but keep the email - this triggers name mismatch warning
git config user.name "Different Name"
