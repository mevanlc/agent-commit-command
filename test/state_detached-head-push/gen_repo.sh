#!/usr/bin/env bash
# Detached HEAD with staged changes, exercised under a `-push` mode.
# This is the combination the "push not attempted" outcome line exists for:
# the commit can land, but the Push After Commit section says not to push.
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

# Stage a change so the run reaches the commit instructions rather than
# stopping at "Nothing Staged"
echo "detached work" >> file.txt
git add file.txt
