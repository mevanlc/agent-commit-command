---
name: commit
description: Git commit helper. Use only when explicitly invoked. Do not consult memories.
---

You do not need to announce that you are about to use the skill, just use it.
You do not need to probe for the existence of the commit- script prior to
calling it, just call it. Report after-the-fact failures, if any.

# Commit

Use this skill to invoke `~/.local/share/agent-commit-command/commit-tool/commit-tool.sh` with the `git` base command. Parse the user's latest request to extract one required mode flag, plus any extra commit instructions; skills do not receive a separate `$ARGUMENTS` placeholder.

## Required Mode

Accept exactly one of:

- `--staged`
- `--staged-yes`
- `--all`
- `--all-yes`
- `--ask`
- `--ask-no`

Every mode except `--ask-no` also accepts a `-push` suffix: `--staged-push`,
`--staged-yes-push`, `--all-push`, `--all-yes-push`, `--ask-push`.

If no mode is present in the user's request, ask the user to provide one.

## Command

Run:

```sh
~/.local/share/agent-commit-command/commit-tool/commit-tool.sh git "<derived args>"
```

Build `<derived args>` from the actual user request. Include the chosen mode first, then any additional freeform instructions.

## Preconfirmed Modes

`--staged-yes` and `--all-yes` allow the user to make a quicker commit by
preanswering `y` to the `y/n` commit gate. Still present the Commit Review, then
commit without waiting for the user to reply.

Because the user will not have an opportunity to decline the commit, be
slightly more wary of unusual files and similar concerns. If you find such a
concern, drop out of preconfirmed mode and resolve it interactively with the
user. Once dropped, do not re-enter preconfirmed mode; use the ordinary `y/n`
commit gate before committing. Preconfirmed mode is engaged only when the user
selects `--staged-yes` or `--all-yes` at skill-invocation time.

If a pre-commit hook rejects the commit for a mechanical, low-risk issue, you
may fix it and retry while preconfirmed mode remains engaged. For a more
substantial pre-commit hook issue, drop out of preconfirmed mode and involve the
user interactively.

## Push Modes

A `-push` suffix is the user's clear and affirmative instruction to push after
the commit lands, and the helper output spells out the rules. In short: push
only once the commit has actually succeeded, push the current branch only, stop
and ask before creating an upstream for a branch that has none, and never
force-push, reset, rebase, or amend to force a rejected push through.

## Workflow

1. Verify the helper path exists. If it does not, tell the user to install or upgrade the tool.
2. Derive the argument string from the latest user request.
3. Run the helper script.
4. Follow the helper output exactly.
5. If it says `STOP`, stop and help the user resolve the issue first.
6. Present the requested Commit Review. In ordinary modes, wait for explicit user confirmation before running any commit command; in a preconfirmed mode, proceed as instructed without waiting.
7. Once confirmed or while preconfirmed mode remains engaged, perform the commit exactly as instructed. If the commit was uneventful, the final response may be exactly `Completed successfully.`
8. If hooks, formatters, clippy, errors, or substantial warnings made the commit eventful, relay those events. Do not report the commit hash unless the user asks for it.
9. If the helper requests heredoc-based commit input, put only the commit message in the heredoc. Do not put follow-up commands inside the heredoc.

## Windows

On Windows, assume this workflow runs via Git Bash. If Git Bash is unavailable, stop and inform the user.
