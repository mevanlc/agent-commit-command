---
description: Git commit helper (using gdf wrapper via commit-tool.sh)
argument-hint: --<staged|all|ask> [additional instructions]
---

# IMPORTANT: Use the `gdf` base command instead of the `git` base command
You MUST use the `gdf` command (a wrapper around git) for all git operations in this workflow.
Do not use raw `git` commands directly without first discussing with the user.

# Instructions
If `gdf`:
- is unavailable
- returns an unexpected error
- or behaves unexpectedly:
1. STOP immediately — do not fall back to using `git` directly
2. Report the issue to the user with the exact error or unexpected behavior
3. Wait for user guidance before proceeding

---

Run the commit helper script, passing the full user arguments as a *single* quoted string:

```sh
~/.local/share/agent-commit-command/commit-tool/commit-tool.sh gdf "$ARGUMENTS"
```

If that path does not exist, tell the user to install/upgrade the tool. See the agent-commit-command repo README for setup instructions.

Then follow the script’s output exactly:
- If it says **STOP**, stop and help the user resolve the issue first.
- Present the requested **Commit Review** and wait for explicit user confirmation before running any commit command.
- If confirmed, perform the commit as instructed (use the heredoc format) and show the resulting commit hash.

If the text inside the following backticks is empty: `$ARGUMENTS`
Stop and ask the user to provide the required mode: `--staged`, `--all`, or `--ask`.

# Note when running on a Windows shell (pwsh)
On Windows this command has only been tested with Git Bash. If Git Bash is not available, STOP and inform the user.
Assume the command is functioning (execute without testing for existence).
```
& "C:\Program Files\Git\bin\bash.exe" ~/.local/share/agent-commit-command/commit-tool/commit-tool.sh gdf "$ARGUMENTS"
```
## Windows (pwsh) + Git Bash: heredoc-safe pattern
You can use this command syntax literally as written.
It does not require any extra escaping or quoting.
```powershell
& "C:\Program Files\Git\bin\bash.exe" -lc @'
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
cat <<'EOF' | git commit -F -
commit summary
  - commit detail 1
  - commit detail N
EOF
git rev-parse HEAD
'@
```
