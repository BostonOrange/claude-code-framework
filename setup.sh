#!/bin/bash
# Claude Code Framework — Interactive Setup Wizard
# Usage: cd your-project/ && bash ~/Developer/claude-code-framework/setup.sh

set -e

FRAMEWORK_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(pwd)"
PROJECT_NAME="$(basename "$PROJECT_DIR")"

echo "======================================"
echo "  Claude Code Framework Setup"
echo "======================================"
echo ""
echo "Project: $PROJECT_NAME"
echo "Directory: $PROJECT_DIR"
echo ""

# ── 1. Project Type ──────────────────────────────────────────────

echo "What type of project is this?"
echo "  1) Node.js / TypeScript"
echo "  2) Python"
echo "  3) Go"
echo "  4) Java / Spring Boot"
echo "  5) React / Next.js"
echo "  6) Ruby on Rails"
echo "  7) Other"
read -p "Choice [1-7]: " PROJECT_TYPE

case $PROJECT_TYPE in
    1) PROJECT_TYPE_NAME="nodejs" ;;
    2) PROJECT_TYPE_NAME="python" ;;
    3) PROJECT_TYPE_NAME="go" ;;
    4) PROJECT_TYPE_NAME="java" ;;
    5) PROJECT_TYPE_NAME="react" ;;
    6) PROJECT_TYPE_NAME="rails" ;;
    7) PROJECT_TYPE_NAME="generic" ;;
    *) PROJECT_TYPE_NAME="generic" ;;
esac

# ── 2. Work Item Tracker ────────────────────────────────────────

echo ""
echo "What work item tracker do you use?"
echo "  1) Azure DevOps"
echo "  2) Jira"
echo "  3) Linear"
echo "  4) GitHub Issues"
echo "  5) None"
read -p "Choice [1-5]: " TRACKER_TYPE

case $TRACKER_TYPE in
    1) TRACKER_NAME="ado" ;;
    2) TRACKER_NAME="jira" ;;
    3) TRACKER_NAME="linear" ;;
    4) TRACKER_NAME="github" ;;
    5) TRACKER_NAME="none" ;;
    *) TRACKER_NAME="none" ;;
esac

# Tracker-specific config
TRACKER_CONFIG=""
case $TRACKER_NAME in
    ado)
        read -p "ADO Organization: " ADO_ORG
        read -p "ADO Project: " ADO_PROJECT
        TRACKER_CONFIG="- **Organization:** \`$ADO_ORG\`
- **Project:** \`$ADO_PROJECT\`
- **URL:** https://dev.azure.com/$ADO_ORG/$ADO_PROJECT
- **Auth:** PAT stored in \`.env\` as \`AZURE_DEVOPS_EXT_PAT\`"
        ;;
    jira)
        read -p "Jira Domain (e.g., mycompany.atlassian.net): " JIRA_DOMAIN
        read -p "Jira Project Key (e.g., PROJ): " JIRA_PROJECT
        TRACKER_CONFIG="- **Domain:** \`$JIRA_DOMAIN\`
- **Project:** \`$JIRA_PROJECT\`
- **Auth:** API token in \`.env\` as \`JIRA_API_TOKEN\` and email as \`JIRA_EMAIL\`"
        ;;
    linear)
        read -p "Linear Team ID: " LINEAR_TEAM
        TRACKER_CONFIG="- **Team:** \`$LINEAR_TEAM\`
- **Auth:** API key in \`.env\` as \`LINEAR_API_KEY\`"
        ;;
    github)
        TRACKER_CONFIG="- **Tracker:** GitHub Issues (uses \`gh\` CLI)
- **Auth:** \`gh auth login\`"
        ;;
    none)
        TRACKER_CONFIG="- No work item tracker configured. Tickets managed manually."
        ;;
esac

# ── 3. CI/CD Platform ───────────────────────────────────────────

echo ""
echo "What CI/CD platform do you use?"
echo "  1) GitHub Actions"
echo "  2) GitLab CI"
echo "  3) CircleCI"
echo "  4) None / Manual"
read -p "Choice [1-4]: " CI_TYPE

case $CI_TYPE in
    1) CI_NAME="github-actions" ;;
    2) CI_NAME="gitlab-ci" ;;
    3) CI_NAME="circleci" ;;
    4) CI_NAME="none" ;;
    *) CI_NAME="none" ;;
esac

# ── 4. Base Branch ──────────────────────────────────────────────

echo ""
read -p "Primary integration branch [develop]: " BASE_BRANCH
BASE_BRANCH="${BASE_BRANCH:-develop}"

# ── 5. Notification System ──────────────────────────────────────

echo ""
echo "What notification system do you use?"
echo "  1) Slack"
echo "  2) Microsoft Teams"
echo "  3) Discord"
echo "  4) None"
read -p "Choice [1-4]: " NOTIFY_TYPE

case $NOTIFY_TYPE in
    1) NOTIFY_NAME="slack" ;;
    2) NOTIFY_NAME="teams" ;;
    3) NOTIFY_NAME="discord" ;;
    4) NOTIFY_NAME="none" ;;
    *) NOTIFY_NAME="none" ;;
esac

# ── 6. Project Short Name (for worktrees) ───────────────────────

echo ""
read -p "Short project name (for worktrees, e.g., 'myapp'): " PROJECT_SHORT
PROJECT_SHORT="${PROJECT_SHORT:-$PROJECT_NAME}"

# ═══════════════════════════════════════════════════════════════
# Generate project files
# ═══════════════════════════════════════════════════════════════

echo ""
echo "Setting up Claude Code framework..."
echo ""

# ── Ensure base branch exists ───────────────────────────────────

if git rev-parse --git-dir > /dev/null 2>&1; then
    CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
    if [ "$CURRENT_BRANCH" != "$BASE_BRANCH" ]; then
        echo "Renaming branch '$CURRENT_BRANCH' -> '$BASE_BRANCH'..."
        git branch -m "$CURRENT_BRANCH" "$BASE_BRANCH"

        # Update remote if it exists
        if git remote get-url origin > /dev/null 2>&1; then
            echo "Pushing '$BASE_BRANCH' to remote..."
            git push -u origin "$BASE_BRANCH" 2>/dev/null || true

            # Try to set default branch (requires gh CLI)
            if command -v gh &> /dev/null; then
                gh repo edit --default-branch "$BASE_BRANCH" 2>/dev/null || true
            fi

            # Delete old remote branch
            git push origin --delete "$CURRENT_BRANCH" 2>/dev/null || true
        fi
    fi
fi

# ── Create .claude directory ─────────────────────────────────────

mkdir -p "$PROJECT_DIR/.claude/skills"
mkdir -p "$PROJECT_DIR/.claude/statusline"
mkdir -p "$PROJECT_DIR/docs/stories"

# ── Copy skills ──────────────────────────────────────────────────

echo "Copying skills..."
for skill_dir in "$FRAMEWORK_DIR/skills"/*/; do
    skill_name=$(basename "$skill_dir")
    if [ -d "$skill_dir" ]; then
        cp -r "$skill_dir" "$PROJECT_DIR/.claude/skills/$skill_name"
        echo "  + /$(basename "$skill_dir")"
    fi
done

# ── Replace placeholders in skills ───────────────────────────────

echo "Configuring skills for your project..."

# Build tracker-specific command blocks
TRACKER_FETCH=""
TRACKER_CREATE=""
TRACKER_SET_PROGRESS=""
TRACKER_SET_REVIEW=""
TRACKER_LINK_PR=""
TRACKER_URL=""

case $TRACKER_NAME in
    ado)
        TRACKER_FETCH='```bash
PAT=$(grep AZURE_DEVOPS_EXT_PAT .env | cut -d= -f2)
curl -s "https://dev.azure.com/'"$ADO_ORG"'/'"$ADO_PROJECT"'/_apis/wit/workitems/{id}?api-version=7.1&\$expand=all" -u ":${PAT}"
```'
        TRACKER_URL="https://dev.azure.com/$ADO_ORG/$ADO_PROJECT/_workitems/edit/{id}"
        TRACKER_SET_PROGRESS='```bash
PAT=$(grep AZURE_DEVOPS_EXT_PAT .env | cut -d= -f2)
curl -s -X PATCH "https://dev.azure.com/'"$ADO_ORG"'/'"$ADO_PROJECT"'/_apis/wit/workitems/{id}?api-version=7.1" \
  -H "Content-Type: application/json-patch+json" -u ":${PAT}" \
  -d '"'"'[{"op": "replace", "path": "/fields/System.State", "value": "In Progress"}]'"'"'
```'
        TRACKER_SET_REVIEW='```bash
PAT=$(grep AZURE_DEVOPS_EXT_PAT .env | cut -d= -f2)
curl -s -X PATCH "https://dev.azure.com/'"$ADO_ORG"'/'"$ADO_PROJECT"'/_apis/wit/workitems/{id}?api-version=7.1" \
  -H "Content-Type: application/json-patch+json" -u ":${PAT}" \
  -d '"'"'[{"op": "replace", "path": "/fields/System.State", "value": "In Peer Testing"}]'"'"'
```'
        ;;
    jira)
        TRACKER_FETCH='```bash
curl -s "https://'"$JIRA_DOMAIN"'/rest/api/3/issue/{key}" \
  -H "Authorization: Basic $(echo -n $(grep JIRA_EMAIL .env | cut -d= -f2):$(grep JIRA_API_TOKEN .env | cut -d= -f2) | base64)"
```'
        TRACKER_URL="https://$JIRA_DOMAIN/browse/{key}"
        TRACKER_SET_PROGRESS='Use Jira REST API to transition issue to "In Progress".'
        TRACKER_SET_REVIEW='Use Jira REST API to transition issue to "In Review".'
        ;;
    github)
        TRACKER_FETCH='```bash
gh issue view {number} --json title,body,state,labels,assignees
```'
        TRACKER_URL="$(git remote get-url origin 2>/dev/null | sed 's/\.git$//' || echo 'https://github.com/org/repo')/issues/{number}"
        TRACKER_SET_PROGRESS='```bash
gh issue edit {number} --add-label "in-progress"
```'
        TRACKER_SET_REVIEW='```bash
gh issue edit {number} --add-label "in-review" --remove-label "in-progress"
```'
        ;;
    linear)
        TRACKER_FETCH='Use Linear GraphQL API to fetch issue by identifier.'
        TRACKER_URL="https://linear.app/team/$LINEAR_TEAM/issue/{id}"
        TRACKER_SET_PROGRESS='Use Linear GraphQL API to update issue state to "In Progress".'
        TRACKER_SET_REVIEW='Use Linear GraphQL API to update issue state to "In Review".'
        ;;
    none)
        TRACKER_FETCH='No work item tracker configured. Ask user for ticket details.'
        TRACKER_URL=""
        TRACKER_SET_PROGRESS='No tracker configured.'
        TRACKER_SET_REVIEW='No tracker configured.'
        ;;
esac

# Build project-type-specific commands
FORMAT_CMD=""
FORMAT_VERIFY=""
TEST_CMD=""
DEPLOY_VALIDATE=""

case $PROJECT_TYPE_NAME in
    nodejs|react)
        FORMAT_CMD='npx prettier --write "path/to/file"'
        FORMAT_VERIFY='npx prettier --check .'
        TEST_CMD='npm test'
        DEPLOY_VALIDATE='npm run build && npm test'
        ;;
    python)
        FORMAT_CMD='black path/to/file.py'
        FORMAT_VERIFY='black --check . && ruff check .'
        TEST_CMD='pytest'
        DEPLOY_VALIDATE='pytest && mypy .'
        ;;
    go)
        FORMAT_CMD='gofmt -w path/to/file.go'
        FORMAT_VERIFY='gofmt -l . | grep -q . && echo "needs formatting" || echo "ok"'
        TEST_CMD='go test ./...'
        DEPLOY_VALIDATE='go build ./... && go test ./... && go vet ./...'
        ;;
    java)
        FORMAT_CMD='./gradlew spotlessApply'
        FORMAT_VERIFY='./gradlew spotlessCheck'
        TEST_CMD='./gradlew test'
        DEPLOY_VALIDATE='./gradlew build test'
        ;;
    rails)
        FORMAT_CMD='bundle exec rubocop -a path/to/file.rb'
        FORMAT_VERIFY='bundle exec rubocop'
        TEST_CMD='bundle exec rspec'
        DEPLOY_VALIDATE='bundle exec rspec && bundle exec rubocop'
        ;;
    *)
        FORMAT_CMD='# Configure your formatter command'
        FORMAT_VERIFY='# Configure your format verification command'
        TEST_CMD='# Configure your test command'
        DEPLOY_VALIDATE='# Configure your validation command'
        ;;
esac

# Build notification command
NOTIFY_CMD=""
case $NOTIFY_NAME in
    slack)
        NOTIFY_CMD='```bash
source .env && curl -s -X POST "${SLACK_WEBHOOK_URL}" \
  -H "Content-Type: application/json" \
  -d "{\"text\":\"Factory halted for {TICKET_ID}: {reason}. Manual intervention needed.\"}"
```'
        ;;
    teams)
        NOTIFY_CMD='```bash
source .env && curl -s -X POST "${TEAMS_WEBHOOK_URL}" \
  -H "Content-Type: application/json" \
  -d "{\"text\":\"Factory halted for {TICKET_ID}: {reason}. Manual intervention needed.\"}"
```'
        ;;
    discord)
        NOTIFY_CMD='```bash
source .env && curl -s -X POST "${DISCORD_WEBHOOK_URL}" \
  -H "Content-Type: application/json" \
  -d "{\"content\":\"Factory halted for {TICKET_ID}: {reason}. Manual intervention needed.\"}"
```'
        ;;
    none)
        NOTIFY_CMD='No notification system configured. Log the halt message.'
        ;;
esac

# Replace placeholders in all skill files
find "$PROJECT_DIR/.claude/skills" -name "*.md" -exec sed -i '' \
    -e "s|{{BASE_BRANCH}}|$BASE_BRANCH|g" \
    -e "s|{{PROJECT_SHORT_NAME}}|$PROJECT_SHORT|g" \
    -e "s|{{FORMAT_COMMAND}}|$FORMAT_CMD|g" \
    -e "s|{{FORMAT_VERIFY_COMMAND}}|$FORMAT_VERIFY|g" \
    -e "s|{{TEST_COMMAND}}|$TEST_CMD|g" \
    -e "s|{{DEPLOY_VALIDATE_COMMAND}}|$DEPLOY_VALIDATE|g" \
    {} +

# Replace multi-line placeholders (tracker commands, notifications)
# These are more complex — write them to temp files and use python for replacement
python3 << 'PYEOF'
import os, glob

project_dir = os.environ.get('PROJECT_DIR', '.')
skills_dir = os.path.join(project_dir, '.claude', 'skills')

replacements = {
    '{{TRACKER_FETCH_TICKET}}': os.environ.get('TRACKER_FETCH', 'Configure tracker fetch command.'),
    '{{TRACKER_SET_IN_PROGRESS}}': os.environ.get('TRACKER_SET_PROGRESS', 'Configure tracker state transition.'),
    '{{TRACKER_SET_IN_REVIEW}}': os.environ.get('TRACKER_SET_REVIEW', 'Configure tracker state transition.'),
    '{{TRACKER_TICKET_URL}}': os.environ.get('TRACKER_URL', '{ticket_url}'),
    '{{TRACKER_LINK_PR}}': os.environ.get('TRACKER_LINK_PR', 'Configure PR-to-ticket linking.'),
    '{{TRACKER_CREATE_TICKET}}': os.environ.get('TRACKER_CREATE', 'Configure ticket creation.'),
    '{{TRACKER_CREATE_BUG}}': os.environ.get('TRACKER_CREATE', 'Configure bug creation.'),
    '{{TRACKER_UPDATE_FIELDS}}': 'Configure tracker field update command.',
    '{{TRACKER_SET_DEPLOYED}}': 'Configure tracker deployed state transition.',
    '{{NOTIFY_HALT}}': os.environ.get('NOTIFY_CMD', 'Log halt message.'),
    '{{NOTIFY_HALT_FACTORY}}': os.environ.get('NOTIFY_CMD', 'Log halt message.'),
    '{{NOTIFY_DEPLOY_SUCCESS}}': os.environ.get('NOTIFY_CMD', 'Log deploy success.').replace('halted', 'deployed').replace('Manual intervention needed', 'Deployment complete'),
    '{{ERROR_QUERY_COMMAND}}': 'Configure error query command for your monitoring system.',
    '{{ERROR_UPDATE_STATUS}}': 'Configure error status update command.',
    '{{ERROR_DISMISS}}': 'Configure error dismiss command.',
    '{{DEPLOY_COMMAND}}': os.environ.get('DEPLOY_VALIDATE', 'Configure deploy command.'),
    '{{FACTORY_LOCAL_VALIDATION}}': os.environ.get('DEPLOY_VALIDATE', 'Configure local validation command.'),
}

for filepath in glob.glob(os.path.join(skills_dir, '**', '*.md'), recursive=True):
    with open(filepath, 'r') as f:
        content = f.read()
    changed = False
    for placeholder, value in replacements.items():
        if placeholder in content:
            content = content.replace(placeholder, value)
            changed = True
    if changed:
        with open(filepath, 'w') as f:
            f.write(content)
PYEOF

# ── Copy settings ────────────────────────────────────────────────

echo "Copying settings..."
cp "$FRAMEWORK_DIR/templates/settings.local.json" "$PROJECT_DIR/.claude/settings.local.json"

# ── Copy statusline ──────────────────────────────────────────────

cp "$FRAMEWORK_DIR/templates/statusline/statusline-command.sh" "$PROJECT_DIR/.claude/statusline/statusline-command.sh"
chmod +x "$PROJECT_DIR/.claude/statusline/statusline-command.sh"

# ── Create initial CLAUDE.md if none exists ──────────────────────

if [ ! -f "$PROJECT_DIR/CLAUDE.md" ]; then
    echo "Creating CLAUDE.md..."
    cp "$FRAMEWORK_DIR/templates/CLAUDE.md.template" "$PROJECT_DIR/CLAUDE.md"

    # Replace known placeholders
    sed -i '' \
        -e "s|{{BASE_BRANCH}}|$BASE_BRANCH|g" \
        -e "s|{{PROJECT_SHORT_NAME}}|$PROJECT_SHORT|g" \
        "$PROJECT_DIR/CLAUDE.md"

    # Replace tracker config
    python3 -c "
import os
with open('$PROJECT_DIR/CLAUDE.md', 'r') as f:
    content = f.read()
content = content.replace('{{TRACKER_CONFIG}}', '''$TRACKER_CONFIG''')
content = content.replace('{{FORMAT_COMMAND}}', '$FORMAT_CMD')
content = content.replace('{{FORMAT_VERIFY_COMMAND}}', '$FORMAT_VERIFY')
content = content.replace('{{TEST_COMMAND}}', '$TEST_CMD')
content = content.replace('{{DEPLOY_VALIDATE_COMMAND}}', '$DEPLOY_VALIDATE')
with open('$PROJECT_DIR/CLAUDE.md', 'w') as f:
    f.write(content)
"
    echo "  Created CLAUDE.md (fill in project-specific sections marked with {{...}})"
else
    echo "  CLAUDE.md already exists — skipping"
fi

# ── Create GitHub Actions workflows ──────────────────────────────

if [ "$CI_NAME" = "github-actions" ]; then
    echo "Creating GitHub Actions workflows..."
    mkdir -p "$PROJECT_DIR/.github/workflows"

    # Copy workflow templates
    for wf in "$FRAMEWORK_DIR/workflows"/*.yml; do
        if [ -f "$wf" ]; then
            cp "$wf" "$PROJECT_DIR/.github/workflows/"
            echo "  + $(basename "$wf")"
        fi
    done
fi

# ── Install Claude Code hooks ────────────────────────────────────

echo "Setting up Claude Code hooks..."
CLAUDE_HOME="$HOME/.claude"
mkdir -p "$CLAUDE_HOME/hooks"

if [ ! -f "$CLAUDE_HOME/hooks/session-stop.sh" ]; then
    cp "$FRAMEWORK_DIR/templates/hooks/session-stop.sh" "$CLAUDE_HOME/hooks/session-stop.sh"
    chmod +x "$CLAUDE_HOME/hooks/session-stop.sh"
    echo "  + Session stop sound hook"
fi

# ── Set up pre-commit hooks (formatting + linting) ──────────────

echo "Setting up pre-commit hooks..."

setup_precommit() {
    case $PROJECT_TYPE_NAME in
        nodejs|react)
            # Use husky + lint-staged for Node.js projects
            if [ -f "$PROJECT_DIR/package.json" ]; then
                if ! grep -q '"husky"' "$PROJECT_DIR/package.json" 2>/dev/null; then
                    echo "  Install pre-commit hooks with:"
                    echo "    npx husky init"
                    echo "    npm install --save-dev lint-staged"
                    echo '    echo "npx lint-staged" > .husky/pre-commit'
                    echo ""
                    echo "  Add to package.json:"
                    echo '    "lint-staged": { "*.{js,jsx,ts,tsx,json,css,md}": "prettier --write" }'
                else
                    echo "  husky already configured"
                fi
            fi
            ;;
        python)
            # Use pre-commit framework for Python
            if ! command -v pre-commit &> /dev/null; then
                echo "  Install pre-commit hooks with:"
                echo "    pip install pre-commit"
                echo "    pre-commit install"
            fi
            if [ ! -f "$PROJECT_DIR/.pre-commit-config.yaml" ]; then
                cat > "$PROJECT_DIR/.pre-commit-config.yaml" << 'PRECOMMIT_EOF'
repos:
  - repo: https://github.com/psf/black
    rev: 24.4.2
    hooks:
      - id: black
  - repo: https://github.com/astral-sh/ruff-pre-commit
    rev: v0.4.7
    hooks:
      - id: ruff
        args: [--fix]
  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v4.6.0
    hooks:
      - id: trailing-whitespace
      - id: end-of-file-fixer
      - id: check-yaml
      - id: check-added-large-files
PRECOMMIT_EOF
                echo "  + Created .pre-commit-config.yaml"
                echo "  Run 'pre-commit install' to activate"
            fi
            ;;
        go)
            echo "  Go uses gofmt automatically. For pre-commit hooks:"
            echo "    go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest"
            echo "  Add to .git/hooks/pre-commit:"
            echo '    gofmt -l . | grep -q . && echo "Run gofmt" && exit 1'
            ;;
        java)
            echo "  For Java, configure spotless in build.gradle:"
            echo '    plugins { id "com.diffplug.spotless" }'
            echo "  Then: ./gradlew spotlessApply"
            ;;
        rails)
            echo "  For Ruby, use overcommit or lefthook:"
            echo "    gem install overcommit && overcommit --install"
            ;;
        *)
            echo "  Configure pre-commit hooks for your project manually"
            ;;
    esac
}

setup_precommit

# ── Create .env template ────────────────────────────────────────

if [ ! -f "$PROJECT_DIR/.env" ]; then
    echo "Creating .env template..."
    cat > "$PROJECT_DIR/.env" << 'ENV_EOF'
# Claude Code Framework — Environment Variables
# Copy this to .env and fill in your values

# Work Item Tracker
ENV_EOF

    case $TRACKER_NAME in
        ado)
            cat >> "$PROJECT_DIR/.env" << 'ENV_EOF'
AZURE_DEVOPS_EXT_PAT=your-pat-here
ENV_EOF
            ;;
        jira)
            cat >> "$PROJECT_DIR/.env" << 'ENV_EOF'
JIRA_EMAIL=your-email@company.com
JIRA_API_TOKEN=your-token-here
ENV_EOF
            ;;
        linear)
            cat >> "$PROJECT_DIR/.env" << 'ENV_EOF'
LINEAR_API_KEY=your-key-here
ENV_EOF
            ;;
    esac

    case $NOTIFY_NAME in
        slack)
            echo "SLACK_WEBHOOK_URL=https://hooks.slack.com/services/..." >> "$PROJECT_DIR/.env"
            ;;
        teams)
            echo "TEAMS_WEBHOOK_URL=https://outlook.office.com/webhook/..." >> "$PROJECT_DIR/.env"
            ;;
        discord)
            echo "DISCORD_WEBHOOK_URL=https://discord.com/api/webhooks/..." >> "$PROJECT_DIR/.env"
            ;;
    esac

    # Ensure .env is gitignored
    if [ -f "$PROJECT_DIR/.gitignore" ]; then
        if ! grep -q "^\.env$" "$PROJECT_DIR/.gitignore"; then
            echo ".env" >> "$PROJECT_DIR/.gitignore"
        fi
    fi
fi

# ═══════════════════════════════════════════════════════════════
# Summary
# ═══════════════════════════════════════════════════════════════

echo ""
echo "======================================"
echo "  Setup Complete!"
echo "======================================"
echo ""
echo "Project:    $PROJECT_NAME"
echo "Type:       $PROJECT_TYPE_NAME"
echo "Tracker:    $TRACKER_NAME"
echo "CI/CD:      $CI_NAME"
echo "Base branch: $BASE_BRANCH"
echo "Notify:     $NOTIFY_NAME"
echo ""
echo "Files created:"
echo "  .claude/skills/         — 12 workflow skills (incl. merge-resolve)"
echo "  .claude/settings.local.json"
echo "  .claude/statusline/"
if [ "$CI_NAME" = "github-actions" ]; then
    echo "  .github/workflows/      — 4 CI/CD pipelines (validate, auto-merge, deploy, cleanup)"
fi
echo "  docs/stories/            — story documentation folder"
if [ ! -f "$PROJECT_DIR/CLAUDE.md.bak" ]; then
    echo "  CLAUDE.md                — project instructions (customize!)"
fi
echo ""
echo "Next steps:"
echo "  1. Fill in CLAUDE.md sections marked with {{...}}"
echo "  2. Configure .env with your credentials"
echo "  3. Set up pre-commit hooks (see instructions above)"
echo "  4. Add domain knowledge: /add-reference my-domain topic"
echo "  5. Try it: /develop TICKET-123"
echo ""
