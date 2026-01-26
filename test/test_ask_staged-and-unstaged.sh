#!/usr/bin/env bash
# Test: --ask mode with both staged and unstaged
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"${SCRIPT_DIR}/run_test.sh" staged-and-unstaged --ask no-checks
