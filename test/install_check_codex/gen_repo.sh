#!/usr/bin/env bash
set -euo pipefail

TARGET="${1:-./repo}"
mkdir -p "$TARGET" && cd "$TARGET"

CASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$(dirname "$CASE_DIR")")"

HOME_DIR="${TARGET}/home"
DEST_ROOT="${HOME_DIR}/.codex"
DEST_PROMPTS="${DEST_ROOT}/prompts"
DEST_TOOL="${DEST_PROMPTS}/commit-tool"

mkdir -p "$DEST_TOOL"

# Make one file identical, one missing, and one different.
cp "${PROJECT_DIR}/codex/commands/commit.md" "${DEST_PROMPTS}/commit.md"
cp "${PROJECT_DIR}/commit-tool/commit-tool.config" "${DEST_TOOL}/commit-tool.config"
printf '%s\n' '# different version' > "${DEST_TOOL}/commit-tool.sh"

