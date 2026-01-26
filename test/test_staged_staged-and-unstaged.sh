#!/usr/bin/env bash
# Test: --staged mode with both staged and unstaged (should only show staged)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"${SCRIPT_DIR}/run_test.sh" staged-and-unstaged --staged no-checks
