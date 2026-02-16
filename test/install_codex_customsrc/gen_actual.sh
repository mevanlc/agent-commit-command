#!/usr/bin/env bash
set -euo pipefail
CASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$(dirname "$CASE_DIR")")"
TARGET="${1:-${CASE_DIR}/actual.txt}"

export HOME="${CASE_DIR}/repo/home"
mkdir -p "$HOME"

"${PROJECT_DIR}/install.sh" --codex "${CASE_DIR}/repo/customsrc" >/dev/null

cd "${HOME}/.codex"
find . -type f -print | LC_ALL=C sort > "$TARGET"

