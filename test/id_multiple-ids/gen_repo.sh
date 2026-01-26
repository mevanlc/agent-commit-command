#!/usr/bin/env bash
set -euo pipefail
TARGET="${1:-./repo}"
mkdir -p "$TARGET" && cd "$TARGET"
git init -q
git config user.name "Alice"
git config user.email "alice@example.com"
echo "alice" > file.txt
git add file.txt
git commit -q -m "Alice commit"
git config user.name "Bob"
git config user.email "bob@example.com"
echo "bob" >> file.txt
git add file.txt
git commit -q -m "Bob commit"
# Set back to Alice - multiple IDs have now committed
git config user.name "Alice"
git config user.email "alice@example.com"
