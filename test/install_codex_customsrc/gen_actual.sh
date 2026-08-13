#!/usr/bin/env bash
# Tests: install.sh --codex --hooks (hooks enabled)
set -euo pipefail
CASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$(dirname "$CASE_DIR")")"
TARGET="${1:-${CASE_DIR}/actual.txt}"

export HOME="${CASE_DIR}/repo/home"
mkdir -p "$HOME"

"${PROJECT_DIR}/install.sh" --codex --hooks >/dev/null

{
  echo "=== .codex ==="
  cd "${HOME}/.codex"
  find . -type l -print | LC_ALL=C sort | while read -r link; do
    target="$(readlink "$link")"
    target="${target#"${PROJECT_DIR}/"}"
    echo "${link} -> ${target}"
  done

  echo "=== .config ==="
  cd "${HOME}/.config/agent-commit-skill"
  # Show files and symlinks separately
  find . -type f -print | LC_ALL=C sort
  find . -type l -print | LC_ALL=C sort | while read -r link; do
    target="$(readlink "$link")"
    target="${target#"${PROJECT_DIR}/"}"
    echo "LINK: ${link} -> ${target}"
  done
} > "$TARGET"
