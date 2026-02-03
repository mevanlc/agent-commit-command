#!/usr/bin/env bash
# run_all.sh - Run all test cases
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

PASS=0
FAIL=0
SKIP=0

for case_dir in "${SCRIPT_DIR}"/*/; do
  [[ -d "$case_dir" ]] || continue
  [[ -f "${case_dir}/gen_repo.sh" ]] || continue

  rc=0
  "${SCRIPT_DIR}/run_test.sh" "$case_dir" || rc=$?
  if [[ $rc -eq 0 ]]; then
    PASS=$((PASS + 1))
  elif [[ $rc -eq 2 ]]; then
    SKIP=$((SKIP + 1))
  else
    FAIL=$((FAIL + 1))
  fi
done

echo ""
echo "Results: ${PASS} passed, ${FAIL} failed, ${SKIP} skipped"

[[ $FAIL -eq 0 ]]
