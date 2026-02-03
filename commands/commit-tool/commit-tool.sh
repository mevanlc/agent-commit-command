#!/usr/bin/env bash
# commit-tool.sh - Unified commit helper for Claude Code slash commands
# Usage: commit-tool.sh <git-cmd> "<mode> [additional-instructions...]"
#   git-cmd: "git" or "gdf" (or other git wrapper)
#   mode: --staged, --all, or --ask
#   Note: arg2 is a single quoted string; mode is split from the first word

set -euo pipefail

# set -x

# === OUTPUT SIZE THRESHOLD ===
# Claude Code truncates output over 30000 characters, which can cut off
# critical instructions. We check total output size and externalize the
# diff to a temp file if needed to keep instructions visible.
MAX_OUTPUT_CHARS=28000  # Leave some margin below 30000

# === --write-config HANDLING ===

if [[ "${1:-}" == "--write-config" ]]; then
  TARGET="${2:-}"
  if [[ -z "$TARGET" ]]; then
    echo "Usage: commit-tool.sh --write-config <file>" >&2
    exit 1
  fi
  if [[ -e "$TARGET" ]]; then
    echo "Error: $TARGET already exists" >&2
    exit 1
  fi
  cat > "$TARGET" <<'CONFIGEOF'
# commit-tool.config - Reporting configuration
#
# Format: key=value (no spaces around =)
# Lines starting with # are comments
# Blank lines are ignored

# Show most recent N commits for style reference (0 to disable)
report_recent_commits=5

# Note: Identity checking has moved to commit-tool/hook-preflight/01-id-check.config
CONFIGEOF
  echo "Created $TARGET"
  exit 0
fi

GIT_CMD="${1:-git}"
# Split arg2: first word is MODE, rest is EXTRA_INSTRUCTIONS
read -r MODE EXTRA_INSTRUCTIONS <<< "${2:-}"

# === INVALID MODE HANDLING ===

if [[ -z "$MODE" ]]; then
  cat <<'EOF'
# Invalid Invocation - Missing Mode

The user invoked `/commit` without a required mode. Please inform them:

**Usage:** `/commit <mode> [additional instructions]`

**Modes:**
- `--staged` - Commit exactly what's staged (ignores unstaged changes)
- `--all` - Stage all modifications, then commit
- `--ask` - Interactively decide what to stage

**Examples:**
```
/commit --staged
/commit --all fix the auth routes
/commit --ask
```
EOF
  exit 0
fi

case "$MODE" in
  --staged|--all|--ask) ;;
  *)
    cat <<EOF
# Invalid Invocation - Unknown Mode

The user provided an unrecognized mode: \`$MODE\`

Please inform them:

**Valid modes:** \`--staged\`, \`--all\`, \`--ask\`

**Examples:**
\`\`\`
/commit --staged
/commit --all fix the auth routes
/commit --ask
\`\`\`
EOF
    exit 0
    ;;
esac

# === LOAD CONFIG ===

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/commit-tool.config"

# Defaults
REPORT_RECENT_COMMITS=10

if [[ -f "$CONFIG_FILE" ]]; then
  while IFS= read -r line || [[ -n "$line" ]]; do
    # Strip carriage return (Windows CRLF)
    line="${line//$'\r'/}"
    # Skip comments and blank lines
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    [[ -z "${line// }" ]] && continue

    key="${line%%=*}"
    value="${line#*=}"

    case "$key" in
      report_recent_commits) REPORT_RECENT_COMMITS="$value" ;;
    esac
  done < "$CONFIG_FILE"
fi

# === HOOK SUPPORT ===

run_hooks_for() {
  local stage="$1"
  local pattern="${SCRIPT_DIR}/hook-${stage}-*.sh"

  # Find hooks matching pattern (e.g., hook-preflight-01-id-check.sh)
  local hooks=()
  for f in $pattern; do
    [[ -f "$f" ]] && hooks+=("$f")
  done
  [[ ${#hooks[@]} -eq 0 ]] && return 0

  # Run hooks in sorted order
  while IFS= read -r -d '' hook_sh; do
    local hook_output rc=0
    hook_output=$("$hook_sh" "$GIT_CMD" "$MODE" "$EXTRA_INSTRUCTIONS") || rc=$?
    if [[ $rc -ne 0 ]]; then
      echo "Stopping execution due to ${stage} hook return code."
      echo "Hook script: ${hook_sh}"
      echo "Return code: ${rc}"
      echo ""
      echo "Stop and help the user resolve."
      exit 1
    fi
    echo -n "$hook_output"
  done < <(printf '%s\0' "${hooks[@]}" | sort -z)
}

# Run preflight hooks
PREFLIGHT_OUTPUT=$(run_hooks_for preflight)

# === GATHER GIT CONTEXT ===

BRANCH=$($GIT_CMD branch --show-current 2>/dev/null || echo "(detached HEAD)")
USER_NAME=$($GIT_CMD config user.name)
USER_EMAIL=$($GIT_CMD config user.email)
STATUS=$($GIT_CMD status --short)
STAGED_FILES=$($GIT_CMD diff --cached --name-only)
UNSTAGED_FILES=$($GIT_CMD diff --name-only)
UNTRACKED=$($GIT_CMD ls-files --others --exclude-standard)

# Check for conflicts
CONFLICTS=$($GIT_CMD diff --name-only --diff-filter=U 2>/dev/null || true)

# === SHARED INSTRUCTION BLOCKS ===

COMMIT_REVIEW_FORMAT='Present a **Commit Review** to the user in this exact format:

```
# Commit Review

## Paths
M  path/to/modified
A  path/to/added
D  path/to/deleted
R  {old/path -> new/path}

## Proposed Commit Message
<summary line>
[- bullet if needed]
[- bullet if needed]

Proceed? ([y]es / [n]o)
```

Wait for user confirmation before committing.'

# === BUILD REPORT SECTIONS ===

RECENT_COMMITS_SECTION=""
if [[ "$REPORT_RECENT_COMMITS" -gt 0 ]]; then
  commits=$($GIT_CMD log --oneline -"$REPORT_RECENT_COMMITS" 2>/dev/null || echo "(no commits yet)")
  RECENT_COMMITS_SECTION="# Recent Commits
\`\`\`
${commits}
\`\`\`
"
fi

# === OUTPUT COMPOSITION HELPERS ===

# These functions build output sections into variables so we can
# measure total size before emitting, and externalize the diff if needed.

compose_diff_inline() {
  local diff_content="$1"
  cat <<EOF
# Diff

Output of \`$GIT_CMD diff --cached\`:
\`\`\`diff
$diff_content
\`\`\`

EOF
}

compose_diff_external() {
  local diff_file="$1"
  local char_count="$2"
  cat <<EOF
# Diff

**Diff too large for inline display** ($char_count characters)

The diff has been saved to: \`$diff_file\`

**Instructions for reviewing the diff:**
1. Use the Read tool to examine the diff file (you may need to read it in chunks using offset/limit if it's very large)
2. After you have fully reviewed the diff, delete the temp file
3. Then proceed with the commit review as normal

EOF
}

compose_diff_too_many_lines() {
  local line_count="$1"
  cat <<EOF
# Diff
**DIFF TOO LARGE** ($line_count lines) - discuss strategies with user:
- Split the commit
- Review anyway (might fit context)
- Reduce diff context lines
- Skip lock files

EOF
}

# === MODE: --staged ===

if [[ "$MODE" == "--staged" ]]; then
  # Check early exit conditions first (these output directly and exit)
  if [[ -n "$CONFLICTS" ]]; then
    cat <<'EOF'
# Git Commit - Staged Only Mode

Commit exactly what's staged. **Ignore unstaged changes entirely** - don't mention them.

EOF
    if [[ -n "$EXTRA_INSTRUCTIONS" ]]; then
      cat <<EOF
# Additional Instructions from User
$EXTRA_INSTRUCTIONS

EOF
    fi
    cat <<EOF
Branch: \`$BRANCH\`
Identity: \`$USER_NAME <$USER_EMAIL>\`

EOF
    [[ -n "$RECENT_COMMITS_SECTION" ]] && echo "$RECENT_COMMITS_SECTION"
    [[ -n "$PREFLIGHT_OUTPUT" ]] && echo "$PREFLIGHT_OUTPUT"
    cat <<EOF
# CONFLICTS DETECTED - STOP
\`\`\`
$CONFLICTS
\`\`\`
Inform user and help resolve before committing.

EOF
    exit 0
  fi

  if [[ -z "$STAGED_FILES" ]]; then
    cat <<EOF
# Git Commit - Staged Only Mode

# Nothing Staged - STOP

There are no staged changes. Inform the user:
- They need to stage changes first (\`$GIT_CMD add <files>\`)
- Or use \`/commit --all\` to stage everything
- Or use \`/commit --ask\` for interactive help

EOF
    exit 0
  fi

  # Get staged status and diff
  STAGED_STATUS=$($GIT_CMD status --porcelain | grep '^[MADRCT]' || true)
  STAGED_DIFF=$($GIT_CMD diff --cached)
  DIFF_LINES=$(echo "$STAGED_DIFF" | wc -l)

  # Check line count threshold first
  if [[ $DIFF_LINES -gt 8000 ]]; then
    # Too many lines - use the original "discuss with user" approach
    OUTPUT_HEADER="# Git Commit - Staged Only Mode

Commit exactly what's staged. **Ignore unstaged changes entirely** - don't mention them.

"
    [[ -n "$EXTRA_INSTRUCTIONS" ]] && OUTPUT_HEADER+="# Additional Instructions from User
$EXTRA_INSTRUCTIONS

"
    OUTPUT_HEADER+="Branch: \`$BRANCH\`
Identity: \`$USER_NAME <$USER_EMAIL>\`

"
    [[ -n "$RECENT_COMMITS_SECTION" ]] && OUTPUT_HEADER+="$RECENT_COMMITS_SECTION"
    [[ -n "$PREFLIGHT_OUTPUT" ]] && OUTPUT_HEADER+="$PREFLIGHT_OUTPUT"

    OUTPUT_PRE_DIFF="# Staged Changes

Output of \`$GIT_CMD status --porcelain | grep '^[MADRCT]'\`:
\`\`\`
$STAGED_STATUS
\`\`\`

"
    OUTPUT_DIFF=$(compose_diff_too_many_lines "$DIFF_LINES")

    OUTPUT_INSTRUCTIONS="# Instructions

1. Review the diff and generate a commit message (imperative summary, optional bullets for distinct changes)
2. Match the style of recent commits shown above
3. $COMMIT_REVIEW_FORMAT
4. If confirmed: commit using HEREDOC format
5. Show resulting commit hash

# Safety Checks

Stop and warn if staged files include:
- Secrets (\`.env\`, credentials, API keys, certs)
- Large binaries that look accidental
"
    echo -n "${OUTPUT_HEADER}${OUTPUT_PRE_DIFF}${OUTPUT_DIFF}${OUTPUT_INSTRUCTIONS}"
    exit 0
  fi

  # Compose full output to measure size
  OUTPUT_HEADER="# Git Commit - Staged Only Mode

Commit exactly what's staged. **Ignore unstaged changes entirely** - don't mention them.

"
  [[ -n "$EXTRA_INSTRUCTIONS" ]] && OUTPUT_HEADER+="# Additional Instructions from User
$EXTRA_INSTRUCTIONS

"
  OUTPUT_HEADER+="Branch: \`$BRANCH\`
Identity: \`$USER_NAME <$USER_EMAIL>\`

"
  [[ -n "$RECENT_COMMITS_SECTION" ]] && OUTPUT_HEADER+="$RECENT_COMMITS_SECTION"
  [[ -n "$PREFLIGHT_OUTPUT" ]] && OUTPUT_HEADER+="$PREFLIGHT_OUTPUT"

  OUTPUT_PRE_DIFF="# Staged Changes

Output of \`$GIT_CMD status --porcelain | grep '^[MADRCT]'\`:
\`\`\`
$STAGED_STATUS
\`\`\`

"

  OUTPUT_DIFF_INLINE=$(compose_diff_inline "$STAGED_DIFF")

  OUTPUT_INSTRUCTIONS="# Instructions

1. Review the diff and generate a commit message (imperative summary, optional bullets for distinct changes)
2. Match the style of recent commits shown above
3. $COMMIT_REVIEW_FORMAT
4. If confirmed: commit using HEREDOC format
5. Show resulting commit hash

# Safety Checks

Stop and warn if staged files include:
- Secrets (\`.env\`, credentials, API keys, certs)
- Large binaries that look accidental
"

  FULL_OUTPUT="${OUTPUT_HEADER}${OUTPUT_PRE_DIFF}${OUTPUT_DIFF_INLINE}${OUTPUT_INSTRUCTIONS}"
  CHAR_COUNT=${#FULL_OUTPUT}

  if [[ $CHAR_COUNT -gt $MAX_OUTPUT_CHARS ]]; then
    # Externalize diff to file
    DIFF_FILE="/tmp/commit-tool-diff-$$.txt"
    echo "$STAGED_DIFF" > "$DIFF_FILE"
    DIFF_CHAR_COUNT=${#STAGED_DIFF}
    OUTPUT_DIFF_EXTERNAL=$(compose_diff_external "$DIFF_FILE" "$DIFF_CHAR_COUNT")
    FULL_OUTPUT="${OUTPUT_HEADER}${OUTPUT_PRE_DIFF}${OUTPUT_DIFF_EXTERNAL}${OUTPUT_INSTRUCTIONS}"
  fi

  echo -n "$FULL_OUTPUT"
  exit 0
fi

# === MODE: --all ===

if [[ "$MODE" == "--all" ]]; then
  # Check early exit conditions first
  if [[ -n "$CONFLICTS" ]]; then
    cat <<'EOF'
# Git Commit - Stage All Mode

Stage all outstanding changes, then commit.

EOF
    if [[ -n "$EXTRA_INSTRUCTIONS" ]]; then
      cat <<EOF
# Additional Instructions from User
$EXTRA_INSTRUCTIONS

EOF
    fi
    cat <<EOF
Branch: \`$BRANCH\`
Identity: \`$USER_NAME <$USER_EMAIL>\`

EOF
    [[ -n "$RECENT_COMMITS_SECTION" ]] && echo "$RECENT_COMMITS_SECTION"
    [[ -n "$PREFLIGHT_OUTPUT" ]] && echo "$PREFLIGHT_OUTPUT"
    cat <<EOF
# CONFLICTS DETECTED - STOP
\`\`\`
$CONFLICTS
\`\`\`
Inform user and help resolve before committing.

EOF
    exit 0
  fi

  if [[ -z "$STATUS" ]]; then
    cat <<'EOF'
# Git Commit - Stage All Mode

# No Changes - STOP

Working tree is clean. Nothing to commit. Inform the user.

EOF
    exit 0
  fi

  # Save current staged state, then stage everything
  BACKUP_PATCH="/tmp/commit-tool-staged-backup-$$.patch"
  $GIT_CMD diff --cached > "$BACKUP_PATCH" 2>/dev/null || true
  $GIT_CMD add -A

  # Get staged status and diff
  STAGED_STATUS=$($GIT_CMD status --porcelain 2>/dev/null || true)
  ALL_DIFF=$($GIT_CMD diff --cached 2>/dev/null || true)
  DIFF_LINES=$(echo "$ALL_DIFF" | wc -l)

  # Check line count threshold first
  if [[ $DIFF_LINES -gt 8000 ]]; then
    OUTPUT_HEADER="# Git Commit - Stage All Mode

Stage all outstanding changes, then commit.

"
    [[ -n "$EXTRA_INSTRUCTIONS" ]] && OUTPUT_HEADER+="# Additional Instructions from User
$EXTRA_INSTRUCTIONS

"
    OUTPUT_HEADER+="Branch: \`$BRANCH\`
Identity: \`$USER_NAME <$USER_EMAIL>\`

"
    [[ -n "$RECENT_COMMITS_SECTION" ]] && OUTPUT_HEADER+="$RECENT_COMMITS_SECTION"
    [[ -n "$PREFLIGHT_OUTPUT" ]] && OUTPUT_HEADER+="$PREFLIGHT_OUTPUT"

    OUTPUT_PRE_DIFF="# Staged Changes

Ran \`$GIT_CMD add -A\` to stage all changes.

Output of \`$GIT_CMD status --porcelain\`:
\`\`\`
$STAGED_STATUS
\`\`\`

> Staging backup saved to \`$BACKUP_PATCH\`
> To abort: \`$GIT_CMD reset HEAD && $GIT_CMD apply --cached $BACKUP_PATCH\`

"
    OUTPUT_DIFF=$(compose_diff_too_many_lines "$DIFF_LINES")

    OUTPUT_INSTRUCTIONS="# Instructions

Changes are already staged. Review and confirm:

1. Review the diff and generate a commit message (imperative summary, optional bullets for distinct changes)
2. Match the style of recent commits shown above
3. $COMMIT_REVIEW_FORMAT
4. If confirmed: commit using HEREDOC format, then show resulting hash
5. If declined: run \`$GIT_CMD reset HEAD && $GIT_CMD apply --cached $BACKUP_PATCH\` to restore previous staging

# Safety Checks

Stop and warn if changes include:
- Secrets (\`.env\`, credentials, API keys, certs)
- Large binaries that look accidental
- Files that seem unrelated to the apparent intent
"
    echo -n "${OUTPUT_HEADER}${OUTPUT_PRE_DIFF}${OUTPUT_DIFF}${OUTPUT_INSTRUCTIONS}"
    exit 0
  fi

  # Compose full output to measure size
  OUTPUT_HEADER="# Git Commit - Stage All Mode

Stage all outstanding changes, then commit.

"
  [[ -n "$EXTRA_INSTRUCTIONS" ]] && OUTPUT_HEADER+="# Additional Instructions from User
$EXTRA_INSTRUCTIONS

"
  OUTPUT_HEADER+="Branch: \`$BRANCH\`
Identity: \`$USER_NAME <$USER_EMAIL>\`

"
  [[ -n "$RECENT_COMMITS_SECTION" ]] && OUTPUT_HEADER+="$RECENT_COMMITS_SECTION"
  [[ -n "$PREFLIGHT_OUTPUT" ]] && OUTPUT_HEADER+="$PREFLIGHT_OUTPUT"

  OUTPUT_PRE_DIFF="# Staged Changes

Ran \`$GIT_CMD add -A\` to stage all changes.

Output of \`$GIT_CMD status --porcelain\`:
\`\`\`
$STAGED_STATUS
\`\`\`

> Staging backup saved to \`$BACKUP_PATCH\`
> To abort: \`$GIT_CMD reset HEAD && $GIT_CMD apply --cached $BACKUP_PATCH\`

"

  OUTPUT_DIFF_INLINE=$(compose_diff_inline "$ALL_DIFF")

  OUTPUT_INSTRUCTIONS="# Instructions

Changes are already staged. Review and confirm:

1. Review the diff and generate a commit message (imperative summary, optional bullets for distinct changes)
2. Match the style of recent commits shown above
3. $COMMIT_REVIEW_FORMAT
4. If confirmed: commit using HEREDOC format, then show resulting hash
5. If declined: run \`$GIT_CMD reset HEAD && $GIT_CMD apply --cached $BACKUP_PATCH\` to restore previous staging

# Safety Checks

Stop and warn if changes include:
- Secrets (\`.env\`, credentials, API keys, certs)
- Large binaries that look accidental
- Files that seem unrelated to the apparent intent
"

  FULL_OUTPUT="${OUTPUT_HEADER}${OUTPUT_PRE_DIFF}${OUTPUT_DIFF_INLINE}${OUTPUT_INSTRUCTIONS}"
  CHAR_COUNT=${#FULL_OUTPUT}

  if [[ $CHAR_COUNT -gt $MAX_OUTPUT_CHARS ]]; then
    # Externalize diff to file
    DIFF_FILE="/tmp/commit-tool-diff-$$.txt"
    echo "$ALL_DIFF" > "$DIFF_FILE"
    DIFF_CHAR_COUNT=${#ALL_DIFF}
    OUTPUT_DIFF_EXTERNAL=$(compose_diff_external "$DIFF_FILE" "$DIFF_CHAR_COUNT")
    FULL_OUTPUT="${OUTPUT_HEADER}${OUTPUT_PRE_DIFF}${OUTPUT_DIFF_EXTERNAL}${OUTPUT_INSTRUCTIONS}"
  fi

  echo -n "$FULL_OUTPUT"
  exit 0
fi

# === MODE: --ask ===

if [[ "$MODE" == "--ask" ]]; then
  cat <<'EOF'
# Git Commit - Interactive Mode

Help the user decide what to stage and commit.

EOF

  if [[ -n "$EXTRA_INSTRUCTIONS" ]]; then
    cat <<EOF
# Additional Instructions from User
$EXTRA_INSTRUCTIONS

EOF
  fi

  cat <<EOF
Branch: \`$BRANCH\`
Identity: \`$USER_NAME <$USER_EMAIL>\`

EOF

  # Report sections
  [[ -n "$RECENT_COMMITS_SECTION" ]] && echo "$RECENT_COMMITS_SECTION"
  # Preflight hook output (identity reports and warnings)
  [[ -n "$PREFLIGHT_OUTPUT" ]] && echo "$PREFLIGHT_OUTPUT"

  if [[ -n "$CONFLICTS" ]]; then
    cat <<EOF
# CONFLICTS DETECTED - STOP
\`\`\`
$CONFLICTS
\`\`\`
Inform user and help resolve before committing.

EOF
    exit 0
  fi

  # Get full status including untracked
  FULL_STATUS=$($GIT_CMD status --porcelain -u 2>/dev/null || true)

  cat <<EOF
# Working Tree Status

Output of \`$GIT_CMD status --porcelain -u\`:
\`\`\`
${FULL_STATUS:-"(clean)"}
\`\`\`

EOF

  if [[ -z "$FULL_STATUS" ]]; then
    cat <<'EOF'
# No Changes - STOP

Working tree is clean. Nothing to commit. Inform the user.

EOF
    exit 0
  fi

  cat <<EOF
# Instructions

1. **Show the user what's available to commit** - relay the status above (they can't see slash command output):
   - First column: staged status (\`M\`=modified, \`A\`=added, \`D\`=deleted, \`R\`=renamed)
   - Second column: unstaged status
   - \`??\` = untracked file
2. **Ask the user** what should be included in this commit:
   - Suggest logical groupings if changes seem separable
   - If user gave additional instructions, use those as guidance
   - Offer options like "all of it", "just the staged", or specific files
3. Stage the selected changes (\`$GIT_CMD add <files>\`)
4. **Before generating the commit review**, run \`$GIT_CMD status --porcelain -u\` to refresh your view of what's staged
5. Generate a commit message (imperative summary, optional bullets)
6. $COMMIT_REVIEW_FORMAT
7. If confirmed: commit using HEREDOC format
8. Show resulting commit hash

# Safety Checks

Stop and warn if selected files include:
- Secrets (\`.env\`, credentials, API keys, certs)
- Large binaries that look accidental
EOF
  exit 0
fi
