#!/usr/bin/env bash
# Tests: install.sh --claude (basic claude install)
set -euo pipefail
CASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$(dirname "$CASE_DIR")")"
TARGET="${1:-${CASE_DIR}/actual.txt}"

export HOME="${CASE_DIR}/repo/home"
mkdir -p "$HOME"

"${PROJECT_DIR}/install.sh" --claude >/dev/null

{
  echo "=== .claude ==="
  cd "${HOME}/.claude"
  find . -type l -print | LC_ALL=C sort | while read -r link; do
    target="$(readlink "$link")"
    target="${target#"${PROJECT_DIR}/"}"
    echo "${link} -> ${target}"
  done

  echo "=== .config ==="
  cd "${HOME}/.config/agent-commit-skill"
  find . -type f -print | LC_ALL=C sort
} > "$TARGET"
