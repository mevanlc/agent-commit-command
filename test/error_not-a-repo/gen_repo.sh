#!/usr/bin/env bash
set -euo pipefail
TARGET="${1:-./repo}"
mkdir -p "$TARGET"
echo "not a repo" > "${TARGET}/file.txt"
