#!/usr/bin/env bash
set -euo pipefail
CASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$(dirname "$CASE_DIR")")"
TARGET="${1:-${CASE_DIR}/actual.txt}"

HOOK_CONFIG="${PROJECT_DIR}/commit-tool/hook-preflight-01-id-check.config"
cat > "$HOOK_CONFIG" << 'CONF'
enforce_one_id_per_repo=0
enforce_name=1
report_named_commits=0
report_email_commits=0
CONF

cd "${CASE_DIR}/repo"
"${PROJECT_DIR}/commit-tool/commit-tool.sh" git --staged 2>&1 | "${PROJECT_DIR}/test/normalize.sh" > "$TARGET"
