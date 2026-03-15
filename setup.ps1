# Claude Code Framework — Interactive Setup Wizard (Windows PowerShell)
# Usage: cd your-project/ ; & ~/Developer/claude-code-framework/setup.ps1

$ErrorActionPreference = "Stop"

$FRAMEWORK_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path
$PROJECT_DIR = Get-Location
$PROJECT_NAME = Split-Path -Leaf $PROJECT_DIR

Write-Host "======================================"
Write-Host "  Claude Code Framework Setup"
Write-Host "======================================"
Write-Host ""
Write-Host "Project: $PROJECT_NAME"
Write-Host "Directory: $PROJECT_DIR"
Write-Host ""

# -- 1. Project Type --

Write-Host "What type of project is this?"
Write-Host "  1) Node.js / TypeScript"
Write-Host "  2) Python"
Write-Host "  3) Go"
Write-Host "  4) Java / Spring Boot"
Write-Host "  5) React / Next.js"
Write-Host "  6) Ruby on Rails"
Write-Host "  7) Other"
$PROJECT_TYPE = Read-Host "Choice [1-7]"

$PROJECT_TYPE_NAME = switch ($PROJECT_TYPE) {
    "1" { "nodejs" }
    "2" { "python" }
    "3" { "go" }
    "4" { "java" }
    "5" { "react" }
    "6" { "rails" }
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
$TRACKER_TYPE = Read-Host "Choice [1-5]"

$TRACKER_NAME = switch ($TRACKER_TYPE) {
    "1" { "ado" }
    "2" { "jira" }
    "3" { "linear" }
    "4" { "github" }
    default { "none" }
}

$TRACKER_CONFIG = ""
switch ($TRACKER_NAME) {
    "ado" {
        $ADO_ORG = Read-Host "ADO Organization"
        $ADO_PROJECT = Read-Host "ADO Project"
        $TRACKER_CONFIG = @"
- **Organization:** ``$ADO_ORG``
- **Project:** ``$ADO_PROJECT``
- **URL:** https://dev.azure.com/$ADO_ORG/$ADO_PROJECT
- **Auth:** PAT stored in ``.env`` as ``AZURE_DEVOPS_EXT_PAT``
"@
    }
    "jira" {
        $JIRA_DOMAIN = Read-Host "Jira Domain (e.g., mycompany.atlassian.net)"
        $JIRA_PROJECT = Read-Host "Jira Project Key (e.g., PROJ)"
        $TRACKER_CONFIG = @"
- **Domain:** ``$JIRA_DOMAIN``
- **Project:** ``$JIRA_PROJECT``
- **Auth:** API token in ``.env`` as ``JIRA_API_TOKEN`` and email as ``JIRA_EMAIL``
"@
    }
    "linear" {
        $LINEAR_TEAM = Read-Host "Linear Team ID"
        $TRACKER_CONFIG = @"
- **Team:** ``$LINEAR_TEAM``
- **Auth:** API key in ``.env`` as ``LINEAR_API_KEY``
"@
    }
    "github" {
        $TRACKER_CONFIG = "- **Tracker:** GitHub Issues (uses ``gh`` CLI)`n- **Auth:** ``gh auth login``"
    }
    "none" {
        $TRACKER_CONFIG = "- No work item tracker configured. Tickets managed manually."
    }
}

# -- 3. CI/CD Platform --

Write-Host ""
Write-Host "What CI/CD platform do you use?"
Write-Host "  1) GitHub Actions"
Write-Host "  2) GitLab CI"
Write-Host "  3) CircleCI"
Write-Host "  4) None / Manual"
$CI_TYPE = Read-Host "Choice [1-4]"

$CI_NAME = switch ($CI_TYPE) {
    "1" { "github-actions" }
    "2" { "gitlab-ci" }
    "3" { "circleci" }
    default { "none" }
}

# -- 4. Base Branch --

Write-Host ""
$BASE_BRANCH = Read-Host "Primary integration branch [develop]"
if (-not $BASE_BRANCH) { $BASE_BRANCH = "develop" }

# -- 5. Notification System --

Write-Host ""
Write-Host "What notification system do you use?"
Write-Host "  1) Slack"
Write-Host "  2) Microsoft Teams"
Write-Host "  3) Discord"
Write-Host "  4) None"
$NOTIFY_TYPE = Read-Host "Choice [1-4]"

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
    }
}

# -- Create directories --

New-Item -ItemType Directory -Force -Path ".claude/skills" | Out-Null
New-Item -ItemType Directory -Force -Path ".claude/statusline" | Out-Null
New-Item -ItemType Directory -Force -Path "docs/stories" | Out-Null

# -- Copy skills --

Write-Host "Copying skills..."
Get-ChildItem -Directory "$FRAMEWORK_DIR/skills" | ForEach-Object {
    Copy-Item -Recurse -Force $_.FullName ".claude/skills/$($_.Name)"
    Write-Host "  + /$($_.Name)"
}

# -- Build project-type-specific commands --

$FORMAT_CMD = ""
$FORMAT_VERIFY = ""
$TEST_CMD = ""
$DEPLOY_VALIDATE = ""

switch ($PROJECT_TYPE_NAME) {
    { $_ -in "nodejs", "react" } {
        $FORMAT_CMD = 'npx prettier --write "path/to/file"'
        $FORMAT_VERIFY = 'npx prettier --check .'
        $TEST_CMD = 'npm test'
        $DEPLOY_VALIDATE = 'npm run build && npm test'
    }
    "python" {
        $FORMAT_CMD = 'black path/to/file.py'
        $FORMAT_VERIFY = 'black --check . && ruff check .'
        $TEST_CMD = 'pytest'
        $DEPLOY_VALIDATE = 'pytest && mypy .'
    }
    "go" {
        $FORMAT_CMD = 'gofmt -w path/to/file.go'
        $FORMAT_VERIFY = 'gofmt -l .'
        $TEST_CMD = 'go test ./...'
        $DEPLOY_VALIDATE = 'go build ./... && go test ./... && go vet ./...'
    }
    "java" {
        $FORMAT_CMD = './gradlew spotlessApply'
        $FORMAT_VERIFY = './gradlew spotlessCheck'
        $TEST_CMD = './gradlew test'
        $DEPLOY_VALIDATE = './gradlew build test'
    }
    "rails" {
        $FORMAT_CMD = 'bundle exec rubocop -a path/to/file.rb'
        $FORMAT_VERIFY = 'bundle exec rubocop'
        $TEST_CMD = 'bundle exec rspec'
        $DEPLOY_VALIDATE = 'bundle exec rspec && bundle exec rubocop'
    }
    default {
        $FORMAT_CMD = '# Configure your formatter command'
        $FORMAT_VERIFY = '# Configure your format verification command'
        $TEST_CMD = '# Configure your test command'
        $DEPLOY_VALIDATE = '# Configure your validation command'
    }
}

# -- Build tracker commands --

$TRACKER_FETCH = ""
$TRACKER_SET_PROGRESS = ""
$TRACKER_SET_REVIEW = ""
$TRACKER_URL = ""

switch ($TRACKER_NAME) {
    "github" {
        $TRACKER_FETCH = "``````bash`ngh issue view {number} --json title,body,state,labels,assignees`n``````"
        $TRACKER_URL = "https://github.com/org/repo/issues/{number}"
        $TRACKER_SET_PROGRESS = "``````bash`ngh issue edit {number} --add-label `"in-progress`"`n``````"
        $TRACKER_SET_REVIEW = "``````bash`ngh issue edit {number} --add-label `"in-review`" --remove-label `"in-progress`"`n``````"
    }
    "none" {
        $TRACKER_FETCH = "No work item tracker configured. Ask user for ticket details."
        $TRACKER_SET_PROGRESS = "No tracker configured."
        $TRACKER_SET_REVIEW = "No tracker configured."
    }
}

# -- Replace placeholders in skill files --

Write-Host "Configuring skills for your project..."

$replacements = @{
    '{{BASE_BRANCH}}'              = $BASE_BRANCH
    '{{PROJECT_SHORT_NAME}}'       = $PROJECT_SHORT
    '{{FORMAT_COMMAND}}'           = $FORMAT_CMD
    '{{FORMAT_VERIFY_COMMAND}}'    = $FORMAT_VERIFY
    '{{TEST_COMMAND}}'             = $TEST_CMD
    '{{DEPLOY_VALIDATE_COMMAND}}'  = $DEPLOY_VALIDATE
    '{{FACTORY_LOCAL_VALIDATION}}' = $DEPLOY_VALIDATE
    '{{TRACKER_FETCH_TICKET}}'     = $TRACKER_FETCH
    '{{TRACKER_SET_IN_PROGRESS}}'  = $TRACKER_SET_PROGRESS
    '{{TRACKER_SET_IN_REVIEW}}'    = $TRACKER_SET_REVIEW
    '{{TRACKER_TICKET_URL}}'       = $TRACKER_URL
    '{{TRACKER_LINK_PR}}'          = 'Linked automatically via PR body "Closes #number".'
    '{{TRACKER_CREATE_TICKET}}'    = 'gh issue create --title "TITLE" --body "BODY"'
    '{{TRACKER_CREATE_BUG}}'       = 'gh issue create --title "Bug: TITLE" --body "BODY" --label bug'
    '{{TRACKER_UPDATE_FIELDS}}'    = 'Use gh issue edit to update labels and assignees.'
    '{{TRACKER_SET_DEPLOYED}}'     = 'gh issue edit {number} --add-label "deployed"'
    '{{NOTIFY_HALT}}'              = 'Log halt message.'
    '{{NOTIFY_HALT_FACTORY}}'      = 'Log halt message.'
    '{{NOTIFY_DEPLOY_SUCCESS}}'    = 'Log deploy success.'
    '{{ERROR_QUERY_COMMAND}}'      = 'Configure error query command for your monitoring system.'
    '{{ERROR_UPDATE_STATUS}}'      = 'Configure error status update command.'
    '{{ERROR_DISMISS}}'            = 'Configure error dismiss command.'
    '{{DEPLOY_COMMAND}}'           = $DEPLOY_VALIDATE
}

$skillFiles = Get-ChildItem -Recurse ".claude/skills" -Filter "*.md"
$updatedCount = 0
foreach ($file in $skillFiles) {
    $content = Get-Content $file.FullName -Raw -Encoding UTF8
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
Write-Host "  Updated $updatedCount skill files"

# -- Copy settings --

Write-Host "Copying settings..."
Copy-Item "$FRAMEWORK_DIR/templates/settings.local.json" ".claude/settings.local.json" -Force
Copy-Item "$FRAMEWORK_DIR/templates/statusline/statusline-command.sh" ".claude/statusline/statusline-command.sh" -Force

# -- Create CLAUDE.md if none exists --

if (-not (Test-Path "CLAUDE.md")) {
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
    Set-Content "CLAUDE.md" $claudeContent -Encoding UTF8 -NoNewline

    Write-Host "  Created CLAUDE.md (fill in project-specific sections marked with {{...}})"
} else {
    Write-Host "  CLAUDE.md already exists - skipping"
}

# -- GitHub Actions workflows --

if ($CI_NAME -eq "github-actions") {
    Write-Host "Creating GitHub Actions workflows..."
    New-Item -ItemType Directory -Force -Path ".github/workflows" | Out-Null
    Get-ChildItem "$FRAMEWORK_DIR/workflows" -Filter "*.yml" | ForEach-Object {
        Copy-Item $_.FullName ".github/workflows/$($_.Name)" -Force
        Write-Host "  + $($_.Name)"
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
Write-Host ""
Write-Host "Files created:"
Write-Host "  .claude/skills/         - workflow skills"
Write-Host "  .claude/settings.local.json"
Write-Host "  .claude/statusline/"
if ($CI_NAME -eq "github-actions") {
    Write-Host "  .github/workflows/      - CI/CD pipelines"
}
Write-Host "  docs/stories/           - story documentation folder"
Write-Host ""
Write-Host "Next steps:"
Write-Host "  1. Fill in CLAUDE.md sections marked with {{...}}"
Write-Host "  2. Configure .env with your credentials"
Write-Host "  3. Try it: /develop TICKET-123"
Write-Host ""
