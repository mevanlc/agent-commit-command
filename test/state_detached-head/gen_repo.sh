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
echo "second" > second.txt
git add second.txt
git commit -q -m "Second commit"
git checkout -q HEAD~1
