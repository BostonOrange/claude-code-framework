# Installs the global /install-framework skill into ~/.claude/skills/.
# Run from a clone of claude-code-framework.
$ErrorActionPreference = "Stop"

$FrameworkDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$Src = Join-Path $FrameworkDir "global-skills/install-framework"
$SkillsDir = Join-Path $env:USERPROFILE ".claude/skills"
$Dest = Join-Path $SkillsDir "install-framework"

if (-not (Test-Path $Src)) {
    Write-Host "ERROR: $Src not found. Run this from a clone of claude-code-framework."
    exit 1
}

New-Item -ItemType Directory -Force -Path $SkillsDir | Out-Null
if (Test-Path $Dest) {
    Write-Host "Updating existing global skill at $Dest"
    Remove-Item -Recurse -Force $Dest
}
Copy-Item -Recurse -Force $Src $Dest
Write-Host "Installed /install-framework to $Dest"
Write-Host "It is now available in Claude Code (CLI, desktop, web)."
