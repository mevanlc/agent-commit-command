#!/usr/bin/env bash
# install.sh - Install slash commands + commit-tool
#
# Usage:
#   ./install.sh --codex [options]
#   ./install.sh --claude [options]
#   ./install.sh <srcdir> <dstdir> [options]
#
# Where:
#   srcdir: repo subdir containing ./commands (e.g. ./codex or ./claude)
#   dstdir: base config dir (e.g. ~/.codex/ or ~/.claude/)
#
# Options:
#   --hooks      Also install hook-*.{sh,config} files
#   --sh-update  Overwrite existing .sh files (not .config)
#   --md-update  Overwrite existing .md files (not .config)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMMIT_TOOL_SRC="${SCRIPT_DIR}/commit-tool"

INSTALL_HOOKS=0
UPGRADE_SH=0
UPGRADE_MD=0
MODE=""
POSITIONAL=()

usage() {
  cat <<'EOF'
Usage:
  ./install.sh --codex [--hooks] [--sh-update] [--md-update] [srcdir]
  ./install.sh --claude [--hooks] [--sh-update] [--md-update] [srcdir]
  ./install.sh <srcdir> <dstdir> [--hooks] [--sh-update] [--md-update]

Examples:
  ./install.sh --codex --sh-update --md-update
  ./install.sh --claude --hooks
  ./install.sh --codex ./codex --sh-update --md-update
  ./install.sh ./codex ~/.codex/ --sh-update --md-update
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --codex) MODE="codex"; shift ;;
    --claude) MODE="claude"; shift ;;
    --hooks) INSTALL_HOOKS=1; shift ;;
    --sh-update) UPGRADE_SH=1; shift ;;
    --md-update) UPGRADE_MD=1; shift ;;
    -h|--help) usage; exit 0 ;;
    --) shift; POSITIONAL+=("$@"); break ;;
    -*)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
    *)
      POSITIONAL+=("$1")
      shift
      ;;
  esac
done

if [[ -n "$MODE" && ${#POSITIONAL[@]} -gt 1 ]]; then
  echo "Error: --${MODE} mode optionally takes [srcdir] (no <dstdir>)" >&2
  usage >&2
  exit 1
fi

SRCDIR=""
DSTDIR=""
if [[ "$MODE" == "codex" ]]; then
  if [[ ${#POSITIONAL[@]} -eq 1 ]]; then
    SRCDIR="${POSITIONAL[0]}"
  else
    SRCDIR="${SCRIPT_DIR}/codex"
  fi
  DSTDIR="${HOME}/.codex"
elif [[ "$MODE" == "claude" ]]; then
  if [[ ${#POSITIONAL[@]} -eq 1 ]]; then
    SRCDIR="${POSITIONAL[0]}"
  else
    SRCDIR="${SCRIPT_DIR}/claude"
  fi
  DSTDIR="${HOME}/.claude"
else
  if [[ ${#POSITIONAL[@]} -ne 2 ]]; then
    echo "Error: expected <srcdir> <dstdir> or --codex/--claude" >&2
    usage >&2
    exit 1
  fi
  SRCDIR="${POSITIONAL[0]}"
  DSTDIR="${POSITIONAL[1]}"
fi

# Expand leading ~ if present (e.g. when quoted).
SRCDIR="${SRCDIR/#\~/$HOME}"
DSTDIR="${DSTDIR/#\~/$HOME}"

SRC_COMMANDS="${SRCDIR%/}/commands"
DEST_ROOT="${DSTDIR%/}"
DEST_SUBDIR="commands"
# Codex stores slash commands in ~/.codex/prompts/.
# When installing to Codex, put both the .md prompts and commit-tool under prompts/.
if [[ "$MODE" == "codex" || "$(basename "${DEST_ROOT}")" == ".codex" || "$(basename "${SRCDIR%/}")" == "codex" ]]; then
  DEST_SUBDIR="prompts"
fi
DEST_COMMANDS="${DEST_ROOT}/${DEST_SUBDIR}"
DEST_TOOL="${DEST_COMMANDS}/commit-tool"

if [[ ! -d "$SRC_COMMANDS" ]]; then
  echo "Missing expected source directory: $SRC_COMMANDS" >&2
  exit 1
fi
if [[ ! -f "${COMMIT_TOOL_SRC}/commit-tool.sh" ]]; then
  echo "Missing expected file: ${COMMIT_TOOL_SRC}/commit-tool.sh" >&2
  exit 1
fi
if [[ ! -f "${COMMIT_TOOL_SRC}/commit-tool.config" ]]; then
  echo "Missing expected file: ${COMMIT_TOOL_SRC}/commit-tool.config" >&2
  exit 1
fi

mkdir -p "$DEST_COMMANDS"
mkdir -p "$DEST_TOOL"

INSTALLED=()
SKIPPED=()

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

can_overwrite() {
  local file="$1"
  case "$file" in
    *.sh) [[ "$UPGRADE_SH" == "1" ]] && echo 1 || echo 0 ;;
    *.md) [[ "$UPGRADE_MD" == "1" ]] && echo 1 || echo 0 ;;
    *.config) echo 0 ;; # Never overwrite config files
    *) echo 0 ;;
  esac
}

for md in "${SRC_COMMANDS}"/*.md; do
  [[ -f "$md" ]] || continue
  dest="${DEST_COMMANDS}/$(basename "$md")"
  copy_file "$md" "$dest" "$(can_overwrite "$md")"
done

copy_file "${COMMIT_TOOL_SRC}/commit-tool.sh" "${DEST_TOOL}/commit-tool.sh" "$(can_overwrite "commit-tool.sh")"
copy_file "${COMMIT_TOOL_SRC}/commit-tool.config" "${DEST_TOOL}/commit-tool.config" "$(can_overwrite "commit-tool.config")"

chmod +x "${DEST_TOOL}/commit-tool.sh" 2>/dev/null || true

if [[ "$INSTALL_HOOKS" == "1" ]]; then
  for hook in "${COMMIT_TOOL_SRC}"/hook-*.sh "${COMMIT_TOOL_SRC}"/hook-*.config; do
    [[ -f "$hook" ]] || continue
    dest="${DEST_TOOL}/$(basename "$hook")"
    copy_file "$hook" "$dest" "$(can_overwrite "$hook")"
    [[ "$hook" == *.sh ]] && chmod +x "$dest" 2>/dev/null || true
  done
fi

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
  echo "Skipped (use --sh-update or --md-update to overwrite):"
  for f in "${SKIPPED[@]}"; do
    echo "  $f"
  done
fi
