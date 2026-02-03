#!/usr/bin/env bash
# Normalize test output by replacing variable content with placeholders
# Usage: normalize.sh < input > output
# Or:    some_command | normalize.sh > output

sed -E \
  -e 's/[0-9a-f]{7,40}/HASH/g' \
  -e 's|/tmp/commit-tool-staged-backup-[0-9]+\.patch|/tmp/commit-tool-staged-backup-PID.patch|g' \
  -e 's|/tmp/commit-tool-diff-[0-9]+\.txt|/tmp/commit-tool-diff-PID.txt|g' \
  -e 's/\*\*Diff too large for inline display\*\* \([0-9]+ characters\)/**Diff too large for inline display** (NNNNN characters)/'
