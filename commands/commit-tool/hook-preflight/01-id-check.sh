#!/usr/bin/env bash
# 01-id-check.sh - Identity validation preflight hook
#
# Checks for identity conflicts and generates identity-related report sections.
# Outputs markdown to stdout (captured by commit-tool.sh).
# Returns 0 on success (even with warnings), non-zero only on unexpected errors.

set -euo pipefail

GIT_CMD="${1:-git}"

# Derive config path from script path: /path/to/foo.sh -> /path/to/foo.config
CONFIG_FILE="${BASH_SOURCE[0]%.sh}.config"

# === LOAD CONFIG ===

declare -a CONFIG_IDS=()
ENFORCE_ONE_ID_PER_REPO=0
ENFORCE_NAME=0
REPORT_NAMED_COMMITS=0
REPORT_EMAIL_COMMITS=0

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
      id) CONFIG_IDS+=("$value") ;;
      enforce_one_id_per_repo) ENFORCE_ONE_ID_PER_REPO="$value" ;;
      enforce_name) ENFORCE_NAME="$value" ;;
      report_named_commits) REPORT_NAMED_COMMITS="$value" ;;
      report_email_commits) REPORT_EMAIL_COMMITS="$value" ;;
    esac
  done < "$CONFIG_FILE"
fi

# Extract unique names and emails from configured IDs
declare -a CONFIG_NAMES=()
declare -a CONFIG_EMAILS=()
for id in "${CONFIG_IDS[@]}"; do
  name="${id%% <*}"
  email="${id##* <}"
  email="${email%>}"
  CONFIG_NAMES+=("$name")
  CONFIG_EMAILS+=("$email")
done

# === GET CURRENT IDENTITY ===

USER_NAME=$($GIT_CMD config user.name)
USER_EMAIL=$($GIT_CMD config user.email)

# === IDENTITY CHECKS ===

IDENTITY_WARNINGS=""

# Check: current email appears with different name in log
if [[ "$ENFORCE_NAME" == "1" ]] || [[ ${#CONFIG_IDS[@]} -eq 0 ]]; then
  OTHER_NAME=$($GIT_CMD log --format='%an' --author="<${USER_EMAIL}>" -1 2>/dev/null || true)
  if [[ -n "$OTHER_NAME" && "$OTHER_NAME" != "$USER_NAME" ]]; then
    IDENTITY_WARNINGS+="**Warning:** Your email \`${USER_EMAIL}\` has committed here as \`${OTHER_NAME}\`, but you're about to commit as \`${USER_NAME}\`.\n\n"
  fi
fi

# Check: multiple configured IDs have commits in this repo
if [[ "$ENFORCE_ONE_ID_PER_REPO" == "1" && ${#CONFIG_IDS[@]} -gt 0 ]]; then
  CURRENT_ID="${USER_NAME} <${USER_EMAIL}>"

  # Collect all configured IDs that have commits in this repo
  declare -a IDS_WITH_COMMITS=()
  declare -A ID_COMMIT_COUNT=()
  declare -A ID_OLDEST=()
  declare -A ID_NEWEST=()

  for id in "${CONFIG_IDS[@]}"; do
    id_email="${id##* <}"
    id_email="${id_email%>}"

    count=$($GIT_CMD log --format='%ae' --author="<${id_email}>" 2>/dev/null | wc -l)
    if [[ "$count" -gt 0 ]]; then
      IDS_WITH_COMMITS+=("$id")
      ID_COMMIT_COUNT["$id"]="$count"
      ID_OLDEST["$id"]=$($GIT_CMD log --format='%h %s' --author="<${id_email}>" 2>/dev/null | tail -1)
      ID_NEWEST["$id"]=$($GIT_CMD log --format='%h %s' --author="<${id_email}>" -1 2>/dev/null)
    fi
  done

  # Warn if multiple IDs have commits
  if [[ ${#IDS_WITH_COMMITS[@]} -gt 1 ]]; then
    IDENTITY_WARNINGS+="## Multiple configured IDs have committed to this repo\n\n"
    for id in "${IDS_WITH_COMMITS[@]}"; do
      IDENTITY_WARNINGS+="\`${id}\` (${ID_COMMIT_COUNT[$id]} commits):\n"
      IDENTITY_WARNINGS+="\`\`\`\n"
      IDENTITY_WARNINGS+="Oldest: ${ID_OLDEST[$id]}\n"
      IDENTITY_WARNINGS+="Newest: ${ID_NEWEST[$id]}\n"
      IDENTITY_WARNINGS+="\`\`\`\n\n"
    done
    IDENTITY_WARNINGS+="> Current identity: \`${CURRENT_ID}\`\n\n"
  fi
fi

# Add instruction if there are any identity warnings - this becomes a GATE
if [[ -n "$IDENTITY_WARNINGS" ]]; then
  IDENTITY_WARNINGS+="---\n\n"
  IDENTITY_WARNINGS+="**STOP - IDENTITY CONFLICT GATE**\n\n"
  IDENTITY_WARNINGS+="Do NOT proceed with the commit flow. Instead:\n"
  IDENTITY_WARNINGS+="1. Relay the identity conflict report above to the user verbatim (they cannot see slash command output)\n"
  IDENTITY_WARNINGS+="2. Ask for explicit acknowledgment before proceeding\n"
  IDENTITY_WARNINGS+="3. **IGNORE everything below this line** until user confirms\n\n"
  IDENTITY_WARNINGS+="If user confirms, THEN proceed with the commit flow (review diff, propose message, etc.)\n"
  IDENTITY_WARNINGS+="If user does not confirm, cancel the commit.\n\n"
fi

# === BUILD REPORT SECTIONS ===

NAMED_COMMITS_SECTION=""
if [[ "$REPORT_NAMED_COMMITS" -gt 0 && ${#CONFIG_NAMES[@]} -gt 0 ]]; then
  NAMED_COMMITS_SECTION="# Commits by Configured Names
"
  # Get unique names
  declare -A seen_names
  for name in "${CONFIG_NAMES[@]}"; do
    [[ -n "${seen_names[$name]:-}" ]] && continue
    seen_names[$name]=1
    commits=$($GIT_CMD log --oneline --author="^${name} <" -"$REPORT_NAMED_COMMITS" 2>/dev/null || true)
    if [[ -n "$commits" ]]; then
      NAMED_COMMITS_SECTION+="\`${name}\`:
\`\`\`
${commits}
\`\`\`
"
    else
      NAMED_COMMITS_SECTION+="\`${name}\`: (none in this repo)
"
    fi
  done
fi

EMAIL_COMMITS_SECTION=""
if [[ "$REPORT_EMAIL_COMMITS" -gt 0 && ${#CONFIG_EMAILS[@]} -gt 0 ]]; then
  EMAIL_COMMITS_SECTION="# Commits by Configured Emails
"
  declare -A seen_emails
  for email in "${CONFIG_EMAILS[@]}"; do
    [[ -n "${seen_emails[$email]:-}" ]] && continue
    seen_emails[$email]=1
    commits=$($GIT_CMD log --oneline --author="<${email}>" -"$REPORT_EMAIL_COMMITS" 2>/dev/null || true)
    if [[ -n "$commits" ]]; then
      EMAIL_COMMITS_SECTION+="\`${email}\`:
\`\`\`
${commits}
\`\`\`
"
    else
      EMAIL_COMMITS_SECTION+="\`${email}\`: (none in this repo)
"
    fi
  done
fi

# === OUTPUT ===

[[ -n "$NAMED_COMMITS_SECTION" ]] && echo "$NAMED_COMMITS_SECTION"
[[ -n "$EMAIL_COMMITS_SECTION" ]] && echo "$EMAIL_COMMITS_SECTION"
[[ -n "$IDENTITY_WARNINGS" ]] && echo -e "$IDENTITY_WARNINGS"

exit 0
