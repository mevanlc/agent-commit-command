#!/usr/bin/env bash
# Test: --staged mode with clean working directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"${SCRIPT_DIR}/run_test.sh" clean-workdir --staged no-checks
