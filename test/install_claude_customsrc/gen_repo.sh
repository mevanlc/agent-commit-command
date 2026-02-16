#!/usr/bin/env bash
set -euo pipefail
TARGET="${1:-./repo}"
mkdir -p "${TARGET}/home"
mkdir -p "${TARGET}/customsrc/commands"
cat > "${TARGET}/customsrc/commands/custom.md" <<'EOF'
---
description: Custom test command
---

Hello
EOF

