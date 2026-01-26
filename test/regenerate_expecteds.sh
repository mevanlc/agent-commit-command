#!/usr/bin/env bash
# regenerate_expecteds.sh - Regenerate expected output files from test scripts
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXP_DIR="${SCRIPT_DIR}/exp"

mkdir -p "$EXP_DIR"

# Find all test scripts and regenerate their expected output
for test_script in "${SCRIPT_DIR}"/test_*.sh; do
  test_name=$(basename "$test_script" .sh)
  exp_file="${EXP_DIR}/${test_name}.exp"

  echo "Regenerating: ${test_name}"
  chmod +x "$test_script"
  "$test_script" > "$exp_file" 2>&1 || true
done

echo ""
echo "Expected outputs regenerated in ${EXP_DIR}"
