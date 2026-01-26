#!/usr/bin/env bash
# regen_expecteds.sh - Regenerate expected.txt for all (or specified) test cases
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# If args provided, only regenerate those cases
if [[ $# -gt 0 ]]; then
  cases=("$@")
else
  cases=("${SCRIPT_DIR}"/*/)
fi

for case_dir in "${cases[@]}"; do
  [[ -d "$case_dir" ]] || continue
  [[ -f "${case_dir}/gen_repo.sh" ]] || continue
  [[ -f "${case_dir}/gen_actual.sh" ]] || continue

  case_name="$(basename "$case_dir")"
  echo "Regenerating: ${case_name}"

  rm -rf "${case_dir}/repo" "${case_dir}/actual.txt"
  "${case_dir}/gen_repo.sh" "${case_dir}/repo" 2>/dev/null || true
  "${case_dir}/gen_actual.sh" "${case_dir}/expected.txt" 2>/dev/null || true
done

echo "Done."
