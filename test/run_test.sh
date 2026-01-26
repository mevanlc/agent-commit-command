#!/usr/bin/env bash
# run_test.sh - Run commit-tool.sh against a test repo with optional config override
# Usage: run_test.sh <repo_name> <mode> [config_name]
#   repo_name: name of repo in test/repos/
#   mode: --staged, --all, or --ask
#   config_name: optional config from test/configs/ (without .config extension)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
COMMANDS_DIR="${PROJECT_DIR}/commands"
REPOS_DIR="${SCRIPT_DIR}/repos"
CONFIGS_DIR="${SCRIPT_DIR}/configs"

REPO_NAME="${1:-}"
MODE="${2:-}"
CONFIG_NAME="${3:-}"

if [[ -z "$REPO_NAME" || -z "$MODE" ]]; then
  echo "Usage: run_test.sh <repo_name> <mode> [config_name]" >&2
  exit 1
fi

REPO_DIR="${REPOS_DIR}/${REPO_NAME}"
if [[ ! -d "$REPO_DIR" ]]; then
  echo "Error: repo '${REPO_NAME}' not found in ${REPOS_DIR}" >&2
  exit 1
fi

# If config override specified, copy it into place
if [[ -n "$CONFIG_NAME" ]]; then
  CONFIG_SRC="${CONFIGS_DIR}/${CONFIG_NAME}.config"
  if [[ ! -f "$CONFIG_SRC" ]]; then
    echo "Error: config '${CONFIG_NAME}' not found in ${CONFIGS_DIR}" >&2
    exit 1
  fi
  cp "$CONFIG_SRC" "${COMMANDS_DIR}/commit-tool/hook-preflight/01-id-check.config"
fi

# Run commit-tool.sh from the test repo directory
cd "$REPO_DIR"
"${COMMANDS_DIR}/commit-tool.sh" git "$MODE" 2>&1

# Normalize output: strip variable content like commit hashes, dates
# (This helps with expected output comparison)
