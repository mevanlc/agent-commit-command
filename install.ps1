#!/usr/bin/env pwsh
# install.ps1 - Install slash commands + commit-tool
#
# Usage:
#   ./install.ps1 --codex [--hooks] [--upgrade-sh] [--upgrade-md]
#   ./install.ps1 --claude [--hooks] [--upgrade-sh] [--upgrade-md]
#   ./install.ps1 <srcdir> <dstdir> [--hooks] [--upgrade-sh] [--upgrade-md]
#
# Where:
#   srcdir: repo subdir containing ./commands (e.g. ./codex or ./claude)
#   dstdir: base config dir (e.g. ~/.codex/ or ~/.claude/)

[CmdletBinding(PositionalBinding = $false)]
param(
  [switch]$Codex,
  [switch]$Claude,
  [switch]$Hooks,
  [Alias('upgrade-sh')]
  [switch]$UpgradeSh,
  [Alias('upgrade-md')]
  [switch]$UpgradeMd,
  [Alias('h')]
  [switch]$Help,
  [Parameter(Position = 0)]
  [string]$SrcDir,
  [Parameter(Position = 1)]
  [string]$DstDir,
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$RemainingArgs = @()
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Usage {
  Write-Host 'Usage:'
  Write-Host '  ./install.ps1 --codex [--hooks] [--upgrade-sh] [--upgrade-md]'
  Write-Host '  ./install.ps1 --claude [--hooks] [--upgrade-sh] [--upgrade-md]'
  Write-Host '  ./install.ps1 <srcdir> <dstdir> [--hooks] [--upgrade-sh] [--upgrade-md]'
  Write-Host ''
  Write-Host 'Examples:'
  Write-Host '  ./install.ps1 --codex --upgrade-sh --upgrade-md'
  Write-Host '  ./install.ps1 --claude --hooks'
  Write-Host '  ./install.ps1 ./codex ~/.codex/ --upgrade-sh --upgrade-md'
}

if ($Help) {
  Write-Usage
  exit 0
}

if ($RemainingArgs.Count -gt 0) {
  [Console]::Error.WriteLine("Unknown option: $($RemainingArgs[0])")
  exit 1
}

$ScriptDir =
  if ($PSScriptRoot) { $PSScriptRoot }
  else { Split-Path -Parent $MyInvocation.MyCommand.Path }

$HomeDir =
  if ($HOME) { $HOME }
  elseif ($env:USERPROFILE) { $env:USERPROFILE }
  else { [Environment]::GetFolderPath('UserProfile') }

if ($Codex -and $Claude) {
  throw "Error: choose only one of --codex or --claude"
}

if (($Codex -or $Claude) -and ($SrcDir -or $DstDir)) {
  throw "Error: do not combine --codex/--claude with <srcdir> <dstdir>"
}

$SourceRoot = $SrcDir
$DestRoot = $DstDir
if ($Codex) {
  $SourceRoot = Join-Path $ScriptDir 'codex'
  $DestRoot = Join-Path $HomeDir '.codex'
} elseif ($Claude) {
  $SourceRoot = Join-Path $ScriptDir 'claude'
  $DestRoot = Join-Path $HomeDir '.claude'
} else {
  if (-not $SourceRoot -or -not $DestRoot) {
    Write-Usage
    throw "Error: expected <srcdir> <dstdir> or --codex/--claude"
  }
}

$SrcCommands = Join-Path $SourceRoot 'commands'
if (-not (Test-Path -LiteralPath $SrcCommands)) {
  throw "Missing expected source directory: $SrcCommands"
}

$CommitToolSrc = Join-Path $ScriptDir 'commit-tool'
if (-not (Test-Path -LiteralPath (Join-Path $CommitToolSrc 'commit-tool.sh'))) {
  throw "Missing expected file: $(Join-Path $CommitToolSrc 'commit-tool.sh')"
}
if (-not (Test-Path -LiteralPath (Join-Path $CommitToolSrc 'commit-tool.config'))) {
  throw "Missing expected file: $(Join-Path $CommitToolSrc 'commit-tool.config')"
}

$DestCommands = Join-Path $DestRoot 'commands'
$DestTool = Join-Path $DestCommands 'commit-tool'
New-Item -ItemType Directory -Force -Path $DestCommands | Out-Null
New-Item -ItemType Directory -Force -Path $DestTool | Out-Null

$Installed = New-Object System.Collections.Generic.List[string]
$Skipped = New-Object System.Collections.Generic.List[string]

function Get-CanOverwrite {
  param([Parameter(Mandatory = $true)][string]$PathOrName)
  $ext = [IO.Path]::GetExtension($PathOrName).ToLowerInvariant()
  switch ($ext) {
    '.sh' { return [bool]$UpgradeSh }
    '.md' { return [bool]$UpgradeMd }
    '.config' { return $false } # Never overwrite config files
    default { return $false }
  }
}

function Copy-FileControlled {
  param(
    [Parameter(Mandatory = $true)][string]$Source,
    [Parameter(Mandatory = $true)][string]$Destination,
    [Parameter(Mandatory = $true)][bool]$CanOverwrite
  )

  if (Test-Path -LiteralPath $Destination) {
    if ($CanOverwrite) {
      Copy-Item -LiteralPath $Source -Destination $Destination -Force
      $Installed.Add("$Destination (overwritten)") | Out-Null
    } else {
      $Skipped.Add("$Destination (exists)") | Out-Null
    }
    return
  }

  Copy-Item -LiteralPath $Source -Destination $Destination
  $Installed.Add($Destination) | Out-Null
}

Get-ChildItem -LiteralPath $SrcCommands -Filter '*.md' -File -ErrorAction Stop | ForEach-Object {
  $dest = Join-Path $DestCommands $_.Name
  Copy-FileControlled -Source $_.FullName -Destination $dest -CanOverwrite (Get-CanOverwrite -PathOrName $_.Name)
}

Copy-FileControlled `
  -Source (Join-Path $CommitToolSrc 'commit-tool.sh') `
  -Destination (Join-Path $DestTool 'commit-tool.sh') `
  -CanOverwrite (Get-CanOverwrite -PathOrName 'commit-tool.sh')

Copy-FileControlled `
  -Source (Join-Path $CommitToolSrc 'commit-tool.config') `
  -Destination (Join-Path $DestTool 'commit-tool.config') `
  -CanOverwrite (Get-CanOverwrite -PathOrName 'commit-tool.config')

if ($Hooks) {
  Get-ChildItem -LiteralPath $CommitToolSrc -File -ErrorAction Stop |
    Where-Object { $_.Name -like 'hook-*.sh' -or $_.Name -like 'hook-*.config' } |
    ForEach-Object {
      $dest = Join-Path $DestTool $_.Name
      Copy-FileControlled -Source $_.FullName -Destination $dest -CanOverwrite (Get-CanOverwrite -PathOrName $_.Name)
    }
}

Write-Host 'Installation complete.'
Write-Host ''

if ($Installed.Count -gt 0) {
  Write-Host 'Installed:'
  foreach ($item in $Installed) { Write-Host "  $item" }
}

if ($Skipped.Count -gt 0) {
  Write-Host ''
  Write-Host 'Skipped (use --upgrade-sh/-UpgradeSh or --upgrade-md/-UpgradeMd to overwrite):'
  foreach ($item in $Skipped) { Write-Host "  $item" }
}

