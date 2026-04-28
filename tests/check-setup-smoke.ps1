# Claude Code Framework - PowerShell Setup Smoke Tests
# Exercises setup.ps1 in throwaway target projects with an isolated USERPROFILE.

$ErrorActionPreference = "Stop"

$FrameworkDir = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$SetupScript = Join-Path $FrameworkDir "setup.ps1"
$TmpRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("ccf-setup-smoke-ps-" + [System.Guid]::NewGuid().ToString("N"))
$script:Pass = 0
$script:Fail = 0

New-Item -ItemType Directory -Force -Path $TmpRoot | Out-Null

function Complete-Cleanup {
    if (Test-Path $TmpRoot) {
        Remove-Item -Recurse -Force $TmpRoot -ErrorAction SilentlyContinue
    }
}

trap {
    Complete-Cleanup
    throw
}

function Pass($Label) {
    Write-Host "  [PASS] $Label"
    $script:Pass++
}

function Fail($Label) {
    Write-Host "  [FAIL] $Label"
    $script:Fail++
}

function Assert-Exists($Path, $Label) {
    if (Test-Path $Path) { Pass $Label } else { Fail $Label }
}

function Assert-Absent($Path, $Label) {
    if (-not (Test-Path $Path)) { Pass $Label } else { Fail $Label }
}

function Assert-Contains($Path, $Pattern, $Label) {
    if ((Test-Path $Path) -and (Select-String -Path $Path -Pattern $Pattern -Quiet)) {
        Pass $Label
    } else {
        Fail $Label
    }
}

function Invoke-SetupProcess($Target, $Home, $InputText, [switch]$DryRun) {
    New-Item -ItemType Directory -Force -Path $Target, $Home | Out-Null

    $inputFile = Join-Path $TmpRoot ([System.Guid]::NewGuid().ToString("N") + ".in")
    $outputFile = Join-Path $TmpRoot ([System.Guid]::NewGuid().ToString("N") + ".out")
    $errorFile = Join-Path $TmpRoot ([System.Guid]::NewGuid().ToString("N") + ".err")
    Set-Content -Path $inputFile -Value $InputText -NoNewline -Encoding UTF8

    $pwsh = (Get-Command pwsh -ErrorAction Stop).Source
    $args = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $SetupScript)
    if ($DryRun) { $args += "-DryRun" }

    $oldUserProfile = $env:USERPROFILE
    $env:USERPROFILE = $Home
    try {
        $process = Start-Process `
            -FilePath $pwsh `
            -ArgumentList $args `
            -WorkingDirectory $Target `
            -RedirectStandardInput $inputFile `
            -RedirectStandardOutput $outputFile `
            -RedirectStandardError $errorFile `
            -NoNewWindow `
            -Wait `
            -PassThru
    } finally {
        $env:USERPROFILE = $oldUserProfile
    }

    $output = ""
    if (Test-Path $outputFile) { $output += Get-Content $outputFile -Raw -ErrorAction SilentlyContinue }
    if (Test-Path $errorFile) { $output += Get-Content $errorFile -Raw -ErrorAction SilentlyContinue }

    [pscustomobject]@{
        ExitCode = $process.ExitCode
        Output = $output
        OutputFile = $outputFile
    }
}

function Assert-NoTraceback($Result, $Label) {
    if ($Result.Output -match "Traceback|Exception") {
        Fail $Label
        Write-Host ($Result.Output -split "`n" | Select-Object -First 80)
    } else {
        Pass $Label
    }
}

function Assert-NoOperationalPlaceholders($Target, $Label) {
    $paths = @()
    $claudeDir = Join-Path $Target ".claude"
    if (Test-Path $claudeDir) {
        $paths += Get-ChildItem -Path $claudeDir -Recurse -File
    }
    foreach ($file in @("CLAUDE.md", ".mcp.json")) {
        $path = Join-Path $Target $file
        if (Test-Path $path) { $paths += Get-Item $path }
    }

    $remaining = @()
    foreach ($path in $paths) {
        $relative = [System.IO.Path]::GetRelativePath($Target, $path.FullName).Replace("\", "/")
        if ($relative -eq ".claude/agents/framework-improver.md" -or $relative -eq ".claude/skills/improve/SKILL.md") {
            continue
        }
        $matches = Select-String -Path $path.FullName -Pattern "\{\{[A-Z_][A-Z_]*\}\}" -ErrorAction SilentlyContinue
        if ($matches) { $remaining += $matches }
    }

    if ($remaining.Count -eq 0) {
        Pass $Label
    } else {
        Fail $Label
        $remaining | Select-Object -First 20 | ForEach-Object { Write-Host "    $($_.Path):$($_.LineNumber):$($_.Line)" }
    }
}

function Assert-NoPlaceholdersInTree($Target, $Label) {
    $remaining = @()
    $files = Get-ChildItem -Path $Target -Recurse -File -Force -ErrorAction SilentlyContinue |
        Where-Object {
            $_.FullName -notmatch "\\.git\\" -and
            $_.FullName -notmatch "\\node_modules\\" -and
            $_.FullName -notmatch "\\.next\\"
        }

    foreach ($file in $files) {
        $relative = [System.IO.Path]::GetRelativePath($Target, $file.FullName).Replace("\", "/")
        if ($relative -eq ".claude/agents/framework-improver.md" -or $relative -eq ".claude/skills/improve/SKILL.md") {
            continue
        }
        $matches = Select-String -Path $file.FullName -Pattern "\{\{[A-Z_][A-Z_]*\}\}" -ErrorAction SilentlyContinue
        if ($matches) { $remaining += $matches }
    }

    if ($remaining.Count -eq 0) {
        Pass $Label
    } else {
        Fail $Label
        $remaining | Select-Object -First 20 | ForEach-Object { Write-Host "    $($_.Path):$($_.LineNumber):$($_.Line)" }
    }
}

function Run-SetupCase($Name, $InputText) {
    $target = Join-Path $TmpRoot $Name
    $home = Join-Path $TmpRoot "home-$Name"
    $result = Invoke-SetupProcess -Target $target -Home $home -InputText $InputText

    if ($result.ExitCode -eq 0) {
        Pass "$Name setup exits 0"
    } else {
        Fail "$Name setup exits 0"
        Write-Host ($result.Output -split "`n" | Select-Object -First 120)
        return $target
    }

    Assert-NoTraceback $result "$Name has no PowerShell exception"
    Assert-Exists (Join-Path $target ".claude/skills/develop/SKILL.md") "$Name installs skills"
    Assert-Exists (Join-Path $target ".claude/agents/code-reviewer.md") "$Name installs agents"
    Assert-Exists (Join-Path $target ".claude/hooks/guardrails.sh") "$Name installs hooks"
    Assert-Exists (Join-Path $target ".claude/settings.local.json") "$Name installs project settings"
    Assert-Exists (Join-Path $target ".mcp.json") "$Name installs MCP config"
    Assert-Exists (Join-Path $target "CLAUDE.md") "$Name creates CLAUDE.md"
    Assert-Exists (Join-Path $home ".claude/settings.json") "$Name isolates user settings under test USERPROFILE"
    Assert-NoOperationalPlaceholders $target "$Name has no operational placeholders"
    return $target
}

Write-Host "======================================"
Write-Host "  PowerShell Setup Smoke Tests"
Write-Host "======================================"
Write-Host ""

Write-Host "Node.js target, no tracker, no CI, no design system..."
$node = Run-SetupCase "node-none" "2`n5`n4`nmain`n4`nsample`n4`n"
Assert-Absent (Join-Path $node ".claude/rules/design-system.md") "node-none skips design-system rule"
Assert-Contains (Join-Path $node "CLAUDE.md") "No design system configured" "node-none documents no design system"

Write-Host ""
Write-Host "Python target..."
$python = Run-SetupCase "python-none" "3`n5`n4`nmain`n4`nsample`n"
Assert-Absent (Join-Path $python ".claude/rules/components.md") "python-none skips components rule"
Assert-Absent (Join-Path $python ".claude/rules/design-system.md") "python-none skips design-system rule"
Assert-Contains (Join-Path $python "CLAUDE.md") "N/A .* backend project" "python-none documents backend design status"

Write-Host ""
Write-Host "React target with GitHub Actions and shadcn/ui..."
$react = Run-SetupCase "react-gh-shadcn" "6`n5`n1`nmain`n4`nsample`n2`n"
Assert-Exists (Join-Path $react ".github/workflows/factory-validate.yml") "react-gh-shadcn installs GitHub workflows"
$workflowCount = 0
$workflowDir = Join-Path $react ".github/workflows"
if (Test-Path $workflowDir) {
    $workflowCount = (Get-ChildItem -Path $workflowDir -Filter "*.yml" -File).Count
}
if ($workflowCount -eq 4) { Pass "react-gh-shadcn installs 4 workflow files" } else { Fail "react-gh-shadcn installs 4 workflow files (found $workflowCount)" }
Assert-Exists (Join-Path $react ".claude/rules/design-system.md") "react-gh-shadcn keeps design-system rule"
Assert-Contains (Join-Path $react "CLAUDE.md") "Use CSS variable-based colors" "react-gh-shadcn documents shadcn color rules"

Write-Host ""
Write-Host "Internal Next.js business app preset..."
$internal = Run-SetupCase "internal-app-vercel" "7`n2`n3`n2`n5`n1`nmain`n4`nsample`n"
Assert-Exists (Join-Path $internal "package.json") "internal-app installs package.json"
Assert-Exists (Join-Path $internal "prisma/schema.prisma") "internal-app installs Prisma schema"
Assert-Exists (Join-Path $internal "src/lib/blob/client.ts") "internal-app installs blob boundary"
Assert-Exists (Join-Path $internal "src/lib/auth/session.ts") "internal-app installs auth/session files"
Assert-Exists (Join-Path $internal "src/app/api/health/route.ts") "internal-app installs Next.js API route"
Assert-Exists (Join-Path $internal ".env.example") "internal-app creates .env.example"
Assert-Exists (Join-Path $internal "docs/setup.md") "internal-app creates setup docs"
Assert-Exists (Join-Path $internal ".claude/internal-app.json") "internal-app stores setup choices"
Assert-Absent (Join-Path $internal "node_modules") "internal-app excludes node_modules"
Assert-Absent (Join-Path $internal ".next") "internal-app excludes .next"
Assert-Absent (Join-Path $internal ".env.local") "internal-app excludes .env.local"
Assert-Absent (Join-Path $internal "src/generated/prisma") "internal-app excludes generated Prisma client"
Assert-Absent (Join-Path $internal "tsconfig.tsbuildinfo") "internal-app excludes tsbuildinfo"
Assert-Contains (Join-Path $internal ".env.example") "Vercel" "internal-app .env.example contains Vercel notes"
Assert-Contains (Join-Path $internal ".env.example") "Azure Container Apps" "internal-app .env.example contains Azure notes"
Assert-Contains (Join-Path $internal "docs/setup.md") "do not fork it into hosting-specific stacks" "internal-app setup docs preserve one stack"
Assert-Contains (Join-Path $internal "package.json") "prisma generate && tsc --noEmit" "internal-app typecheck can generate Prisma after install"
Assert-NoPlaceholdersInTree $internal "internal-app tree has no setup placeholders"

Write-Host ""
Write-Host "Dry-run branch rename safety..."
$dryTarget = Join-Path $TmpRoot "dry-run-target"
$dryHome = Join-Path $TmpRoot "home-dry-run"
New-Item -ItemType Directory -Force -Path $dryTarget, $dryHome | Out-Null
git -C $dryTarget init -b old *> $null
git -C $dryTarget config user.email "setup-smoke@example.com"
git -C $dryTarget config user.name "Setup Smoke"
Set-Content -Path (Join-Path $dryTarget "README.md") -Value "setup smoke" -Encoding UTF8
git -C $dryTarget add README.md
git -C $dryTarget commit -m "Initial commit" *> $null

$dryResult = Invoke-SetupProcess -Target $dryTarget -Home $dryHome -InputText "9`n5`n4`nnew`ny`n4`nsample`n" -DryRun
if ($dryResult.ExitCode -eq 0) { Pass "dry-run setup exits 0" } else { Fail "dry-run setup exits 0" }
$dryBranch = (git -C $dryTarget rev-parse --abbrev-ref HEAD 2>$null)
if ($dryBranch -eq "old") { Pass "dry-run does not rename branch" } else { Fail "dry-run does not rename branch (found $dryBranch)" }
Assert-Absent (Join-Path $dryTarget ".claude") "dry-run does not create .claude"
Assert-Absent (Join-Path $dryTarget "CLAUDE.md") "dry-run does not create CLAUDE.md"
if ($dryResult.Output -match "Would rename branch 'old' -> 'new'") { Pass "dry-run reports branch rename preview" } else { Fail "dry-run reports branch rename preview" }
$dryStatus = git -C $dryTarget status --short
if (-not $dryStatus) { Pass "dry-run leaves git status clean" } else { Fail "dry-run leaves git status clean"; Write-Host $dryStatus }

Write-Host ""
Write-Host "--------------------------------------"
Write-Host "  Results: $script:Pass passed, $script:Fail failed"
Write-Host "--------------------------------------"

Complete-Cleanup

if ($script:Fail -gt 0) {
    Write-Host ""
    Write-Host "FAILED: $script:Fail PowerShell setup smoke check(s) failed"
    exit 1
}

Write-Host ""
Write-Host "All PowerShell setup smoke tests passed."
