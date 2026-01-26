#!/usr/bin/env bash
# run_test.sh <casedir>
# Runs a single test case:
#   1. rm -rf <casedir>/repo/ <casedir>/actual.txt
#   2. <casedir>/gen_repo.sh <casedir>/repo/
#   3. <casedir>/gen_actual.sh <casedir>/actual.txt
#   4. diff <casedir>/expected.txt <casedir>/actual.txt
#   5. return 0 (pass) or 1 (fail)

set -euo pipefail

CASE_DIR="${1:-}"

if [[ -z "$CASE_DIR" ]]; then
  echo "Usage: run_test.sh <casedir>" >&2
  exit 1
fi

# Resolve to absolute path
CASE_DIR="$(cd "$CASE_DIR" && pwd)"
CASE_NAME="$(basename "$CASE_DIR")"

# Validate case directory
if [[ ! -f "${CASE_DIR}/gen_repo.sh" ]]; then
  echo "SKIP: ${CASE_NAME} (no gen_repo.sh)" >&2
  exit 2
fi
if [[ ! -f "${CASE_DIR}/gen_actual.sh" ]]; then
  echo "SKIP: ${CASE_NAME} (no gen_actual.sh)" >&2
  exit 2
fi
if [[ ! -f "${CASE_DIR}/expected.txt" ]]; then
  echo "SKIP: ${CASE_NAME} (no expected.txt)" >&2
  exit 2
fi

# Clean up
rm -rf "${CASE_DIR}/repo" "${CASE_DIR}/actual.txt"

# Generate repo
if ! "${CASE_DIR}/gen_repo.sh" "${CASE_DIR}/repo" 2>/dev/null; then
  echo "FAIL: ${CASE_NAME} (gen_repo.sh failed)" >&2
  exit 1
fi

# Generate actual output
if ! "${CASE_DIR}/gen_actual.sh" "${CASE_DIR}/actual.txt" 2>/dev/null; then
  echo "FAIL: ${CASE_NAME} (gen_actual.sh failed)" >&2
  exit 1
fi

# Compare
if diff -q "${CASE_DIR}/expected.txt" "${CASE_DIR}/actual.txt" >/dev/null 2>&1; then
  echo "PASS: ${CASE_NAME}"
  exit 0
else
  echo "FAIL: ${CASE_NAME}"
  echo "--- diff ---"
  diff "${CASE_DIR}/expected.txt" "${CASE_DIR}/actual.txt" | head -30
  exit 1
fi
