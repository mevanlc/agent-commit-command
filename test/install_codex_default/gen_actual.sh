#!/usr/bin/env bash
set -euo pipefail
CASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$(dirname "$CASE_DIR")")"
TARGET="${1:-${CASE_DIR}/actual.txt}"

export HOME="${CASE_DIR}/repo/home"
mkdir -p "$HOME"

"${PROJECT_DIR}/install.sh" --codex >/dev/null

# List what was created under .codex (should be symlinks to .md files)
{
  echo "=== .codex ==="
  cd "${HOME}/.codex"
  find . -type l -print | LC_ALL=C sort | while read -r link; do
    target="$(readlink "$link")"
    # Normalize: strip the project dir prefix for stable output
    target="${target#"${PROJECT_DIR}/"}"
    echo "${link} -> ${target}"
  done

  echo "=== .local/share ==="
  if [[ -L "${HOME}/.local/share/agent-commit-command" ]]; then
    target="$(readlink "${HOME}/.local/share/agent-commit-command")"
    rel="${target#"${PROJECT_DIR}"}"
    if [[ -n "$rel" ]]; then
      echo "agent-commit-command -> ${rel}"
    else
      echo "agent-commit-command -> (repo root)"
    fi
  fi

  echo "=== .config ==="
  cd "${HOME}/.config/agent-commit-command"
  find . -type f -print | LC_ALL=C sort
} > "$TARGET"
