#!/usr/bin/env bash
# Test: --all mode with clean working directory (should show "no changes")
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"${SCRIPT_DIR}/run_test.sh" clean-workdir --all no-checks
