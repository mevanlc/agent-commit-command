#!/usr/bin/env pwsh
# install.ps1 - Install commit-tool to ~/.claude/commands
#
# Supports both Windows PowerShell 5.1 and PowerShell 7+.
#
# Usage: install.ps1 [options]
#   --hooks       Also install hook-*.{sh,config} files
#   --upgrade-sh  Overwrite existing .sh files (not .config)
#   --upgrade-md  Overwrite existing .md files (not .config)
#
# Options can be combined.

[CmdletBinding(PositionalBinding = $false)]
param(
  [switch]$Hooks,
  [Alias('upgrade-sh')]
  [switch]$UpgradeSh,
  [Alias('upgrade-md')]
  [switch]$UpgradeMd,
  [Alias('h')]
  [switch]$Help,
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$RemainingArgs = @()
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Usage {
  Write-Host 'Usage: install.ps1 [--hooks] [--upgrade-sh] [--upgrade-md]'
  Write-Host ''
  Write-Host 'Options:'
  Write-Host '  --hooks       Also install hook-*.{sh,config} files'
  Write-Host '  --upgrade-sh  Overwrite existing .sh files (not .config)'
  Write-Host '  --upgrade-md  Overwrite existing .md files (not .config)'
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

$SrcCommands = Join-Path $ScriptDir 'commands'
if (-not (Test-Path -LiteralPath $SrcCommands)) {
  throw "Missing expected directory: $SrcCommands"
}

$HomeDir =
  if ($HOME) { $HOME }
  elseif ($env:USERPROFILE) { $env:USERPROFILE }
  else { [Environment]::GetFolderPath('UserProfile') }

# Join-Path with 3+ segments relies on -AdditionalChildPath (not in Windows PowerShell 5.1).
$DestBase = Join-Path (Join-Path $HomeDir '.claude') 'commands'
$DestTool = Join-Path $DestBase 'commit-tool'

New-Item -ItemType Directory -Force -Path $DestBase | Out-Null
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

# Install .md files to commands/
Get-ChildItem -LiteralPath $SrcCommands -Filter '*.md' -File -ErrorAction Stop | ForEach-Object {
  $dest = Join-Path $DestBase $_.Name
  Copy-FileControlled -Source $_.FullName -Destination $dest -CanOverwrite (Get-CanOverwrite -PathOrName $_.Name)
}

$CommitToolDir = Join-Path $SrcCommands 'commit-tool'
Copy-FileControlled `
  -Source (Join-Path $CommitToolDir 'commit-tool.sh') `
  -Destination (Join-Path $DestTool 'commit-tool.sh') `
  -CanOverwrite (Get-CanOverwrite -PathOrName 'commit-tool.sh')

Copy-FileControlled `
  -Source (Join-Path $CommitToolDir 'commit-tool.config') `
  -Destination (Join-Path $DestTool 'commit-tool.config') `
  -CanOverwrite (Get-CanOverwrite -PathOrName 'commit-tool.config')

if ($Hooks) {
  Get-ChildItem -LiteralPath $CommitToolDir -File -ErrorAction Stop |
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
