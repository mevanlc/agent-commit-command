#!/usr/bin/env bash
# Test: identity warning - name mismatch (same email, different name)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"${SCRIPT_DIR}/run_test.sh" name-mismatch --staged name-mismatch
