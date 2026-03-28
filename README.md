# agent-commit-command

Git commit helper for AI coding CLIs (Codex CLI + Claude Code).

This repo provides:
- Codex skills (`$commit`, `$gdf-commit`) and Claude slash commands (`/commit`, `/gdf-commit`)
- A shared bash helper, `commit-tool/commit-tool.sh`, that prints a structured **Commit Review** workflow and requires explicit user confirmation before committing
- Optional preflight hooks (for example, identity checks)

## Install

The installers:
- Symlink `~/.local/share/agent-commit-command` to this repo (or fail if that path exists as a non-symlink directory)
- Seed defaults into `~/.config/agent-commit-command/` (never overwrites existing config)
- Symlink command artifacts into:
  - Codex CLI: `~/.codex/skills/`
  - Claude Code: `~/.claude/commands/`

### macOS/Linux (bash)

```bash
./install.sh --codex --claude --hooks
./install.sh --codex --check
```

### Windows (PowerShell)

```powershell
./install.ps1 -Codex -Claude -Hooks
./install.ps1 -Codex -Check
```

Notes:
- The commit helper is a bash script; on Windows this workflow is intended to run via Git Bash.
- Creating symlinks on Windows may require Developer Mode or elevated privileges.

## Usage

After installation, use these in your agent CLI:

Codex:

```text
$commit --staged [additional instructions...]
$commit --all [additional instructions...]
$commit --ask [additional instructions...]
```

If you use a `gdf` git wrapper and want *all* git operations to go through it:

```text
$gdf-commit --staged|--all|--ask [additional instructions...]
```

Claude:

```text
/commit --staged [additional instructions...]
/commit --all [additional instructions...]
/commit --ask [additional instructions...]
/gdf-commit --staged|--all|--ask [additional instructions...]
```

For large diffs, the helper may write the diff to a temp file under `/tmp/` to avoid CLI output truncation and will instruct you to delete it after review.

## Configuration

Config location (default): `~/.config/agent-commit-command/`

- `commit-tool.config`
  - `report_recent_commits=5` (set `0` to disable)
- Hooks (installed with `--hooks` / `-Hooks`): `~/.config/agent-commit-command/hooks/`
  - `hook-preflight-01-id-check.sh` and `hook-preflight-01-id-check.config`

Override the config directory by setting `AGENT_COMMIT_CONFIG_DIR`.

## Development

Run tests (requires bash + git):

```bash
bash test/run_all.sh
```
