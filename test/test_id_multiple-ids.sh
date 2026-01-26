#!/usr/bin/env bash
# Test: identity warning - multiple configured IDs have commits
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"${SCRIPT_DIR}/run_test.sh" multiple-ids --staged multiple-ids
