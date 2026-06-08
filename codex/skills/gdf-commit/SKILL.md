---
name: gdf-commit
description: Git commit helper. Use only when explicitly invoked.
---

# Gdf Commit

Use this skill to invoke `~/.local/share/agent-commit-command/commit-tool/commit-tool.sh` with the `gdf` base command. Parse the user's latest request to extract one required mode flag, plus any extra commit instructions; skills do not receive a separate `$ARGUMENTS` placeholder.

## gdf Requirement

- Use `gdf` for all git operations in this workflow.
- Do not fall back to raw `git` without first discussing it with the user.
- If `gdf` is unavailable or behaves unexpectedly, stop immediately and report the exact issue.

## Required Mode

Accept exactly one of:

- `--staged`
- `--all`
- `--ask`

If no mode is present in the user's request, ask the user to provide one.

## Command

Run:

```sh
~/.local/share/agent-commit-command/commit-tool/commit-tool.sh gdf "<derived args>"
```

Build `<derived args>` from the actual user request. Include the chosen mode first, then any additional freeform instructions.

## Workflow

1. Verify the helper path exists. If it does not, tell the user to install or upgrade the tool.
2. Derive the argument string from the latest user request.
3. Run the helper script.
4. Follow the helper output exactly.
5. If it says `STOP`, stop and help the user resolve the issue first.
6. Present the requested Commit Review and wait for explicit user confirmation before running any commit command.
7. If confirmed, perform the commit exactly as instructed and show the resulting commit hash.
8. If the helper requests heredoc-based commit input, put only the commit message in the heredoc and run the hash command (`gdf rev-parse HEAD` here) in a separate shell command.

## Windows

On Windows, assume this workflow runs via Git Bash. If Git Bash is unavailable, stop and inform the user.
