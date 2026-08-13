#!/usr/bin/env bash
# Tests: install.sh --dotagents --check (dry run)
set -euo pipefail
CASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$(dirname "$CASE_DIR")")"
TARGET="${1:-${CASE_DIR}/actual.txt}"

export HOME="${CASE_DIR}/repo/home"
mkdir -p "$HOME"

"${PROJECT_DIR}/install.sh" --dotagents --check |
  sed "s|${HOME}|/HOME|g" |
  sed "s|${PROJECT_DIR}|/REPO|g" > "$TARGET"
