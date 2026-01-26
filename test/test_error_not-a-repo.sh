#!/usr/bin/env bash
# Test: not a git repository
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"${SCRIPT_DIR}/run_test.sh" not-a-repo --staged no-checks
