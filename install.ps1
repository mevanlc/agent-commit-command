#!/usr/bin/env pwsh
# install.ps1 - Install agent-commit-skill
#
# Installs shared code to ~/.local/share/agent-commit-skill/ (or creates
# a symlink there pointing to this repo), seeds default configs to
# ~/.config/agent-commit-skill/, and symlinks slash-command .md files
# into the appropriate CLI directories.
#
# Usage:
#   ./install.ps1 [-Codex] [-Claude] [-Copilot] [-Agy] [-DotAgents] [-Hooks] [-Check]
#
# At least one of -Codex, -Claude, -Copilot, -Agy, or -DotAgents is required (multiple may be given).

[CmdletBinding(PositionalBinding = $false)]
param(
  [switch]$Codex,
  [switch]$Claude,
  [switch]$Copilot,
  [switch]$Agy,
  [switch]$DotAgents,
  [switch]$Hooks,
  [switch]$Check,
  [Alias('h')]
  [switch]$Help,
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$RemainingArgs = @()
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Usage {
  Write-Host 'Usage:'
  Write-Host '  ./install.ps1 -Codex [-Hooks] [-Check]'
  Write-Host '  ./install.ps1 -Claude [-Hooks] [-Check]'
  Write-Host '  ./install.ps1 -Copilot [-Hooks] [-Check]'
  Write-Host '  ./install.ps1 -Agy [-Hooks] [-Check]'
  Write-Host '  ./install.ps1 -DotAgents [-Hooks] [-Check]'
  Write-Host '  ./install.ps1 -Codex -Claude -Copilot -Agy -DotAgents [-Hooks] [-Check]'
  Write-Host ''
  Write-Host 'Options:'
  Write-Host '  -Codex      Symlink Codex skill directories into ~/.codex/skills/'
  Write-Host '  -Claude     Symlink Claude slash-command .md files into ~/.claude/commands/'
  Write-Host '  -Copilot    Symlink Copilot skill directories into ~/.copilot/skills/'
  Write-Host '  -Agy        Symlink Antigravity skill directories into ~/.gemini/antigravity-cli/skills/'
  Write-Host '  -DotAgents  Symlink Agent skill directories into ~/.agents/skills/'
  Write-Host '  -Hooks      Also set up preflight hooks in the config directory'
  Write-Host '  -Check      Dry-run: show what would happen without making changes'
  Write-Host ''
  Write-Host 'Paths:'
  Write-Host '  Code:   ~/.local/share/agent-commit-skill/  (symlink to repo)'
  Write-Host '  Config: ~/.config/agent-commit-skill/        (seeded defaults)'
  Write-Host ''
  Write-Host 'Examples:'
  Write-Host '  ./install.ps1 -Codex -Claude -Copilot -Agy -DotAgents -Hooks'
  Write-Host '  ./install.ps1 -DotAgents -Check'
}

if ($Help) {
  Write-Usage
  exit 0
}

if ($RemainingArgs.Count -gt 0) {
  Write-Warning "Unknown option: $($RemainingArgs[0])"
  Write-Host ''
  Write-Usage
  exit 1
}

if (-not $Codex -and -not $Claude -and -not $Copilot -and -not $Agy -and -not $DotAgents) {
  Write-Warning 'At least one of -Codex, -Claude, -Copilot, -Agy, or -DotAgents is required'
  Write-Host ''
  Write-Usage
  exit 1
}

$ScriptDir =
  if ($PSScriptRoot) { $PSScriptRoot }
  else { Split-Path -Parent $MyInvocation.MyCommand.Path }

$HomeDir =
  if ($HOME) { $HOME }
  elseif ($env:USERPROFILE) { $env:USERPROFILE }
  else { [Environment]::GetFolderPath('UserProfile') }

$XdgDataHome =
  if ($env:XDG_DATA_HOME) { $env:XDG_DATA_HOME }
  else { Join-Path $HomeDir '.local' 'share' }

$XdgConfigHome =
  if ($env:XDG_CONFIG_HOME) { $env:XDG_CONFIG_HOME }
  else { Join-Path $HomeDir '.config' }

$CodeDir = Join-Path $XdgDataHome 'agent-commit-skill'
$ConfigDir = Join-Path $XdgConfigHome 'agent-commit-skill'

# === VALIDATION ===

$CommitToolSh = Join-Path $ScriptDir 'commit-tool' 'commit-tool.sh'
if (-not (Test-Path -LiteralPath $CommitToolSh)) {
  throw "Error: missing commit-tool/commit-tool.sh in repo"
}

# === HELPERS ===

$Actions = New-Object System.Collections.Generic.List[string]

function Add-Action {
  param(
    [string]$Action,
    [string]$Target,
    [string]$Detail = ''
  )
  if ($Detail) {
    $Actions.Add("${Action}  ${Target}  (${Detail})") | Out-Null
  } else {
    $Actions.Add("${Action}  ${Target}") | Out-Null
  }
}

function Ensure-Symlink {
  param(
    [string]$LinkPath,
    [string]$Target
  )

  if (Test-Path -LiteralPath $LinkPath) {
    $item = Get-Item -LiteralPath $LinkPath -Force
    if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
      # It's a symlink
      $current = $item.Target
      if ($current -eq $Target) {
        Add-Action -Action 'OK' -Target $LinkPath -Detail 'symlink correct'
        return
      }
      if ($Check) {
        Add-Action -Action 'UPDATE' -Target $LinkPath -Detail "symlink -> $Target"
        return
      }
      Remove-Item -LiteralPath $LinkPath -Force
      New-Item -ItemType SymbolicLink -Path $LinkPath -Target $Target -Force | Out-Null
      Add-Action -Action 'UPDATE' -Target $LinkPath -Detail "symlink -> $Target"
    } else {
      Add-Action -Action 'SKIP' -Target $LinkPath -Detail 'exists as regular file; remove manually to switch to symlink'
    }
  } else {
    if ($Check) {
      Add-Action -Action 'CREATE' -Target $LinkPath -Detail "symlink -> $Target"
      return
    }
    $parentDir = Split-Path -Parent $LinkPath
    if (-not (Test-Path -LiteralPath $parentDir)) {
      New-Item -ItemType Directory -Force -Path $parentDir | Out-Null
    }
    New-Item -ItemType SymbolicLink -Path $LinkPath -Target $Target -Force | Out-Null
    Add-Action -Action 'CREATE' -Target $LinkPath -Detail "symlink -> $Target"
  }
}

function Seed-Config {
  param(
    [string]$Source,
    [string]$Destination
  )

  if (Test-Path -LiteralPath $Destination) {
    $srcHash = (Get-FileHash -LiteralPath $Source -Algorithm SHA256).Hash
    $dstHash = (Get-FileHash -LiteralPath $Destination -Algorithm SHA256).Hash
    if ($srcHash -eq $dstHash) {
      Add-Action -Action 'OK' -Target $Destination -Detail 'config unchanged'
    } else {
      Add-Action -Action 'SKIP' -Target $Destination -Detail 'config exists, not overwriting'
    }
    return
  }

  if ($Check) {
    Add-Action -Action 'SEED' -Target $Destination -Detail "from $Source"
    return
  }

  $parentDir = Split-Path -Parent $Destination
  if (-not (Test-Path -LiteralPath $parentDir)) {
    New-Item -ItemType Directory -Force -Path $parentDir | Out-Null
  }
  Copy-Item -LiteralPath $Source -Destination $Destination
  Add-Action -Action 'SEED' -Target $Destination -Detail 'default config'
}

# === CODE_DIR: ensure ~/.local/share/agent-commit-skill points to this repo ===

$ScriptReal = (Resolve-Path -LiteralPath $ScriptDir).Path
$CodeReal = $null
if (Test-Path -LiteralPath $CodeDir) {
  try { $CodeReal = (Resolve-Path -LiteralPath $CodeDir).Path } catch {}
}

if ($ScriptReal -eq $CodeReal) {
  Add-Action -Action 'OK' -Target $CodeDir -Detail 'already points to repo'
} elseif ((Test-Path -LiteralPath $CodeDir) -and ((Get-Item -LiteralPath $CodeDir -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)) {
  if ($Check) {
    Add-Action -Action 'UPDATE' -Target $CodeDir -Detail "symlink -> $ScriptDir"
  } else {
    Remove-Item -LiteralPath $CodeDir -Force
    New-Item -ItemType SymbolicLink -Path $CodeDir -Target $ScriptDir -Force | Out-Null
    Add-Action -Action 'UPDATE' -Target $CodeDir -Detail "symlink -> $ScriptDir"
  }
} elseif (Test-Path -LiteralPath $CodeDir) {
  throw "$CodeDir exists but is not this repo and not a symlink. Remove it manually or clone this repo directly to $CodeDir"
} else {
  if ($Check) {
    Add-Action -Action 'CREATE' -Target $CodeDir -Detail "symlink -> $ScriptDir"
  } else {
    $parentDir = Split-Path -Parent $CodeDir
    if (-not (Test-Path -LiteralPath $parentDir)) {
      New-Item -ItemType Directory -Force -Path $parentDir | Out-Null
    }
    New-Item -ItemType SymbolicLink -Path $CodeDir -Target $ScriptDir -Force | Out-Null
    Add-Action -Action 'CREATE' -Target $CodeDir -Detail "symlink -> $ScriptDir"
  }
}

# === CONFIG_DIR: seed default configs ===

if (-not $Check) {
  New-Item -ItemType Directory -Force -Path $ConfigDir | Out-Null
}

Seed-Config -Source (Join-Path $ScriptDir 'defaults' 'commit-tool.config') -Destination (Join-Path $ConfigDir 'commit-tool.config')

# === HOOKS ===

if ($Hooks) {
  if (-not $Check) {
    New-Item -ItemType Directory -Force -Path (Join-Path $ConfigDir 'hooks') | Out-Null
  }

  $hooksAvail = Join-Path $ScriptDir 'commit-tool' 'hooks-available'
  Get-ChildItem -LiteralPath $hooksAvail -Filter 'hook-*.sh' -File -ErrorAction SilentlyContinue | ForEach-Object {
    Ensure-Symlink -LinkPath (Join-Path $ConfigDir 'hooks' $_.Name) -Target $_.FullName

    $configName = $_.Name -replace '\.sh$', '.config'
    $defaultConfig = Join-Path $ScriptDir 'defaults' 'hooks' $configName
    if (Test-Path -LiteralPath $defaultConfig) {
      Seed-Config -Source $defaultConfig -Destination (Join-Path $ConfigDir 'hooks' $configName)
    }
  }
}

# === CODEX SKILL SYMLINKS ===

if ($Codex) {
  $CodexDir = Join-Path $HomeDir '.codex' 'skills'
  if (-not $Check) {
    New-Item -ItemType Directory -Force -Path $CodexDir | Out-Null
  }

  Get-ChildItem -LiteralPath (Join-Path $ScriptDir 'codex' 'skills') -Directory -ErrorAction Stop | ForEach-Object {
    Ensure-Symlink -LinkPath (Join-Path $CodexDir $_.Name) -Target $_.FullName
  }
}

# === COPILOT SKILL SYMLINKS ===

if ($Copilot) {
  $CopilotDir = Join-Path $HomeDir '.copilot' 'skills'
  if (-not $Check) {
    New-Item -ItemType Directory -Force -Path $CopilotDir | Out-Null
  }

  Get-ChildItem -LiteralPath (Join-Path $ScriptDir 'codex' 'skills') -Directory -ErrorAction Stop | ForEach-Object {
    Ensure-Symlink -LinkPath (Join-Path $CopilotDir $_.Name) -Target $_.FullName
  }
}

# === ANTIGRAVITY (AGY) SKILL SYMLINKS ===

if ($Agy) {
  $AgyDir = Join-Path $HomeDir '.gemini' 'antigravity-cli' 'skills'
  if (-not $Check) {
    New-Item -ItemType Directory -Force -Path $AgyDir | Out-Null
  }

  Get-ChildItem -LiteralPath (Join-Path $ScriptDir 'codex' 'skills') -Directory -ErrorAction Stop | ForEach-Object {
    Ensure-Symlink -LinkPath (Join-Path $AgyDir $_.Name) -Target $_.FullName
  }
}

# === DOTAGENTS SKILL SYMLINKS ===

if ($DotAgents) {
  $DotAgentsDir = Join-Path $HomeDir '.agents' 'skills'
  if (-not $Check) {
    New-Item -ItemType Directory -Force -Path $DotAgentsDir | Out-Null
  }

  Get-ChildItem -LiteralPath (Join-Path $ScriptDir 'codex' 'skills') -Directory -ErrorAction Stop | ForEach-Object {
    Ensure-Symlink -LinkPath (Join-Path $DotAgentsDir $_.Name) -Target $_.FullName
  }
}

# === CLAUDE .md SYMLINKS ===

if ($Claude) {
  $ClaudeDir = Join-Path $HomeDir '.claude' 'commands'
  if (-not $Check) {
    New-Item -ItemType Directory -Force -Path $ClaudeDir | Out-Null
  }

  Get-ChildItem -LiteralPath (Join-Path $ScriptDir 'claude' 'commands') -Filter '*.md' -File -ErrorAction Stop | ForEach-Object {
    Ensure-Symlink -LinkPath (Join-Path $ClaudeDir $_.Name) -Target $_.FullName
  }
}

# === SUMMARY ===

if ($Check) {
  Write-Host '=== Dry Run ==='
} else {
  Write-Host '=== Installation Complete ==='
}

Write-Host ''
foreach ($action in $Actions) {
  Write-Host "  $action"
}
Write-Host ''

if ($Check) {
  Write-Host 'Run without -Check to apply these changes.'
}
