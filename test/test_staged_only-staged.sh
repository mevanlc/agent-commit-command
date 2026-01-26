#!/usr/bin/env bash
# Test: --staged mode with only staged changes
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"${SCRIPT_DIR}/run_test.sh" only-staged --staged no-checks
