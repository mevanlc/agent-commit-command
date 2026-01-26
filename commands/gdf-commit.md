---
name: gdf-commit
description: Git commit helper (using gdf wrapper)
argument-hint: --<staged|all|ask> [additional instructions]
---

## IMPORTANT: Use the `gdf` command instead of the `git` command

You MUST use the `gdf` command (a wrapper around git) for all git operations in this workflow.
Do not use raw `git` commands directly without first discussing with the user.

If `gdf`:
- is unavailable
- returns an unexpected error
- or behaves unexpectedly:
1. **STOP immediately** - do not fall back to using `git` directly
2. **Report the issue** to the user with the exact error or unexpected behavior
3. **Wait for user guidance** before proceeding

---

!`~/.claude/commands/commit-tool.sh gdf "$ARGUMENTS"`
