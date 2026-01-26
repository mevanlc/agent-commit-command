#!/usr/bin/env bash
# check_expecteds.sh - Compare test output against expected output
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXP_DIR="${SCRIPT_DIR}/exp"

PASS=0
FAIL=0
SKIP=0

for test_script in "${SCRIPT_DIR}"/test_*.sh; do
  test_name=$(basename "$test_script" .sh)
  exp_file="${EXP_DIR}/${test_name}.exp"

  if [[ ! -f "$exp_file" ]]; then
    echo "SKIP: ${test_name} (no expected file)"
    ((SKIP++))
    continue
  fi

  chmod +x "$test_script"
  actual=$("$test_script" 2>&1) || true
  expected=$(cat "$exp_file")

  if [[ "$actual" == "$expected" ]]; then
    echo "PASS: ${test_name}"
    ((PASS++))
  else
    echo "FAIL: ${test_name}"
    echo "  --- Expected ---"
    echo "$expected" | head -10 | sed 's/^/  /'
    echo "  --- Actual ---"
    echo "$actual" | head -10 | sed 's/^/  /'
    echo "  --- Diff ---"
    diff <(echo "$expected") <(echo "$actual") | head -20 | sed 's/^/  /' || true
    ((FAIL++))
  fi
done

echo ""
echo "Results: ${PASS} passed, ${FAIL} failed, ${SKIP} skipped"

if [[ $FAIL -gt 0 ]]; then
  exit 1
fi
