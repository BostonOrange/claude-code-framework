# Claude Code Framework — Interactive Setup Wizard (Windows PowerShell)
# Usage: cd your-project/ ; & ~/Developer/claude-code-framework/setup.ps1

param(
    [switch]$DryRun,
    [switch]$Reset,
    [switch]$Help
)

if ($Help) {
    Write-Host "Usage: setup.ps1 [-DryRun] [-Reset]"
    Write-Host "  -DryRun   Show what would be done without making changes"
    Write-Host "  -Reset    Remove framework files from target project"
    exit 0
}

$ErrorActionPreference = "Stop"

$FRAMEWORK_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path
$PROJECT_DIR = Get-Location
$PROJECT_NAME = Split-Path -Leaf $PROJECT_DIR

if ($Reset) {
    Write-Host "Removing framework files..."
    $dirs = @("skills", "agents", "commands", "rules", "hooks")
    foreach ($dir in $dirs) {
        $path = Join-Path $PROJECT_DIR ".claude/$dir"
        if (Test-Path $path) { Remove-Item -Recurse -Force $path }
    }
    $files = @(".claude/settings.local.json", ".mcp.json")
    foreach ($file in $files) {
        $path = Join-Path $PROJECT_DIR $file
        if (Test-Path $path) { Remove-Item -Force $path }
    }
    Write-Host "Framework files removed. CLAUDE.md and .env preserved."
    exit 0
}

Write-Host "======================================"
Write-Host "  Claude Code Framework Setup"
Write-Host "======================================"
Write-Host ""
Write-Host "Project: $PROJECT_NAME"
Write-Host "Directory: $PROJECT_DIR"
if ($DryRun) { Write-Host "Mode:    DRY RUN (no changes will be made)" }
Write-Host ""

# -- 1. Project Type --

Write-Host "What type of project is this?"
Write-Host "  1) Salesforce (Apex, LWC, Flows)"
Write-Host "  2) Node.js / TypeScript"
Write-Host "  3) Python"
Write-Host "  4) Go"
Write-Host "  5) Java / Spring Boot"
Write-Host "  6) React / Next.js"
Write-Host "  7) Ruby on Rails"
Write-Host "  8) Other"
do {
    $PROJECT_TYPE = Read-Host "Choice [1-8]"
    if (-not $PROJECT_TYPE) { $PROJECT_TYPE = "8" }
    $valid = $PROJECT_TYPE -match '^[1-8]$'
    if (-not $valid) { Write-Host "Invalid selection. Please enter a number 1-8." }
} while (-not $valid)

$PROJECT_TYPE_NAME = switch ($PROJECT_TYPE) {
    "1" { "salesforce" }
    "2" { "nodejs" }
    "3" { "python" }
    "4" { "go" }
    "5" { "java" }
    "6" { "react" }
    "7" { "rails" }
    default { "generic" }
}

# -- 2. Work Item Tracker --

Write-Host ""
Write-Host "What work item tracker do you use?"
Write-Host "  1) Azure DevOps"
Write-Host "  2) Jira"
Write-Host "  3) Linear"
Write-Host "  4) GitHub Issues"
Write-Host "  5) None"
do {
    $TRACKER_TYPE = Read-Host "Choice [1-5]"
    if (-not $TRACKER_TYPE) { $TRACKER_TYPE = "5" }
    $valid = $TRACKER_TYPE -match '^[1-5]$'
    if (-not $valid) { Write-Host "Invalid selection. Please enter a number 1-5." }
} while (-not $valid)

$TRACKER_NAME = switch ($TRACKER_TYPE) {
    "1" { "ado" }
    "2" { "jira" }
    "3" { "linear" }
    "4" { "github" }
    default { "none" }
}

# Collect tracker-specific user inputs (config values loaded later from JSON)
switch ($TRACKER_NAME) {
    "ado" {
        $ADO_ORG = Read-Host "ADO Organization"
        $ADO_PROJECT = Read-Host "ADO Project"
    }
    "jira" {
        $JIRA_DOMAIN = Read-Host "Jira Domain (e.g., mycompany.atlassian.net)"
        $JIRA_PROJECT = Read-Host "Jira Project Key (e.g., PROJ)"
    }
    "linear" {
        $LINEAR_TEAM = Read-Host "Linear Team ID"
    }
}

# -- 3. CI/CD Platform --

Write-Host ""
Write-Host "What CI/CD platform do you use?"
Write-Host "  1) GitHub Actions"
Write-Host "  2) GitLab CI"
Write-Host "  3) CircleCI"
Write-Host "  4) None / Manual"
do {
    $CI_TYPE = Read-Host "Choice [1-4]"
    if (-not $CI_TYPE) { $CI_TYPE = "4" }
    $valid = $CI_TYPE -match '^[1-4]$'
    if (-not $valid) { Write-Host "Invalid selection. Please enter a number 1-4." }
} while (-not $valid)

$CI_NAME = switch ($CI_TYPE) {
    "1" { "github-actions" }
    "2" { "gitlab-ci" }
    "3" { "circleci" }
    default { "none" }
}

# -- 4. Base Branch --

Write-Host ""
$BASE_BRANCH = Read-Host "Primary integration branch [main]"
if (-not $BASE_BRANCH) { $BASE_BRANCH = "main" }

# -- 5. Notification System --

Write-Host ""
Write-Host "What notification system do you use?"
Write-Host "  1) Slack"
Write-Host "  2) Microsoft Teams"
Write-Host "  3) Discord"
Write-Host "  4) None"
do {
    $NOTIFY_TYPE = Read-Host "Choice [1-4]"
    if (-not $NOTIFY_TYPE) { $NOTIFY_TYPE = "4" }
    $valid = $NOTIFY_TYPE -match '^[1-4]$'
    if (-not $valid) { Write-Host "Invalid selection. Please enter a number 1-4." }
} while (-not $valid)

$NOTIFY_NAME = switch ($NOTIFY_TYPE) {
    "1" { "slack" }
    "2" { "teams" }
    "3" { "discord" }
    default { "none" }
}

# -- 6. Project Short Name --

Write-Host ""
$PROJECT_SHORT = Read-Host "Short project name (for worktrees, e.g., 'myapp') [$PROJECT_NAME]"
if (-not $PROJECT_SHORT) { $PROJECT_SHORT = $PROJECT_NAME }

# -- 7. Design System --

$DESIGN_SYSTEM_NAME = "none"

if ($PROJECT_TYPE_NAME -in "react", "nodejs") {
    Write-Host ""
    Write-Host "What design system foundation does this project use?"
    Write-Host "  1) Untitled UI (premium, React Aria based)"
    Write-Host "  2) shadcn/ui (open source, Radix based)"
    Write-Host "  3) Custom / existing (I'll configure it later)"
    Write-Host "  4) None - no design system"
    do {
        $DESIGN_TYPE = Read-Host "Choice [1-4]"
        if (-not $DESIGN_TYPE) { $DESIGN_TYPE = "4" }
        $valid = $DESIGN_TYPE -match '^[1-4]$'
        if (-not $valid) { Write-Host "Invalid selection. Please enter a number 1-4." }
    } while (-not $valid)

    $DESIGN_SYSTEM_NAME = switch ($DESIGN_TYPE) {
        "1" { "untitled-ui" }
        "2" { "shadcn" }
        "3" { "custom" }
        default { "none" }
    }
} else {
    # Non-frontend projects use the _backend preset
    $DESIGN_SYSTEM_NAME = "_backend"
}

# Load design system values from config/design-systems.json
$designSystems = Get-Content "$FRAMEWORK_DIR/config/design-systems.json" -Raw -Encoding UTF8 | ConvertFrom-Json
$designCfg = $designSystems.$DESIGN_SYSTEM_NAME
if (-not $designCfg) { $designCfg = $designSystems.none }

$DESIGN_COLOR_RULES = $designCfg.color_rules
$DESIGN_COMPONENT_IMPORTS = $designCfg.component_imports
$DESIGN_ICON_USAGE = $designCfg.icon_usage
$DESIGN_CARD_PATTERNS = $designCfg.card_patterns
$DESIGN_DARK_MODE = $designCfg.dark_mode

# ============================================================
# Generate project files
# ============================================================

Write-Host ""
Write-Host "Setting up Claude Code framework..."
Write-Host ""

# -- Ensure base branch exists --

$isGitRepo = git rev-parse --git-dir 2>$null
if ($isGitRepo) {
    $currentBranch = git rev-parse --abbrev-ref HEAD 2>$null
    if ($currentBranch -and $currentBranch -ne $BASE_BRANCH) {
        $confirm = Read-Host "Current branch is '$currentBranch'. Rename to '$BASE_BRANCH' and update remote? [y/N]"
        if ($confirm -ne 'y' -and $confirm -ne 'Y') {
            Write-Host "Skipping branch rename. Using '$currentBranch' as-is."
            $BASE_BRANCH = $currentBranch
        } else {
            if (-not $DryRun) {
                Write-Host "Renaming branch '$currentBranch' -> '$BASE_BRANCH'..."
                git branch -m $currentBranch $BASE_BRANCH

                $hasRemote = git remote get-url origin 2>$null
                if ($hasRemote) {
                    Write-Host "Pushing '$BASE_BRANCH' to remote..."
                    git push -u origin $BASE_BRANCH 2>$null

                    # Try to set default branch (requires gh CLI)
                    if (Get-Command gh -ErrorAction SilentlyContinue) {
                        gh repo edit --default-branch $BASE_BRANCH 2>$null
                    }

                    # Delete old remote branch
                    git push origin --delete $currentBranch 2>$null
                }
            } else {
                Write-Host "[DRY-RUN] Would rename branch '$currentBranch' -> '$BASE_BRANCH'"
                Write-Host "[DRY-RUN] Would push '$BASE_BRANCH' to remote and delete '$currentBranch'"
            }
        }
    }
}

# -- Create directories --

if (-not $DryRun) {
    New-Item -ItemType Directory -Force -Path ".claude/skills" | Out-Null
    New-Item -ItemType Directory -Force -Path ".claude/agents" | Out-Null
    New-Item -ItemType Directory -Force -Path ".claude/commands" | Out-Null
    New-Item -ItemType Directory -Force -Path ".claude/rules" | Out-Null
    New-Item -ItemType Directory -Force -Path ".claude/hooks" | Out-Null
    New-Item -ItemType Directory -Force -Path ".claude/statusline" | Out-Null
    New-Item -ItemType Directory -Force -Path "docs/stories" | Out-Null
} else {
    Write-Host "[DRY-RUN] Would create directories: .claude/skills, agents, commands, rules, hooks, statusline, docs/stories"
}

# -- Copy skills --

Write-Host "Copying skills..."
Get-ChildItem -Directory "$FRAMEWORK_DIR/skills" | Where-Object { $_.Name -ne "_template" } | ForEach-Object {
    if (-not $DryRun) {
        Copy-Item -Recurse -Force $_.FullName ".claude/skills/$($_.Name)"
    }
    Write-Host "  $(if ($DryRun) { '[DRY-RUN] Would copy' } else { '+' }) /$($_.Name)"
}

# -- Copy agents --

Write-Host "Copying agents..."
Get-ChildItem "$FRAMEWORK_DIR/templates/agents" -Filter "*.md" -ErrorAction SilentlyContinue | ForEach-Object {
    if (-not $DryRun) {
        Copy-Item $_.FullName ".claude/agents/$($_.Name)" -Force
    }
    Write-Host "  $(if ($DryRun) { '[DRY-RUN] Would copy' } else { '+' }) $($_.Name)"
}

# -- Copy commands --

Write-Host "Copying commands..."
Get-ChildItem "$FRAMEWORK_DIR/templates/commands" -Filter "*.md" -ErrorAction SilentlyContinue | ForEach-Object {
    if (-not $DryRun) {
        Copy-Item $_.FullName ".claude/commands/$($_.Name)" -Force
    }
    Write-Host "  $(if ($DryRun) { '[DRY-RUN] Would copy' } else { '+' }) $($_.Name)"
}

# -- Copy rules --

Write-Host "Copying rules..."
Get-ChildItem "$FRAMEWORK_DIR/templates/rules" -Filter "*.md" -ErrorAction SilentlyContinue | ForEach-Object {
    if (-not $DryRun) {
        Copy-Item $_.FullName ".claude/rules/$($_.Name)" -Force
    }
    Write-Host "  $(if ($DryRun) { '[DRY-RUN] Would copy' } else { '+' }) $($_.Name)"
}

# Skip frontend rules for backend-only projects
if ($PROJECT_TYPE_NAME -in "python", "go", "java") {
    if (-not $DryRun) {
        if (Test-Path ".claude/rules/components.md") {
            Remove-Item ".claude/rules/components.md" -Force
            Write-Host "  Skipped components.md (backend-only project)"
        }
        if (Test-Path ".claude/rules/design-system.md") {
            Remove-Item ".claude/rules/design-system.md" -Force
            Write-Host "  Skipped design-system.md (backend-only project)"
        }
    } else {
        Write-Host "[DRY-RUN] Would skip components.md and design-system.md (backend-only project)"
    }
}

# Skip design-system rule if no design system configured
if ($DESIGN_SYSTEM_NAME -eq "none") {
    if (-not $DryRun) {
        if (Test-Path ".claude/rules/design-system.md") {
            Remove-Item ".claude/rules/design-system.md" -Force
            Write-Host "  Skipped design-system.md (no design system configured)"
        }
    } else {
        Write-Host "[DRY-RUN] Would skip design-system.md (no design system configured)"
    }
}

# -- Copy hooks --

Write-Host "Copying hooks..."
Get-ChildItem "$FRAMEWORK_DIR/templates/hooks" -Filter "*.sh" -ErrorAction SilentlyContinue | ForEach-Object {
    if (-not $DryRun) {
        Copy-Item $_.FullName ".claude/hooks/$($_.Name)" -Force
    }
    Write-Host "  $(if ($DryRun) { '[DRY-RUN] Would copy' } else { '+' }) $($_.Name)"
}

# -- Build project-type-specific commands --

# -- Load project-type-specific commands and file patterns from config/project-types.json --

$DEFAULT_MODEL = "sonnet"

$projectTypes = Get-Content "$FRAMEWORK_DIR/config/project-types.json" -Raw -Encoding UTF8 | ConvertFrom-Json
$typeConfig = $projectTypes.$PROJECT_TYPE_NAME
if (-not $typeConfig) { $typeConfig = $projectTypes.generic }

$FORMAT_CMD = $typeConfig.format_cmd
$FORMAT_VERIFY = $typeConfig.format_verify
$TEST_CMD = $typeConfig.test_cmd
$DEPLOY_VALIDATE = $typeConfig.deploy_validate
$TYPE_CHECK_CMD = $typeConfig.type_check_cmd
$DEP_CHECK_CMD = $typeConfig.dep_check_cmd
$SECURITY_AUDIT_CMD = $typeConfig.security_audit_cmd
$ERROR_TRACKING = $typeConfig.error_tracking

# Pattern variables (arrays joined with comma-space, each element quoted)
$API_ROUTE_PATTERNS = ($typeConfig.api_route_patterns | ForEach-Object { "`"$_`"" }) -join ", "
$COMPONENT_PATTERNS = ($typeConfig.component_patterns | ForEach-Object { "`"$_`"" }) -join ", "
$TEST_PATTERNS = ($typeConfig.test_patterns | ForEach-Object { "`"$_`"" }) -join ", "
$DATABASE_PATTERNS = ($typeConfig.database_patterns | ForEach-Object { "`"$_`"" }) -join ", "
$SOURCE_PATTERNS = ($typeConfig.source_patterns | ForEach-Object { "`"$_`"" }) -join ", "

# -- Load tracker commands from config/trackers.json --

$trackersConfig = Get-Content "$FRAMEWORK_DIR/config/trackers.json" -Raw -Encoding UTF8 | ConvertFrom-Json
$trackerConfig = $trackersConfig.$TRACKER_NAME
if (-not $trackerConfig) { $trackerConfig = $trackersConfig.none }

# Replace tracker-specific placeholders with user-provided values
function Replace-TrackerPlaceholders($val) {
    if (-not $val) { return "" }
    $val = $val.Replace('{{ADO_ORG}}', $(if ($ADO_ORG) { $ADO_ORG } else { '' }))
    $val = $val.Replace('{{ADO_PROJECT}}', $(if ($ADO_PROJECT) { $ADO_PROJECT } else { '' }))
    $val = $val.Replace('{{JIRA_DOMAIN}}', $(if ($JIRA_DOMAIN) { $JIRA_DOMAIN } else { '' }))
    $val = $val.Replace('{{JIRA_PROJECT}}', $(if ($JIRA_PROJECT) { $JIRA_PROJECT } else { '' }))
    $val = $val.Replace('{{LINEAR_TEAM}}', $(if ($LINEAR_TEAM) { $LINEAR_TEAM } else { '' }))
    return $val
}

$TRACKER_FETCH = Replace-TrackerPlaceholders $trackerConfig.fetch_ticket
$TRACKER_SET_PROGRESS = Replace-TrackerPlaceholders $trackerConfig.set_progress
$TRACKER_SET_REVIEW = Replace-TrackerPlaceholders $trackerConfig.set_review
$TRACKER_URL = Replace-TrackerPlaceholders $trackerConfig.ticket_url
$TRACKER_CONFIG = Replace-TrackerPlaceholders $trackerConfig.config
# Pre-compute the remaining tracker-derived values as variables so config/placeholders.json
# can reference them by name (matches the env-var convention used by setup.sh)
$TRACKER_LINK_PR = Replace-TrackerPlaceholders $trackerConfig.link_pr
$TRACKER_CREATE = Replace-TrackerPlaceholders $trackerConfig.create_ticket
$TRACKER_CREATE_BUG = Replace-TrackerPlaceholders $trackerConfig.create_bug
$TRACKER_UPDATE_FIELDS = Replace-TrackerPlaceholders $trackerConfig.update_fields
$TRACKER_SET_DEPLOYED = Replace-TrackerPlaceholders $trackerConfig.set_deployed

# -- Load notification commands from config/notifications.json --

$notifyConfig = Get-Content "$FRAMEWORK_DIR/config/notifications.json" -Raw -Encoding UTF8 | ConvertFrom-Json
$notifyCfg = $notifyConfig.$NOTIFY_NAME
if (-not $notifyCfg) { $notifyCfg = $notifyConfig.none }

$NOTIFY_CMD = $notifyCfg.halt
$NOTIFY_DEPLOY_CMD = $notifyCfg.deploy_success
$NOTIFY_MERGE_CMD = $notifyCfg.merge_resolve

# -- Replace placeholders in all copied files --

Write-Host "Configuring files for your project..."

# Build placeholder map from config/placeholders.json (single source of truth shared with setup.sh).
# For each entry, look up the named variable in this scope; fall back to the 'default' field.
$placeholdersPath = Join-Path $FRAMEWORK_DIR "config/placeholders.json"
$placeholdersCfg = Get-Content $placeholdersPath -Raw | ConvertFrom-Json
$replacements = @{}
foreach ($p in $placeholdersCfg.placeholders) {
    $key = '{{' + $p.name + '}}'
    $default = if ($null -ne $p.default) { $p.default } else { '' }
    $value = $default
    if ($p.env) {
        # Look up the PS variable by name; treat unset / $null as "use default"
        $psVar = Get-Variable -Name $p.env -ValueOnly -Scope Script -ErrorAction SilentlyContinue
        if ($null -eq $psVar) {
            $psVar = Get-Variable -Name $p.env -ValueOnly -ErrorAction SilentlyContinue
        }
        if ($null -ne $psVar) {
            $value = $psVar
        }
    }
    $replacements[$key] = $value
}

# Replace in skills, agents, commands, rules, hooks
$searchDirs = @(".claude/skills", ".claude/agents", ".claude/commands", ".claude/rules", ".claude/hooks")
$updatedCount = 0

if (-not $DryRun) {
    foreach ($searchDir in $searchDirs) {
        if (Test-Path $searchDir) {
            $files = Get-ChildItem -Recurse $searchDir -Include "*.md", "*.sh" -ErrorAction SilentlyContinue
            foreach ($file in $files) {
                $content = Get-Content $file.FullName -Raw -Encoding UTF8
                if (-not $content) { continue }
                $changed = $false
                foreach ($key in $replacements.Keys) {
                    if ($content.Contains($key)) {
                        $content = $content.Replace($key, $replacements[$key])
                        $changed = $true
                    }
                }
                if ($changed) {
                    Set-Content $file.FullName $content -Encoding UTF8 -NoNewline
                    $updatedCount++
                }
            }
        }
    }
    Write-Host "  Updated $updatedCount files"
} else {
    Write-Host "[DRY-RUN] Would replace placeholders in all copied .md and .sh files"
}

# -- Copy settings --

Write-Host "Copying settings..."
if (-not $DryRun) {
    Copy-Item "$FRAMEWORK_DIR/templates/settings.local.json" ".claude/settings.local.json" -Force

    # Replace model placeholder in settings
    $settingsContent = Get-Content ".claude/settings.local.json" -Raw -Encoding UTF8
    $settingsContent = $settingsContent.Replace('{{DEFAULT_MODEL}}', $DEFAULT_MODEL)
    Set-Content ".claude/settings.local.json" $settingsContent -Encoding UTF8 -NoNewline
} else {
    Write-Host "[DRY-RUN] Would copy settings.local.json and replace model placeholder"
}

# -- Copy MCP server config --

Write-Host "Copying MCP server config..."
if (-not $DryRun) {
    Copy-Item "$FRAMEWORK_DIR/templates/mcp.json" ".mcp.json" -Force
    Write-Host "  + .mcp.json (Context7 documentation server)"
} else {
    Write-Host "[DRY-RUN] Would copy .mcp.json (Context7 documentation server)"
}

# -- Install user-level settings.json --

$CLAUDE_HOME = Join-Path $env:USERPROFILE ".claude"

if (-not $DryRun) {
    New-Item -ItemType Directory -Force -Path $CLAUDE_HOME | Out-Null

    if (-not (Test-Path (Join-Path $CLAUDE_HOME "settings.json"))) {
        Write-Host "Installing user-level settings.json..."
        Copy-Item "$FRAMEWORK_DIR/templates/settings.json" (Join-Path $CLAUDE_HOME "settings.json") -Force
        Write-Host "  + ~/.claude/settings.json (AI factory permissions)"
    } else {
        Write-Host "  ~/.claude/settings.json already exists - skipping"
    }

    Copy-Item "$FRAMEWORK_DIR/templates/statusline/statusline-command.sh" ".claude/statusline/statusline-command.sh" -Force
} else {
    Write-Host "[DRY-RUN] Would install user-level settings.json and statusline config"
}

# -- Create CLAUDE.md if none exists --

if (-not (Test-Path "CLAUDE.md")) {
    if (-not $DryRun) {
        Write-Host "Creating CLAUDE.md..."
        Copy-Item "$FRAMEWORK_DIR/templates/CLAUDE.md.template" "CLAUDE.md"

        $claudeContent = Get-Content "CLAUDE.md" -Raw -Encoding UTF8
        $claudeContent = $claudeContent.Replace('{{BASE_BRANCH}}', $BASE_BRANCH)
        $claudeContent = $claudeContent.Replace('{{PROJECT_SHORT_NAME}}', $PROJECT_SHORT)
        $claudeContent = $claudeContent.Replace('{{TRACKER_CONFIG}}', $TRACKER_CONFIG)
        $claudeContent = $claudeContent.Replace('{{FORMAT_COMMAND}}', $FORMAT_CMD)
        $claudeContent = $claudeContent.Replace('{{FORMAT_VERIFY_COMMAND}}', $FORMAT_VERIFY)
        $claudeContent = $claudeContent.Replace('{{TEST_COMMAND}}', $TEST_CMD)
        $claudeContent = $claudeContent.Replace('{{DEPLOY_VALIDATE_COMMAND}}', $DEPLOY_VALIDATE)
        $claudeContent = $claudeContent.Replace('{{TYPE_CHECK_COMMAND}}', $TYPE_CHECK_CMD)
        $claudeContent = $claudeContent.Replace('{{DESIGN_COLOR_RULES}}', $DESIGN_COLOR_RULES)
        $claudeContent = $claudeContent.Replace('{{DESIGN_COMPONENT_IMPORTS}}', $DESIGN_COMPONENT_IMPORTS)
        $claudeContent = $claudeContent.Replace('{{DESIGN_ICON_USAGE}}', $DESIGN_ICON_USAGE)
        $claudeContent = $claudeContent.Replace('{{DESIGN_CARD_PATTERNS}}', $DESIGN_CARD_PATTERNS)
        $claudeContent = $claudeContent.Replace('{{DESIGN_DARK_MODE}}', $DESIGN_DARK_MODE)
        # Project description placeholders - filled by /improve on first run
        $claudeContent = $claudeContent.Replace('{{PROJECT_DESCRIPTION}}', '_Not yet documented. Run `/improve` on your first session to auto-populate this from README, package metadata, and code analysis — or edit manually._')
        $claudeContent = $claudeContent.Replace('{{TECH_STACK_TABLE}}', "| Layer | Technology |`n|-------|-----------|`n| _TBD_ | _Run ``/improve`` to auto-detect_ |")
        $claudeContent = $claudeContent.Replace('{{CODE_STRUCTURE}}', '# Run `/improve` to generate a directory tree from the actual project structure.')
        $claudeContent = $claudeContent.Replace('{{CODING_STANDARDS}}', '_Documented in `.claude/rules/`. Run `/improve` to extract and summarize project-specific conventions here._')
        $claudeContent = $claudeContent.Replace('{{ERROR_HANDLING_PATTERN}}', '_See `.claude/rules/error-handling.md` for framework-level rules. Run `/improve` to document project-specific error conventions._')
        $claudeContent = $claudeContent.Replace('{{TESTING_STRATEGY}}', '_See `.claude/rules/tests.md` for framework-level rules. Run `/improve` to document project-specific testing strategy._')
        $claudeContent = $claudeContent.Replace('{{INTEGRATIONS}}', '_External integrations were configured via the setup wizard. Run `/improve` to list and document them here._')
        Set-Content "CLAUDE.md" $claudeContent -Encoding UTF8 -NoNewline

        Write-Host "  Created CLAUDE.md (fill in project-specific sections marked with {{...}})"
    } else {
        Write-Host "[DRY-RUN] Would create CLAUDE.md from template with placeholders replaced"
    }
} else {
    Write-Host "  CLAUDE.md already exists - skipping"
}

# -- GitHub Actions workflows --

if ($CI_NAME -eq "github-actions") {
    Write-Host "Creating GitHub Actions workflows..."
    if (-not $DryRun) {
        New-Item -ItemType Directory -Force -Path ".github/workflows" | Out-Null
        Get-ChildItem "$FRAMEWORK_DIR/workflows" -Filter "*.yml" | ForEach-Object {
            Copy-Item $_.FullName ".github/workflows/$($_.Name)" -Force
            Write-Host "  + $($_.Name)"
        }
    } else {
        Write-Host "[DRY-RUN] Would create .github/workflows/ and copy CI/CD pipeline files"
    }
}

# -- Install Claude Code hooks to user home --

Write-Host "Setting up Claude Code hooks..."
$CLAUDE_HOOKS_HOME = Join-Path $env:USERPROFILE ".claude\hooks"

if (-not $DryRun) {
    New-Item -ItemType Directory -Force -Path $CLAUDE_HOOKS_HOME | Out-Null

    $sessionStopDest = Join-Path $CLAUDE_HOOKS_HOME "session-stop.sh"
    if (-not (Test-Path $sessionStopDest)) {
        Copy-Item "$FRAMEWORK_DIR/templates/hooks/session-stop.sh" $sessionStopDest -Force
        Write-Host "  + Session stop sound hook"
    }
} else {
    Write-Host "[DRY-RUN] Would install session stop hook to ~/.claude/hooks/"
}

# -- Set up pre-commit hooks (formatting + linting) --

Write-Host "Setting up pre-commit hooks..."

# Driven by config/precommit.json — single source of truth shared with setup.sh
$precommitCfgPath = Join-Path $FRAMEWORK_DIR "config/precommit.json"
if (Test-Path $precommitCfgPath) {
    $precommitCfg = Get-Content $precommitCfgPath -Raw | ConvertFrom-Json
    $entry = $precommitCfg.$PROJECT_TYPE_NAME
    if (-not $entry) { $entry = $precommitCfg.generic }

    # Mode 1: always_messages
    if ($entry.always_messages) {
        foreach ($line in $entry.always_messages) {
            if ($line.StartsWith(' ')) { Write-Host $line } else { Write-Host "  $line" }
        }
    }

    # Mode 2: detect-based
    if ($entry.detect) {
        $detect = $entry.detect
        $configured = $false
        $skip = $false
        if ($detect.mode -eq 'file_contains') {
            $detectFile = Join-Path $PROJECT_DIR $detect.file
            if (Test-Path $detectFile) {
                $content = Get-Content $detectFile -Raw -ErrorAction SilentlyContinue
                if ($content -and $content.Contains($detect.needle)) { $configured = $true }
            } else {
                $skip = $true
            }
        } elseif ($detect.mode -eq 'command_missing') {
            $configured = [bool](Get-Command $detect.command -ErrorAction SilentlyContinue)
        }

        if (-not $skip) {
            if ($configured -and $entry.if_detected_message) {
                Write-Host "  $($entry.if_detected_message)"
            } elseif (-not $configured) {
                foreach ($line in $entry.if_missing_messages) {
                    if ($line.StartsWith(' ')) { Write-Host $line } else { Write-Host "  $line" }
                }
            }
        }
    }

    # Mode 3: config file creation
    if ($entry.config_file) {
        $target = Join-Path $PROJECT_DIR $entry.config_file
        if (-not (Test-Path $target)) {
            if (-not $DryRun) {
                $body = ($entry.config_body_lines -join "`n") + "`n"
                Set-Content $target $body -Encoding UTF8 -NoNewline
                foreach ($line in $entry.config_created_messages) {
                    if ($line.StartsWith(' ')) { Write-Host $line } else { Write-Host "  $line" }
                }
            } else {
                Write-Host "[DRY-RUN] Would create $($entry.config_file)"
            }
        }
    }
}

# -- Install framework pre-commit hook (secret scan + size guard) --
# Installs .claude/hooks/pre-commit.sh as .git/hooks/pre-commit.
# This layer is independent of husky/pre-commit-framework — it adds
# secret scanning and large-file detection. Skips if another pre-commit is already present.

$gitHooksDir = Join-Path $PROJECT_DIR ".git/hooks"
$hookTarget  = Join-Path $gitHooksDir "pre-commit"
$hookSource  = Join-Path $PROJECT_DIR ".claude/hooks/pre-commit.sh"
$sentinel    = "Claude Code Framework — Pre-commit Quality Gate"

if (-not (Test-Path $gitHooksDir)) {
    Write-Host "  Skipping framework pre-commit install (no .git directory)"
} elseif (-not (Test-Path $hookSource)) {
    Write-Host "  Skipping framework pre-commit install (hook source missing)"
} elseif (-not (Test-Path $hookTarget)) {
    if (-not $DryRun) {
        Copy-Item $hookSource $hookTarget -Force
        Write-Host "  + Installed framework pre-commit at .git/hooks/pre-commit (secret scan + size guard)"
    } else {
        Write-Host "[DRY-RUN] Would install framework pre-commit at .git/hooks/pre-commit"
    }
} elseif ((Get-Content $hookTarget -Raw -ErrorAction SilentlyContinue) -match [regex]::Escape($sentinel)) {
    # Ours — only refresh if byte-identical. Preserves user edits.
    $existingHash = (Get-FileHash $hookTarget -Algorithm SHA256).Hash
    $sourceHash   = (Get-FileHash $hookSource -Algorithm SHA256).Hash
    if ($existingHash -ne $sourceHash) {
        Write-Host "  Framework pre-commit at .git/hooks/pre-commit has been modified from the shipped version."
        Write-Host "  Keeping your version to preserve local edits."
        Write-Host "  To refresh, delete .git/hooks/pre-commit and re-run setup."
    }
} else {
    Write-Host "  Existing .git/hooks/pre-commit detected (likely husky or pre-commit framework)."
    Write-Host "  To chain the framework's secret scan + size guard, add this to your existing hook:"
    Write-Host "    bash .claude/hooks/pre-commit.sh || exit 1"
}

# -- Create .env template --

$envFile = Join-Path $PROJECT_DIR ".env"
if (-not (Test-Path $envFile)) {
    if (-not $DryRun) {
        Write-Host "Creating .env template..."
        $envContent = @"
# Claude Code Framework - Environment Variables
# Copy this to .env and fill in your values

# Work Item Tracker
"@

        # Append tracker env vars from config/trackers.json
        $trackerEnvVars = $trackerConfig.env_vars
        if ($trackerEnvVars) {
            foreach ($envVar in $trackerEnvVars) {
                $envContent += "`n$envVar"
            }
        }

        # Append notification env vars from config/notifications.json
        $notifyEnvVar = $notifyCfg.env_var
        $notifyEnvPlaceholder = $notifyCfg.env_placeholder
        if ($notifyEnvVar -and $notifyEnvPlaceholder) {
            $envContent += "`n$notifyEnvVar=$notifyEnvPlaceholder"
        }

        Set-Content $envFile $envContent -Encoding UTF8

        # Ensure .env is gitignored
        $gitignoreFile = Join-Path $PROJECT_DIR ".gitignore"
        if (Test-Path $gitignoreFile) {
            $gitignoreContent = Get-Content $gitignoreFile -Raw -ErrorAction SilentlyContinue
            if ($gitignoreContent -and -not ($gitignoreContent -match '(?m)^\.env$')) {
                Add-Content $gitignoreFile "`n.env"
            }
        }

        # Ensure .claude/state/ is gitignored (post-coding-review.sh writes cooldown state)
        if (Test-Path $gitignoreFile) {
            $gitignoreContent = Get-Content $gitignoreFile -Raw -ErrorAction SilentlyContinue
            if ($gitignoreContent -and -not ($gitignoreContent -match '(?m)^\.claude/state/')) {
                Add-Content $gitignoreFile "`n.claude/state/"
            }
        } elseif (Test-Path (Join-Path $PROJECT_DIR ".git")) {
            Set-Content $gitignoreFile ".claude/state/`n" -Encoding UTF8
        }
    } else {
        Write-Host "[DRY-RUN] Would create .env template and update .gitignore"
    }
}

# ============================================================
# Summary
# ============================================================

Write-Host ""
Write-Host "======================================"
Write-Host "  Setup Complete!"
Write-Host "======================================"
Write-Host ""
Write-Host "Project:     $PROJECT_NAME"
Write-Host "Type:        $PROJECT_TYPE_NAME"
Write-Host "Tracker:     $TRACKER_NAME"
Write-Host "CI/CD:       $CI_NAME"
Write-Host "Base branch: $BASE_BRANCH"
Write-Host "Notify:      $NOTIFY_NAME"
Write-Host "Design:      $DESIGN_SYSTEM_NAME"
Write-Host ""
Write-Host "Files created:"
Write-Host "  .claude/skills/         - 20 workflow skills (incl. /team, /improve, /plan, /build, /iterative-review)"
Write-Host "  .claude/agents/         - 35 AI agents (12 reviewers + 12 review specialists + 4 planning specialists + 4 build specialists + 3 coordinators)"
Write-Host "  .claude/commands/       - 6 quick commands (quick-test, lint-fix, check-types, branch-status, changelog, dep-check)"
Write-Host "  .claude/rules/          - 22 coding guardrails (api-routes, tests, database, config, error-handling, auth-security, data-protection, design-system, components, code-smells, dry, purity, complexity, frontend-architecture, architecture-layering, api-layering, crypto, solid, concurrency, observability, supply-chain, secrets-management)"
Write-Host "  .claude/hooks/          - 6 lifecycle hooks (guardrails, post-edit-sync, session-start, session-stop, post-coding-review, pre-commit)"
Write-Host "  .claude/settings.local.json - project permissions, hooks"
Write-Host "  .mcp.json               - MCP servers (Context7 documentation)"
Write-Host "  ~/.claude/settings.json - user-level AI factory permissions (team orchestration enabled)"
Write-Host "  .claude/statusline/"
if ($CI_NAME -eq "github-actions") {
    Write-Host "  .github/workflows/      - 4 CI/CD pipelines"
}
Write-Host "  docs/stories/           - story documentation folder"
Write-Host ""
Write-Host "Next steps:"
Write-Host "  1. Run /improve to auto-fill CLAUDE.md from project analysis"
Write-Host "  2. Configure .env with your credentials"
Write-Host "  3. Try /team review for a full codebase assessment"
Write-Host "  4. Add domain knowledge: /add-reference my-domain topic"
Write-Host "  5. Start developing: /develop TICKET-123"
Write-Host ""
