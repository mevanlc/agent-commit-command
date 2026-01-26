#!/usr/bin/env bash
# Test: merge conflict in progress
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"${SCRIPT_DIR}/run_test.sh" merge-in-progress --staged no-checks
