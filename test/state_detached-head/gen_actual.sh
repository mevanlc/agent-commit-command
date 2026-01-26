#!/usr/bin/env bash
set -euo pipefail
CASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$(dirname "$CASE_DIR")")"
TARGET="${1:-${CASE_DIR}/actual.txt}"
cd "${CASE_DIR}/repo"
"${PROJECT_DIR}/commands/commit-tool/commit-tool.sh" git --staged 2>&1 | "${PROJECT_DIR}/test/normalize.sh" > "$TARGET"
