#!/usr/bin/env bash
# Test: malformed/corrupted git repository
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"${SCRIPT_DIR}/run_test.sh" malformed-repo --staged no-checks
