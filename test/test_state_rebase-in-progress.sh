#!/usr/bin/env bash
# Test: rebase conflict in progress
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"${SCRIPT_DIR}/run_test.sh" rebase-in-progress --staged no-checks
