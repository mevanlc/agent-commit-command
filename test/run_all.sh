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

  if "${SCRIPT_DIR}/run_test.sh" "$case_dir"; then
    ((PASS++))
  else
    rc=$?
    if [[ $rc -eq 2 ]]; then
      ((SKIP++))
    else
      ((FAIL++))
    fi
  fi
done

echo ""
echo "Results: ${PASS} passed, ${FAIL} failed, ${SKIP} skipped"

[[ $FAIL -eq 0 ]]
