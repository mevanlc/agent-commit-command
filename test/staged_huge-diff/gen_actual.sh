#!/usr/bin/env bash
set -euo pipefail
CASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$(dirname "$CASE_DIR")")"
TARGET="${1:-${CASE_DIR}/actual.txt}"
source "${PROJECT_DIR}/test/setup_config.sh"
cd "${CASE_DIR}/repo"
"${PROJECT_DIR}/commit-tool/commit-tool.sh" git --staged 2>&1 | "${PROJECT_DIR}/test/normalize.sh" > "$TARGET"
