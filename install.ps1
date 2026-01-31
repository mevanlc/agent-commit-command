# install.ps1 - Install commit-tool to ~/.claude/commands
#
# Usage: install.ps1 [options]
#   -Hooks       Also install hook-*.{sh,config} files
#   -UpgradeSh   Overwrite existing .sh files (not .config)
#   -UpgradeMd   Overwrite existing .md files (not .config)
#
# Options can be combined.

param(
    [switch]$Hooks,
    [switch]$UpgradeSh,
    [switch]$UpgradeMd,
    [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($Help) {
    Write-Host "Usage: install.ps1 [-Hooks] [-UpgradeSh] [-UpgradeMd]"
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  -Hooks       Also install hook-*.{sh,config} files"
    Write-Host "  -UpgradeSh   Overwrite existing .sh files (not .config)"
    Write-Host "  -UpgradeMd   Overwrite existing .md files (not .config)"
    exit 0
}

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$SrcCommands = Join-Path $ScriptDir 'commands'
$DestBase = Join-Path $HOME '.claude' 'commands'
$DestTool = Join-Path $DestBase 'commit-tool'

# Track results
$Installed = [System.Collections.Generic.List[string]]::new()
$Skipped = [System.Collections.Generic.List[string]]::new()

# Copy a file with overwrite control
function Copy-FileControlled {
    param(
        [string]$Src,
        [string]$Dest,
        [bool]$CanOverwrite
    )
    if (Test-Path $Dest) {
        if ($CanOverwrite) {
            Copy-Item -Path $Src -Destination $Dest -Force
            $Installed.Add("$Dest (overwritten)")
        } else {
            $Skipped.Add("$Dest (exists)")
        }
    } else {
        Copy-Item -Path $Src -Destination $Dest
        $Installed.Add($Dest)
    }
}

# Determine overwrite policy for a file
function Get-CanOverwrite {
    param([string]$File)
    switch -Wildcard ($File) {
        '*.sh'     { return [bool]$UpgradeSh }
        '*.md'     { return [bool]$UpgradeMd }
        '*.config' { return $false }
        default    { return $false }
    }
}

# Create destination directories
New-Item -ItemType Directory -Path $DestBase -Force | Out-Null
New-Item -ItemType Directory -Path $DestTool -Force | Out-Null

# Install .md files to commands/
foreach ($md in Get-ChildItem -Path $SrcCommands -Filter '*.md' -File -ErrorAction SilentlyContinue) {
    $dest = Join-Path $DestBase $md.Name
    Copy-FileControlled -Src $md.FullName -Dest $dest -CanOverwrite (Get-CanOverwrite $md.Name)
}

# Install commit-tool.sh and commit-tool.config
Copy-FileControlled -Src (Join-Path $SrcCommands 'commit-tool' 'commit-tool.sh') `
                    -Dest (Join-Path $DestTool 'commit-tool.sh') `
                    -CanOverwrite (Get-CanOverwrite 'commit-tool.sh')
Copy-FileControlled -Src (Join-Path $SrcCommands 'commit-tool' 'commit-tool.config') `
                    -Dest (Join-Path $DestTool 'commit-tool.config') `
                    -CanOverwrite (Get-CanOverwrite 'commit-tool.config')

# Install hooks if requested
if ($Hooks) {
    $hookPatterns = @('hook-*.sh', 'hook-*.config')
    foreach ($pattern in $hookPatterns) {
        foreach ($hook in Get-ChildItem -Path (Join-Path $SrcCommands 'commit-tool') -Filter $pattern -File -ErrorAction SilentlyContinue) {
            $dest = Join-Path $DestTool $hook.Name
            Copy-FileControlled -Src $hook.FullName -Dest $dest -CanOverwrite (Get-CanOverwrite $hook.Name)
        }
    }
}

# Report results
Write-Host "Installation complete."
Write-Host ""

if ($Installed.Count -gt 0) {
    Write-Host "Installed:"
    foreach ($f in $Installed) {
        Write-Host "  $f"
    }
}

if ($Skipped.Count -gt 0) {
    Write-Host ""
    Write-Host "Skipped (use -UpgradeSh or -UpgradeMd to overwrite):"
    foreach ($f in $Skipped) {
        Write-Host "  $f"
    }
}
