#!/usr/bin/env bash
# Test: detached HEAD state
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"${SCRIPT_DIR}/run_test.sh" detached-head --staged no-checks
