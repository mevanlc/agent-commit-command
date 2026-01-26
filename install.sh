#!/usr/bin/env bash
# install.sh - Install commit-tool to ~/.claude/commands
#
# Usage: install.sh [options]
#   --hooks       Also install hook-*.{sh,config} files
#   --upgrade-sh  Overwrite existing .sh files (not .config)
#   --upgrade-md  Overwrite existing .md files (not .config)
#
# Options can be combined.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_COMMANDS="${SCRIPT_DIR}/commands"
DEST_BASE="${HOME}/.claude/commands"
DEST_TOOL="${DEST_BASE}/commit-tool"

# Parse options
INSTALL_HOOKS=0
UPGRADE_SH=0
UPGRADE_MD=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --hooks) INSTALL_HOOKS=1 ;;
    --upgrade-sh) UPGRADE_SH=1 ;;
    --upgrade-md) UPGRADE_MD=1 ;;
    -h|--help)
      echo "Usage: install.sh [--hooks] [--upgrade-sh] [--upgrade-md]"
      echo ""
      echo "Options:"
      echo "  --hooks       Also install hook-*.{sh,config} files"
      echo "  --upgrade-sh  Overwrite existing .sh files (not .config)"
      echo "  --upgrade-md  Overwrite existing .md files (not .config)"
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
  esac
  shift
done

# Create destination directories
mkdir -p "$DEST_BASE"
mkdir -p "$DEST_TOOL"

# Track results
INSTALLED=()
SKIPPED=()

# Copy a file with overwrite control
# Usage: copy_file <src> <dest> <can_overwrite>
copy_file() {
  local src="$1"
  local dest="$2"
  local can_overwrite="$3"

  if [[ -e "$dest" ]]; then
    if [[ "$can_overwrite" == "1" ]]; then
      cp "$src" "$dest"
      INSTALLED+=("$dest (overwritten)")
    else
      SKIPPED+=("$dest (exists)")
    fi
  else
    cp "$src" "$dest"
    INSTALLED+=("$dest")
  fi
}

# Determine overwrite policy for a file
can_overwrite() {
  local file="$1"
  case "$file" in
    *.sh)
      [[ "$UPGRADE_SH" == "1" ]] && echo 1 || echo 0
      ;;
    *.md)
      [[ "$UPGRADE_MD" == "1" ]] && echo 1 || echo 0
      ;;
    *.config)
      echo 0  # Never overwrite config files
      ;;
    *)
      echo 0
      ;;
  esac
}

# Install .md files to commands/
for md in "${SRC_COMMANDS}"/*.md; do
  [[ -f "$md" ]] || continue
  dest="${DEST_BASE}/$(basename "$md")"
  copy_file "$md" "$dest" "$(can_overwrite "$md")"
done

# Install commit-tool.sh and commit-tool.config
copy_file "${SRC_COMMANDS}/commit-tool/commit-tool.sh" "${DEST_TOOL}/commit-tool.sh" "$(can_overwrite "commit-tool.sh")"
copy_file "${SRC_COMMANDS}/commit-tool/commit-tool.config" "${DEST_TOOL}/commit-tool.config" "$(can_overwrite "commit-tool.config")"

# Make .sh files executable
chmod +x "${DEST_TOOL}/commit-tool.sh" 2>/dev/null || true

# Install hooks if requested
if [[ "$INSTALL_HOOKS" == "1" ]]; then
  for hook in "${SRC_COMMANDS}/commit-tool"/hook-*.sh "${SRC_COMMANDS}/commit-tool"/hook-*.config; do
    [[ -f "$hook" ]] || continue
    dest="${DEST_TOOL}/$(basename "$hook")"
    copy_file "$hook" "$dest" "$(can_overwrite "$hook")"
    # Make hook .sh files executable
    if [[ "$hook" == *.sh ]]; then
      chmod +x "$dest" 2>/dev/null || true
    fi
  done
fi

# Report results
echo "Installation complete."
echo ""

if [[ ${#INSTALLED[@]} -gt 0 ]]; then
  echo "Installed:"
  for f in "${INSTALLED[@]}"; do
    echo "  $f"
  done
fi

if [[ ${#SKIPPED[@]} -gt 0 ]]; then
  echo ""
  echo "Skipped (use --upgrade-sh or --upgrade-md to overwrite):"
  for f in "${SKIPPED[@]}"; do
    echo "  $f"
  done
fi
