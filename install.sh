#!/usr/bin/env bash
# install.sh - Install agent-commit-skill
#
# Installs shared code to ~/.local/share/agent-commit-skill/ (or creates
# a symlink there pointing to this repo), seeds default configs to
# ~/.config/agent-commit-skill/, and symlinks Codex skills / Claude commands
# into the appropriate CLI directories.
#
# Usage:
#   ./install.sh [--codex] [--claude] [--hooks] [--check]
#
# At least one of --codex or --claude is required (both may be given).
#
# Options:
#   --codex    Symlink Codex skill directories into ~/.codex/skills/
#   --claude   Symlink Claude slash-command .md files into ~/.claude/commands/
#   --hooks    Also set up hooks in the config directory
#   --check    Dry-run: show what would be installed without making changes

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

CODE_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/agent-commit-skill"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/agent-commit-skill"

INSTALL_CODEX=0
INSTALL_CLAUDE=0
INSTALL_HOOKS=0
CHECK_ONLY=0

usage() {
  cat <<'EOF'
Usage:
  ./install.sh --codex [--hooks] [--check]
  ./install.sh --claude [--hooks] [--check]
  ./install.sh --codex --claude [--hooks] [--check]

Options:
  --codex    Symlink Codex skill directories into ~/.codex/skills/
  --claude   Symlink Claude slash-command .md files into ~/.claude/commands/
  --hooks    Also set up preflight hooks in the config directory
  --check    Dry-run: show what would happen without making changes

Paths:
  Code:   ~/.local/share/agent-commit-skill/  (symlink to repo)
  Config: ~/.config/agent-commit-skill/        (seeded defaults)

Examples:
  ./install.sh --codex --claude --hooks
  ./install.sh --claude --check
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --codex) INSTALL_CODEX=1; shift ;;
    --claude) INSTALL_CLAUDE=1; shift ;;
    --hooks) INSTALL_HOOKS=1; shift ;;
    --check) CHECK_ONLY=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ "$INSTALL_CODEX" == "0" && "$INSTALL_CLAUDE" == "0" ]]; then
  echo "Error: at least one of --codex or --claude is required" >&2
  usage >&2
  exit 1
fi

# === VALIDATION ===

if [[ ! -f "${SCRIPT_DIR}/commit-tool/commit-tool.sh" ]]; then
  echo "Error: missing commit-tool/commit-tool.sh in repo" >&2
  exit 1
fi

# === HELPERS ===

ACTIONS=()

log_action() {
  local action="$1" target="$2" detail="${3:-}"
  if [[ -n "$detail" ]]; then
    ACTIONS+=("${action}  ${target}  (${detail})")
  else
    ACTIONS+=("${action}  ${target}")
  fi
}

ensure_symlink() {
  local link_path="$1" target="$2"

  if [[ -L "$link_path" ]]; then
    local current
    current="$(readlink "$link_path")"
    if [[ "$current" == "$target" ]]; then
      log_action "OK" "$link_path" "symlink correct"
      return 0
    fi
    if [[ "$CHECK_ONLY" == "1" ]]; then
      log_action "UPDATE" "$link_path" "symlink -> $target"
      return 0
    fi
    rm "$link_path"
    ln -s "$target" "$link_path"
    log_action "UPDATE" "$link_path" "symlink -> $target"
  elif [[ -e "$link_path" ]]; then
    log_action "SKIP" "$link_path" "exists as regular file; remove manually to switch to symlink"
  else
    if [[ "$CHECK_ONLY" == "1" ]]; then
      log_action "CREATE" "$link_path" "symlink -> $target"
      return 0
    fi
    ln -s "$target" "$link_path"
    log_action "CREATE" "$link_path" "symlink -> $target"
  fi
}

seed_config() {
  local src="$1" dest="$2"

  if [[ -e "$dest" ]]; then
    if cmp -s "$src" "$dest"; then
      log_action "OK" "$dest" "config unchanged"
    else
      log_action "SKIP" "$dest" "config exists, not overwriting"
    fi
    return 0
  fi

  if [[ "$CHECK_ONLY" == "1" ]]; then
    log_action "SEED" "$dest" "from $src"
    return 0
  fi

  cp "$src" "$dest"
  log_action "SEED" "$dest" "default config"
}

# === CODE_DIR: ensure ~/.local/share/agent-commit-skill points to this repo ===

SCRIPT_REAL="$(cd "$SCRIPT_DIR" && pwd -P)"
CODE_REAL=""
if [[ -e "$CODE_DIR" ]]; then
  CODE_REAL="$(cd "$CODE_DIR" && pwd -P 2>/dev/null || true)"
fi

if [[ "$SCRIPT_REAL" == "$CODE_REAL" ]]; then
  log_action "OK" "$CODE_DIR" "already points to repo"
elif [[ -L "$CODE_DIR" ]]; then
  # Symlink exists but points elsewhere
  if [[ "$CHECK_ONLY" == "1" ]]; then
    log_action "UPDATE" "$CODE_DIR" "symlink -> $SCRIPT_DIR"
  else
    rm "$CODE_DIR"
    ln -s "$SCRIPT_DIR" "$CODE_DIR"
    log_action "UPDATE" "$CODE_DIR" "symlink -> $SCRIPT_DIR"
  fi
elif [[ -e "$CODE_DIR" ]]; then
  echo "Error: $CODE_DIR exists but is not this repo and not a symlink." >&2
  echo "Remove it manually or clone this repo directly to $CODE_DIR" >&2
  exit 1
else
  if [[ "$CHECK_ONLY" == "1" ]]; then
    log_action "CREATE" "$CODE_DIR" "symlink -> $SCRIPT_DIR"
  else
    mkdir -p "$(dirname "$CODE_DIR")"
    ln -s "$SCRIPT_DIR" "$CODE_DIR"
    log_action "CREATE" "$CODE_DIR" "symlink -> $SCRIPT_DIR"
  fi
fi

# === CONFIG_DIR: seed default configs ===

if [[ "$CHECK_ONLY" == "0" ]]; then
  mkdir -p "$CONFIG_DIR"
fi

seed_config "${SCRIPT_DIR}/defaults/commit-tool.config" "${CONFIG_DIR}/commit-tool.config"

# === HOOKS ===

if [[ "$INSTALL_HOOKS" == "1" ]]; then
  if [[ "$CHECK_ONLY" == "0" ]]; then
    mkdir -p "${CONFIG_DIR}/hooks"
  fi

  # Symlink hook scripts from hooks-available/ into config hooks/
  for hook_sh in "${SCRIPT_DIR}/commit-tool/hooks-available"/hook-*.sh; do
    [[ -f "$hook_sh" ]] || continue
    local_name="$(basename "$hook_sh")"
    ensure_symlink "${CONFIG_DIR}/hooks/${local_name}" "$hook_sh"

    # Seed default hook config if available
    config_name="${local_name%.sh}.config"
    if [[ -f "${SCRIPT_DIR}/defaults/hooks/${config_name}" ]]; then
      seed_config "${SCRIPT_DIR}/defaults/hooks/${config_name}" "${CONFIG_DIR}/hooks/${config_name}"
    fi
  done
fi

# === CODEX SKILL SYMLINKS ===

if [[ "$INSTALL_CODEX" == "1" ]]; then
  CODEX_DIR="${HOME}/.codex/skills"
  if [[ "$CHECK_ONLY" == "0" ]]; then
    mkdir -p "$CODEX_DIR"
  fi

  for skill_dir in "${SCRIPT_DIR}/codex/skills"/*; do
    [[ -d "$skill_dir" ]] || continue
    ensure_symlink "${CODEX_DIR}/$(basename "$skill_dir")" "$skill_dir"
  done
fi

# === CLAUDE .md SYMLINKS ===

if [[ "$INSTALL_CLAUDE" == "1" ]]; then
  CLAUDE_DIR="${HOME}/.claude/commands"
  if [[ "$CHECK_ONLY" == "0" ]]; then
    mkdir -p "$CLAUDE_DIR"
  fi

  for md in "${SCRIPT_DIR}/claude/commands"/*.md; do
    [[ -f "$md" ]] || continue
    ensure_symlink "${CLAUDE_DIR}/$(basename "$md")" "$md"
  done
fi

# === SUMMARY ===

if [[ "$CHECK_ONLY" == "1" ]]; then
  echo "=== Dry Run ==="
else
  echo "=== Installation Complete ==="
fi

echo ""
for action in "${ACTIONS[@]}"; do
  echo "  $action"
done
echo ""

if [[ "$CHECK_ONLY" == "1" ]]; then
  echo "Run without --check to apply these changes."
fi
