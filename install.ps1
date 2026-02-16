#!/usr/bin/env pwsh
# install.ps1 - Install slash commands + commit-tool
#
# Usage:
#   ./install.ps1 -Codex [-Hooks] [-SHUpdate] [-MDUpdate] [-Check] [srcdir]
#   ./install.ps1 -Claude [-Hooks] [-SHUpdate] [-MDUpdate] [-Check] [srcdir]
#   ./install.ps1 <srcdir> <dstdir> [-Hooks] [-SHUpdate] [-MDUpdate] [-Check]
#
# Where:
#   srcdir: repo subdir containing ./commands (e.g. ./codex or ./claude)
#   dstdir: base config dir (e.g. ~/.codex/ or ~/.claude/)

[CmdletBinding(PositionalBinding = $false)]
param(
  [switch]$Codex,
  [switch]$Claude,
  [switch]$Hooks,
  [switch]$SHUpdate,
  [switch]$MDUpdate,
  [switch]$Check,
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
  Write-Host '  ./install.ps1 -Codex [-Hooks] [-SHUpdate] [-MDUpdate] [-Check] [srcdir]'
  Write-Host '  ./install.ps1 -Claude [-Hooks] [-SHUpdate] [-MDUpdate] [-Check] [srcdir]'
  Write-Host '  ./install.ps1 <srcdir> <dstdir> [-Hooks] [-SHUpdate] [-MDUpdate] [-Check]'
  Write-Host ''
  Write-Host 'Note: PowerShell uses single-dash switches. Use ./install.sh for --long-options.'
  Write-Host ''
  Write-Host 'Examples:'
  Write-Host '  ./install.ps1 -Codex -SHUpdate -MDUpdate'
  Write-Host '  ./install.ps1 -Claude -Hooks'
  Write-Host '  ./install.ps1 -Codex ./codex -SHUpdate -MDUpdate'
  Write-Host '  ./install.ps1 -Codex -Check'
  Write-Host '  ./install.ps1 ./codex ~/.codex/ -SHUpdate -MDUpdate'
}

function Exit-UsageError {
  param([Parameter(Mandatory = $true)][string]$Message)
  Write-Warning $Message
  Write-Host ''
  Write-Usage
  exit 1
}

if ($Help) {
  Write-Usage
  exit 0
}

if ($RemainingArgs.Count -gt 0) {
  Exit-UsageError -Message "Unknown option: $($RemainingArgs[0])"
}

$ScriptDir =
  if ($PSScriptRoot) { $PSScriptRoot }
  else { Split-Path -Parent $MyInvocation.MyCommand.Path }

$HomeDir =
  if ($HOME) { $HOME }
  elseif ($env:USERPROFILE) { $env:USERPROFILE }
  else { [Environment]::GetFolderPath('UserProfile') }

if ($Codex -and $Claude) {
  Exit-UsageError -Message 'choose only one of -Codex or -Claude'
}

if (($Codex -or $Claude) -and $DstDir) {
  Exit-UsageError -Message 'do not provide <dstdir> when using -Codex/-Claude (optional [srcdir] only)'
}

$SourceRoot = $SrcDir
$DestRoot = $DstDir
if ($Codex) {
  if (-not $SourceRoot) {
    $SourceRoot = Join-Path $ScriptDir 'codex'
  }
  $DestRoot = Join-Path $HomeDir '.codex'
} elseif ($Claude) {
  if (-not $SourceRoot) {
    $SourceRoot = Join-Path $ScriptDir 'claude'
  }
  $DestRoot = Join-Path $HomeDir '.claude'
} else {
  if (-not $SourceRoot -or -not $DestRoot) {
    Exit-UsageError -Message 'expected <srcdir> <dstdir> or -Codex/-Claude'
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

# Codex stores slash commands in ~/.codex/prompts/.
$destSubdir =
  if ($Codex -or ([IO.Path]::GetFileName($DestRoot.TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)) -eq '.codex')) { 'prompts' }
  else { 'commands' }

$DestCommands = Join-Path $DestRoot $destSubdir
$DestTool = Join-Path $DestCommands 'commit-tool'

$Installed = New-Object System.Collections.Generic.List[string]
$Skipped = New-Object System.Collections.Generic.List[string]

function Get-RelFromDestRoot {
  param([Parameter(Mandatory = $true)][string]$Destination)
  $root = $DestRoot.TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
  if (-not $root) { return $Destination }
  if ($Destination.StartsWith($root, [StringComparison]::OrdinalIgnoreCase)) {
    return $Destination.Substring($root.Length).TrimStart([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
  }
  return $Destination
}

function Test-FilesSame {
  param(
    [Parameter(Mandatory = $true)][string]$Source,
    [Parameter(Mandatory = $true)][string]$Destination
  )
  if (-not (Test-Path -LiteralPath $Destination)) { return $false }
  $srcHash = (Get-FileHash -LiteralPath $Source -Algorithm SHA256).Hash
  $dstHash = (Get-FileHash -LiteralPath $Destination -Algorithm SHA256).Hash
  return ($srcHash -eq $dstHash)
}

function Get-CanOverwrite {
  param([Parameter(Mandatory = $true)][string]$PathOrName)
  $ext = [IO.Path]::GetExtension($PathOrName).ToLowerInvariant()
  switch ($ext) {
    '.sh' { return [bool]$SHUpdate }
    '.md' { return [bool]$MDUpdate }
    '.config' { return $false } # Never overwrite config files
    default { return $false }
  }
}

function Write-CheckLine {
  param(
    [Parameter(Mandatory = $true)][string]$Source,
    [Parameter(Mandatory = $true)][string]$Destination,
    [Parameter(Mandatory = $true)][bool]$CanOverwrite
  )

  $rel = Get-RelFromDestRoot -Destination $Destination

  if (-not (Test-Path -LiteralPath $Destination)) {
    Write-Host ("MISSING`t{0}`tinstall" -f $rel)
    $script:CheckMissing += 1
    return
  }

  if (Test-FilesSame -Source $Source -Destination $Destination) {
    Write-Host ("SAME`t{0}`tskip" -f $rel)
    $script:CheckSame += 1
    return
  }

  if ($CanOverwrite) {
    Write-Host ("DIFF`t{0}`toverwrite" -f $rel)
    $script:CheckDiffOverwrite += 1
    return
  }

  $ext = [IO.Path]::GetExtension($Destination).ToLowerInvariant()
  if ($ext -eq '.config') {
    Write-Host ("DIFF`t{0}`tskip (config never overwritten)" -f $rel)
  } elseif ($ext -eq '.sh') {
    Write-Host ("DIFF`t{0}`tskip (needs -SHUpdate)" -f $rel)
  } elseif ($ext -eq '.md') {
    Write-Host ("DIFF`t{0}`tskip (needs -MDUpdate)" -f $rel)
  } else {
    Write-Host ("DIFF`t{0}`tskip" -f $rel)
  }
  $script:CheckDiffSkip += 1
}

if ($Check) {
  Write-Host ("Destination root: {0}" -f $DestRoot)
  Write-Host ("Destination dir:  {0}" -f $DestCommands)
  Write-Host ''
  Write-Host "Status`tPath`tAction"

  $script:CheckSame = 0
  $script:CheckMissing = 0
  $script:CheckDiffOverwrite = 0
  $script:CheckDiffSkip = 0

  Get-ChildItem -LiteralPath $SrcCommands -Filter '*.md' -File -ErrorAction Stop | Sort-Object Name | ForEach-Object {
    $dest = Join-Path $DestCommands $_.Name
    Write-CheckLine -Source $_.FullName -Destination $dest -CanOverwrite (Get-CanOverwrite -PathOrName $_.Name)
  }

  Write-CheckLine `
    -Source (Join-Path $CommitToolSrc 'commit-tool.sh') `
    -Destination (Join-Path $DestTool 'commit-tool.sh') `
    -CanOverwrite (Get-CanOverwrite -PathOrName 'commit-tool.sh')

  Write-CheckLine `
    -Source (Join-Path $CommitToolSrc 'commit-tool.config') `
    -Destination (Join-Path $DestTool 'commit-tool.config') `
    -CanOverwrite (Get-CanOverwrite -PathOrName 'commit-tool.config')

  if ($Hooks) {
    Get-ChildItem -LiteralPath $CommitToolSrc -File -ErrorAction Stop |
      Where-Object { $_.Name -like 'hook-*.sh' -or $_.Name -like 'hook-*.config' } |
      Sort-Object Name |
      ForEach-Object {
        $dest = Join-Path $DestTool $_.Name
        Write-CheckLine -Source $_.FullName -Destination $dest -CanOverwrite (Get-CanOverwrite -PathOrName $_.Name)
      }
  }

  Write-Host ''
  Write-Host ("Summary: {0} same, {1} missing, {2} diff(overwrite), {3} diff(skip)" -f $script:CheckSame, $script:CheckMissing, $script:CheckDiffOverwrite, $script:CheckDiffSkip)
  exit 0
}

New-Item -ItemType Directory -Force -Path $DestCommands | Out-Null
New-Item -ItemType Directory -Force -Path $DestTool | Out-Null

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
  Write-Host 'Skipped (use -SHUpdate or -MDUpdate to overwrite):'
  foreach ($item in $Skipped) { Write-Host "  $item" }
}
