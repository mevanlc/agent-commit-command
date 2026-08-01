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
git checkout -q -b feature
echo "feature" > file.txt
git add file.txt
git commit -q -m "Feature commit"
git checkout -q main
echo "main" > file.txt
git add file.txt
git commit -q -m "Main commit"
git merge feature --no-commit 2>/dev/null || true
