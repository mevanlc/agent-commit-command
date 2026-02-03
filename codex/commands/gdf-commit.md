---
description: Git commit helper (using gdf wrapper via commit-tool.sh)
argument-hint: --<staged|all|ask> [additional instructions]
---

## IMPORTANT: Use the `gdf` command instead of the `git` command

You MUST use the `gdf` command (a wrapper around git) for all git operations in this workflow.
Do not use raw `git` commands directly without first discussing with the user.

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
~/.codex/commands/commit-tool/commit-tool.sh gdf "$ARGUMENTS"
```

If that path does not exist, tell the user to install/upgrade the tool into `~/.codex/commands/commit-tool/` and then retry.

Recommended install (from this repo):

```sh
./install.sh --codex --upgrade-sh --upgrade-md
```

Then follow the script’s output exactly:
- If it says **STOP**, stop and help the user resolve the issue first.
- Present the requested **Commit Review** and wait for explicit user confirmation before running any commit command.
- If confirmed, perform the commit as instructed (use the heredoc format) and show the resulting commit hash.

If `$ARGUMENTS` is empty, ask the user to provide a required mode: `--staged`, `--all`, or `--ask`.
