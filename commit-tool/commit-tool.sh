#!/usr/bin/env bash
# commit-tool.sh - Unified commit helper for Claude Code slash commands
# Usage: commit-tool.sh <git-cmd> "<mode> [additional-instructions...]"
#   git-cmd: "git" or "gdf" (or other git wrapper)
#   mode: --staged, --staged-yes, --all, --all-yes, or --ask
#   Note: arg2 is a single quoted string; mode is split from the first word

set -euo pipefail

# set -x

# === OUTPUT SIZE THRESHOLD ===
# Claude Code truncates output over 30000 characters, which can cut off
# critical instructions. We check total output size and externalize the
# diff to a temp file if needed to keep instructions visible.
MAX_OUTPUT_CHARS=28000  # Leave some margin below 30000

# === GLOBAL INSTRUCTIONS (ALL PATHS) ===

GLOBAL_INSTRUCTIONS_SECTION="$(
  cat <<'EOF'
## Global Instructions

- You do not need to acknowledge that you are going to use the tool or the skill -- just use it
- You do not need to check for the presence of commit-tool.sh -- just call it -- report any after-the-fact failures
- Always use a descriptive commit message that summarizes the changes; do not use short, non-descriptive messages such as `sync` or `wip`, even if recent commit history contains examples of them
- Do not push without the user's clear and affirmative instruction to do so

EOF
  printf '__END__'
)"
GLOBAL_INSTRUCTIONS_SECTION="${GLOBAL_INSTRUCTIONS_SECTION%__END__}"

emit_global_instructions() {
  printf '%s' "$GLOBAL_INSTRUCTIONS_SECTION"
  [[ -n "${PRECONFIRMED_MODE_SECTION:-}" ]] && printf '%s' "$PRECONFIRMED_MODE_SECTION"
  true  # avoid set -e exit when the preconfirmed-mode section is empty
}

temp_dir() {
  if [[ -n "${TMPDIR:-}" ]]; then
    printf '%s\n' "${TMPDIR%/}"
    return
  fi

  if [[ -n "${PREFIX:-}" && -d "${PREFIX%/}/tmp" ]]; then
    printf '%s\n' "${PREFIX%/}/tmp"
    return
  fi

  printf '%s\n' /tmp
}

make_temp_file() {
  local stem="$1"
  local suffix="$2"
  # suffix goes BEFORE the X's — macOS mktemp only randomizes
  # trailing X's (uses mkstemp, not mkstemps).
  mktemp "$(temp_dir)/${stem}${suffix}.XXXXXX"
}

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

# Note: Identity checking is configured in hooks/hook-preflight-01-id-check.config
# (located in the same config directory as this file)
CONFIGEOF
  echo "Created $TARGET"
  exit 0
fi

GIT_CMD="${1:-git}"
# Split arg2: first word is MODE, rest is EXTRA_INSTRUCTIONS
read -r MODE EXTRA_INSTRUCTIONS <<< "${2:-}"
BASE_MODE="$MODE"
PRECONFIRMED_MODE=0

# === INVALID MODE HANDLING ===

if [[ -z "$MODE" ]]; then
  cat <<'EOF'
# Invalid Invocation - Missing Mode

The user invoked `/commit` without a required mode. Please inform them:

EOF
  emit_global_instructions
  cat <<'EOF'
**Usage:** `/commit <mode> [additional instructions]`

**Modes:**
- `--staged` - Commit exactly what's staged (ignores unstaged changes)
- `--staged-yes` - Commit exactly what's staged without waiting at the commit gate
- `--all` - Stage all modifications, then commit
- `--all-yes` - Stage all modifications and commit without waiting at the commit gate
- `--ask` - Interactively decide what to stage

**Examples:**
```
/commit --staged
/commit --staged-yes
/commit --all fix the auth routes
/commit --all-yes update the documentation
/commit --ask
```
EOF
  exit 0
fi

case "$MODE" in
  --staged|--all|--ask) ;;
  --staged-yes)
    BASE_MODE="--staged"
    PRECONFIRMED_MODE=1
    ;;
  --all-yes)
    BASE_MODE="--all"
    PRECONFIRMED_MODE=1
    ;;
  *)
    printf '# Invalid Invocation - Unknown Mode\n\n'
    printf 'The user provided an unrecognized mode: `%s`\n\n' "$MODE"
    cat <<'EOF'
Please inform them:

EOF
    emit_global_instructions
    cat <<'EOF'
**Valid modes:** `--staged`, `--staged-yes`, `--all`, `--all-yes`, `--ask`

**Examples:**
```
/commit --staged
/commit --staged-yes
/commit --all fix the auth routes
/commit --all-yes update the documentation
/commit --ask
```
EOF
    exit 0
    ;;
esac

read -r FIRST_EXTRA_ARG _ <<< "$EXTRA_INSTRUCTIONS"
if [[ "$FIRST_EXTRA_ARG" == "--yes" ]]; then
  cat <<'EOF'
# Invalid Invocation - Separate --yes Modifier

`--yes` is not a standalone modifier. Please inform the user:

EOF
  emit_global_instructions
  cat <<'EOF'
- Use `--staged-yes` instead of `--staged --yes`
- Use `--all-yes` instead of `--all --yes`
- `--ask` is always interactive and cannot be combined with `--yes`
EOF
  exit 0
fi

PRECONFIRMED_MODE_SECTION=""
if [[ "$PRECONFIRMED_MODE" -eq 1 ]]; then
  PRECONFIRMED_MODE_SECTION="$({
    cat <<'EOF'
## Preconfirmed Mode

- The user explicitly selected `--staged-yes` or `--all-yes`, so the `y/n` commit gate is preanswered `y`
- Still present the Commit Review, then commit immediately without waiting for the user to reply
- Be slightly more wary of unusual files and similar concerns because the user will not have an opportunity to decline the commit
- If you find such a concern, drop out of preconfirmed mode and resolve it interactively with the user. Once dropped, do not re-enter preconfirmed mode; use the ordinary `y/n` commit gate before committing
- If a pre-commit hook rejects the commit for a mechanical, low-risk issue, you may fix it and retry while preconfirmed mode remains engaged
- For a more substantial pre-commit hook issue, drop out of preconfirmed mode and involve the user interactively

EOF
    printf '__END__'
  })"
  PRECONFIRMED_MODE_SECTION="${PRECONFIRMED_MODE_SECTION%__END__}"
fi

# === LOAD CONFIG ===

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${AGENT_COMMIT_CONFIG_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/agent-commit-command}"
CONFIG_FILE="${CONFIG_DIR}/commit-tool.config"

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
  local pattern="${CONFIG_DIR}/hooks/hook-${stage}-*.sh"

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
      return 1
    fi
    echo -n "$hook_output"
  done < <(printf '%s\0' "${hooks[@]}" | sort -z)
}

# Run preflight hooks
PREFLIGHT_OUTPUT=""
if ! PREFLIGHT_OUTPUT="$(run_hooks_for preflight)"; then
  emit_global_instructions
  [[ -n "$PREFLIGHT_OUTPUT" ]] && echo "$PREFLIGHT_OUTPUT"
  exit 1
fi

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

if [[ "$PRECONFIRMED_MODE" -eq 1 ]]; then
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

----

Proceeding automatically (preconfirmed mode)
```

After presenting the review, commit immediately without waiting for a reply.'
  COMMIT_ACTION='Commit immediately without waiting for user confirmation, using HEREDOC format'
  STAGED_REVIEW_INTRO='Changes are already staged. Review before committing:'
  DECLINE_CONDITION='If preconfirmed mode is dropped and the user then declines'
else
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

----

Proceed? ([y]es / [n]o)
```

Wait for user confirmation before committing.'
  COMMIT_ACTION='If confirmed: commit using HEREDOC format'
  STAGED_REVIEW_INTRO='Changes are already staged. Review and confirm:'
  DECLINE_CONDITION='If declined'
fi

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

# IMPORTANT: All output helpers use printf instead of heredocs (cat <<EOF).
# Bash 5.x has a heredoc deadlock bug when content reaches 512 bytes
# (PIPE_BUF on macOS). printf bypasses the internal pipe entirely.

compose_diff_inline() {
  local diff_content="$1"
  printf '# Diff\n\nOutput of `%s diff --cached`:\n```diff\n' "$GIT_CMD"
  printf '%s\n' "$diff_content"
  printf '```\n\n'
}

compose_diff_external() {
  local diff_file="$1"
  local char_count="$2"
  printf '# Diff\n\n'
  printf '**Diff too large for inline display** (%s characters)\n\n' "$char_count"
  printf 'The diff has been saved to: `%s`\n\n' "$diff_file"
  cat <<'EOF'
**Instructions for reviewing the diff:**
1. Use the Read tool to examine the diff file (you may need to read it in chunks using offset/limit if it's very large)
2. After you have fully reviewed the diff, you MUST delete the diff temp file for privacy and cleanliness.
3. Then proceed with the commit review as normal

EOF
}

compose_diff_too_many_lines() {
  local line_count="$1"
  printf '# Diff\n'
  printf '**DIFF TOO LARGE** (%s lines) - discuss strategies with user:\n' "$line_count"
  cat <<'EOF'
- Split the commit
- Review anyway (might fit context)
- Reduce diff context lines
- Skip lock files

EOF
}

# Emit the extra-instructions block (if any)
emit_extra_instructions() {
  if [[ -n "$EXTRA_INSTRUCTIONS" ]]; then
    printf '# Additional Instructions from User\n%s\n\n' "$EXTRA_INSTRUCTIONS"
  fi
}

# Emit branch and identity line
emit_branch_identity() {
  printf 'Branch: `%s`\nIdentity: `%s <%s>`\n\n' "$BRANCH" "$USER_NAME" "$USER_EMAIL"
}

# Emit report sections (recent commits, preflight output)
emit_report_sections() {
  [[ -n "$RECENT_COMMITS_SECTION" ]] && echo "$RECENT_COMMITS_SECTION"
  [[ -n "$PREFLIGHT_OUTPUT" ]] && echo "$PREFLIGHT_OUTPUT"
  true  # avoid set -e exit when last test is false
}

# Emit conflicts block
emit_conflicts_block() {
  printf '# CONFLICTS DETECTED - STOP\n```\n%s\n```\n' "$CONFLICTS"
  printf 'Inform user and help resolve before committing.\n\n'
}

# === MODE: --staged ===

if [[ "$BASE_MODE" == "--staged" ]]; then
  # Check early exit conditions first (these output directly and exit)
  if [[ -n "$CONFLICTS" ]]; then
    cat <<'EOF'
# Git Commit - Staged Only Mode

EOF
    emit_global_instructions
    cat <<'EOF'
Commit exactly what's staged. **Ignore unstaged changes entirely** - don't mention them.

EOF
    emit_extra_instructions
    emit_branch_identity
    emit_report_sections
    emit_conflicts_block
    exit 0
  fi

  if [[ -z "$STAGED_FILES" ]]; then
    cat <<'EOF'
# Git Commit - Staged Only Mode

EOF
    emit_global_instructions
    cat <<'EOF'
# Nothing Staged - STOP

EOF
    printf 'There are no staged changes. Inform the user:\n'
    printf -- '- They need to stage changes first (`%s add <files>`)\n' "$GIT_CMD"
    printf -- '- Or use `/commit --all` to stage everything\n'
    printf -- '- Or use `/commit --ask` for interactive help\n\n'
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

${GLOBAL_INSTRUCTIONS_SECTION}${PRECONFIRMED_MODE_SECTION}Commit exactly what's staged. **Ignore unstaged changes entirely** - don't mention them.

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
4. $COMMIT_ACTION
5. If the commit was uneventful, report only: \`Completed successfully.\`
6. If hooks, formatters, clippy, errors, or substantial warnings made the commit eventful, summarize those events without reporting the commit hash

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

${GLOBAL_INSTRUCTIONS_SECTION}${PRECONFIRMED_MODE_SECTION}Commit exactly what's staged. **Ignore unstaged changes entirely** - don't mention them.

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
4. $COMMIT_ACTION
5. If the commit was uneventful, report only: \`Completed successfully.\`
6. If hooks, formatters, clippy, errors, or substantial warnings made the commit eventful, summarize those events without reporting the commit hash

# Safety Checks

Stop and warn if staged files include:
- Secrets (\`.env\`, credentials, API keys, certs)
- Large binaries that look accidental
"

  FULL_OUTPUT="${OUTPUT_HEADER}${OUTPUT_PRE_DIFF}${OUTPUT_DIFF_INLINE}${OUTPUT_INSTRUCTIONS}"
  CHAR_COUNT=${#FULL_OUTPUT}

  if [[ $CHAR_COUNT -gt $MAX_OUTPUT_CHARS ]]; then
    # Externalize diff to file
    DIFF_FILE="$(make_temp_file commit-tool-diff .txt)"
    echo "$STAGED_DIFF" > "$DIFF_FILE"
    DIFF_CHAR_COUNT=${#STAGED_DIFF}
    OUTPUT_DIFF_EXTERNAL=$(compose_diff_external "$DIFF_FILE" "$DIFF_CHAR_COUNT")
    FULL_OUTPUT="${OUTPUT_HEADER}${OUTPUT_PRE_DIFF}${OUTPUT_DIFF_EXTERNAL}${OUTPUT_INSTRUCTIONS}"
  fi

  echo -n "$FULL_OUTPUT"
  exit 0
fi

# === MODE: --all ===

if [[ "$BASE_MODE" == "--all" ]]; then
  # Check early exit conditions first
  if [[ -n "$CONFLICTS" ]]; then
    cat <<'EOF'
# Git Commit - Stage All Mode

EOF
    emit_global_instructions
    cat <<'EOF'
Stage all outstanding changes, then commit.

EOF
    emit_extra_instructions
    emit_branch_identity
    emit_report_sections
    emit_conflicts_block
    exit 0
  fi

  if [[ -z "$STATUS" ]]; then
    cat <<'EOF'
# Git Commit - Stage All Mode

EOF
    emit_global_instructions
    cat <<'EOF'
# No Changes - STOP

Working tree is clean. Nothing to commit. Inform the user.

EOF
    exit 0
  fi

		# Save current staged state, then stage everything
		  BACKUP_PATCH="$(make_temp_file commit-tool-staged-backup .patch)"
		  $GIT_CMD diff --cached > "$BACKUP_PATCH" 2>/dev/null || true
	  BACKUP_HAS_CONTENT=0
	  [[ -s "$BACKUP_PATCH" ]] && BACKUP_HAS_CONTENT=1

	  HAS_COMMITS=0
	  $GIT_CMD rev-parse --verify HEAD >/dev/null 2>&1 && HAS_COMMITS=1

	  RESET_INDEX_CMD=""
	  if [[ "$HAS_COMMITS" -eq 1 ]]; then
	    RESET_INDEX_CMD="$GIT_CMD reset --mixed"
	  else
	    # New repo with no commits yet: HEAD does not exist, so git reset HEAD fails.
	    RESET_INDEX_CMD="$GIT_CMD read-tree --empty"
	  fi

	  RESTORE_STAGING_CMD="$RESET_INDEX_CMD"
	  if [[ "$BACKUP_HAS_CONTENT" -eq 1 ]]; then
	    RESTORE_STAGING_CMD+=" && $GIT_CMD apply --cached \"$BACKUP_PATCH\""
	  fi

	  BACKUP_NOTE="Staging backup saved to \`$BACKUP_PATCH\`"
	  if [[ "$BACKUP_HAS_CONTENT" -eq 0 ]]; then
	    BACKUP_NOTE+=" (empty; nothing was staged before)"
	  fi
	  $GIT_CMD add -A

  # Get staged status and diff
  STAGED_STATUS=$($GIT_CMD status --porcelain 2>/dev/null || true)
  ALL_DIFF=$($GIT_CMD diff --cached 2>/dev/null || true)
  DIFF_LINES=$(echo "$ALL_DIFF" | wc -l)

  # Check line count threshold first
  if [[ $DIFF_LINES -gt 8000 ]]; then
    OUTPUT_HEADER="# Git Commit - Stage All Mode

${GLOBAL_INSTRUCTIONS_SECTION}${PRECONFIRMED_MODE_SECTION}Stage all outstanding changes, then commit.

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

> $BACKUP_NOTE
> To abort: \`$RESTORE_STAGING_CMD\`

"
    OUTPUT_DIFF=$(compose_diff_too_many_lines "$DIFF_LINES")

    OUTPUT_INSTRUCTIONS="# Instructions

$STAGED_REVIEW_INTRO

1. Review the diff and generate a commit message (imperative summary, optional bullets for distinct changes)
2. Match the style of recent commits shown above
3. $COMMIT_REVIEW_FORMAT
4. $COMMIT_ACTION
5. If the commit was uneventful, report only: \`Completed successfully.\`
6. If hooks, formatters, clippy, errors, or substantial warnings made the commit eventful, summarize those events without reporting the commit hash
7. $DECLINE_CONDITION: run \`$RESTORE_STAGING_CMD\` to restore previous staging

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

${GLOBAL_INSTRUCTIONS_SECTION}${PRECONFIRMED_MODE_SECTION}Stage all outstanding changes, then commit.

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

> $BACKUP_NOTE
> To abort: \`$RESTORE_STAGING_CMD\`

"

  OUTPUT_DIFF_INLINE=$(compose_diff_inline "$ALL_DIFF")

  OUTPUT_INSTRUCTIONS="# Instructions

$STAGED_REVIEW_INTRO

1. Review the diff and generate a commit message (imperative summary, optional bullets for distinct changes)
2. Match the style of recent commits shown above
3. $COMMIT_REVIEW_FORMAT
4. $COMMIT_ACTION
5. If the commit was uneventful, report only: \`Completed successfully.\`
6. If hooks, formatters, clippy, errors, or substantial warnings made the commit eventful, summarize those events without reporting the commit hash
7. $DECLINE_CONDITION: run \`$RESTORE_STAGING_CMD\` to restore previous staging

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
    DIFF_FILE="$(make_temp_file commit-tool-diff .txt)"
    echo "$ALL_DIFF" > "$DIFF_FILE"
    DIFF_CHAR_COUNT=${#ALL_DIFF}
    OUTPUT_DIFF_EXTERNAL=$(compose_diff_external "$DIFF_FILE" "$DIFF_CHAR_COUNT")
    FULL_OUTPUT="${OUTPUT_HEADER}${OUTPUT_PRE_DIFF}${OUTPUT_DIFF_EXTERNAL}${OUTPUT_INSTRUCTIONS}"
  fi

  echo -n "$FULL_OUTPUT"
  exit 0
fi

# === MODE: --ask ===

if [[ "$BASE_MODE" == "--ask" ]]; then
  cat <<'EOF'
# Git Commit - Interactive Mode

EOF
  emit_global_instructions
  cat <<'EOF'
Help the user decide what to stage and commit.

EOF

  emit_extra_instructions
  emit_branch_identity

  # Report sections
  emit_report_sections

  if [[ -n "$CONFLICTS" ]]; then
    emit_conflicts_block
    exit 0
  fi

  # Get full status including untracked
  FULL_STATUS=$($GIT_CMD status --porcelain -u 2>/dev/null || true)

  printf '# Working Tree Status\n\n'
  printf 'Output of `%s status --porcelain -u`:\n```\n' "$GIT_CMD"
  printf '%s\n' "${FULL_STATUS:-"(clean)"}"
  printf '```\n\n'

  if [[ -z "$FULL_STATUS" ]]; then
    cat <<'EOF'
# No Changes - STOP

Working tree is clean. Nothing to commit. Inform the user.

EOF
    exit 0
  fi

  printf '# Instructions\n\n'
  cat <<'EOF'
1. **Show the user what's available to commit** - relay the status above (they can't see slash command output):
   - First column: staged status (`M`=modified, `A`=added, `D`=deleted, `R`=renamed)
   - Second column: unstaged status
   - `??` = untracked file
EOF
  cat <<'EOF'
2. **Ask the user** what should be included in this commit:
   - Suggest logical groupings if changes seem separable
   - If user gave additional instructions, use those as guidance
   - Offer options like "all of it", "just the staged", or specific files
EOF
  printf '3. Stage the selected changes (`%s add <files>`)\n' "$GIT_CMD"
  printf '4. **Before generating the commit review**, run `%s status --porcelain -u` to refresh your view of what'\''s staged\n' "$GIT_CMD"
  cat <<'EOF'
5. Generate a commit message (imperative summary, optional bullets)
EOF
  printf '6. %s\n' "$COMMIT_REVIEW_FORMAT"
  printf '7. %s\n' "$COMMIT_ACTION"
  cat <<'EOF'
8. If the commit was uneventful, report only: `Completed successfully.`
9. If hooks, formatters, clippy, errors, or substantial warnings made the commit eventful, summarize those events without reporting the commit hash

# Safety Checks

Stop and warn if selected files include:
- Secrets (`.env`, credentials, API keys, certs)
- Large binaries that look accidental
EOF
  exit 0
fi
