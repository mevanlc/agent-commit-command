---
name: commit
description: Git commit helper that runs `commit-tool.sh` with the `git` base command, produces a structured Commit Review, and requires explicit user confirmation before creating the commit. Use when the user wants to commit staged changes, all changes, or wants the helper to guide the scope choice with `--ask`.
---

# Commit

Use this skill to invoke `~/.local/share/agent-commit-command/commit-tool/commit-tool.sh` with the `git` base command. Parse the user's latest request to extract one required mode flag, plus any extra commit instructions; skills do not receive a separate `$ARGUMENTS` placeholder.

## Required Mode

Accept exactly one of:

- `--staged`
- `--all`
- `--ask`

If no mode is present in the user's request, ask the user to provide one.

## Command

Run:

```sh
~/.local/share/agent-commit-command/commit-tool/commit-tool.sh git "<derived args>"
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

## Windows

On Windows, assume this workflow runs via Git Bash. If Git Bash is unavailable, stop and inform the user.
