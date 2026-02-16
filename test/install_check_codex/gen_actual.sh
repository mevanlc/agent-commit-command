#!/usr/bin/env bash
set -euo pipefail

CASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$(dirname "$CASE_DIR")")"
TARGET="${1:-${CASE_DIR}/actual.txt}"

export HOME="${CASE_DIR}/repo/home"

"${PROJECT_DIR}/install.sh" --codex --sh-update --md-update --check |
  sed "s|$HOME|/CHECKED/HOME|g" |
  sed $'s/\t/\\\\t/g' > "$TARGET"
