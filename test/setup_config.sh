#!/usr/bin/env bash
# setup_config.sh - Set up AGENT_COMMIT_CONFIG_DIR for test isolation
#
# Source this from gen_actual.sh after setting CASE_DIR and PROJECT_DIR.
# Creates a test-local config dir with the default commit-tool.config.

export AGENT_COMMIT_CONFIG_DIR="${CASE_DIR}/config"
rm -rf "$AGENT_COMMIT_CONFIG_DIR"
mkdir -p "$AGENT_COMMIT_CONFIG_DIR"
cp "${PROJECT_DIR}/defaults/commit-tool.config" "$AGENT_COMMIT_CONFIG_DIR/"
