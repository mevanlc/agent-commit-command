---
description: Git commit helper (via commit-tool.sh)
argument-hint: --<staged|all|ask> [additional instructions]
---

Run the commit helper script, passing the full user arguments as a *single* quoted string:

```sh
~/.codex/commands/commit-tool/commit-tool.sh git "$ARGUMENTS"
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
