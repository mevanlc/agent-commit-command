#!/usr/bin/env bash
set -euo pipefail
TARGET="${1:-./repo}"
mkdir -p "$TARGET" && cd "$TARGET"

if ! git init -q -b main >/dev/null 2>&1; then
  git init -q
fi

git config user.name "Test User"
git config user.email "test@example.com"

echo "initial" > file.txt
