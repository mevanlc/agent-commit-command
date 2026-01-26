#!/usr/bin/env bash
# Test: --all mode with only unstaged changes
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"${SCRIPT_DIR}/run_test.sh" only-unstaged --all no-checks
