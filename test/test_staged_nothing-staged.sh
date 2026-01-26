#!/usr/bin/env bash
# Test: --staged mode with nothing staged (should show STOP message)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"${SCRIPT_DIR}/run_test.sh" nothing-staged --staged no-checks
