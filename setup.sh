#!/bin/bash
# Claude Code Framework — Interactive Setup Wizard
# Usage: cd your-project/ && bash ~/Developer/claude-code-framework/setup.sh

set -e

# ── Argument parsing ───────────────────────────────────────────────
DRY_RUN=false
RESET=false
for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=true ;;
        --reset) RESET=true ;;
        --help|-h) echo "Usage: setup.sh [--dry-run] [--reset]"; echo "  --dry-run  Show what would be done without making changes"; echo "  --reset    Remove framework files from target project"; exit 0 ;;
    esac
done

if ! command -v python3 &>/dev/null; then
    echo "ERROR: python3 is required but not found. Install Python 3 and retry."
    exit 1
fi

FRAMEWORK_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(pwd)"
PROJECT_NAME="$(basename "$PROJECT_DIR")"

# ── Reset mode ─────────────────────────────────────────────────────
if [ "$RESET" = true ]; then
    echo "Removing framework files..."
    rm -rf "$PROJECT_DIR/.claude/skills" "$PROJECT_DIR/.claude/agents" "$PROJECT_DIR/.claude/commands" "$PROJECT_DIR/.claude/rules" "$PROJECT_DIR/.claude/hooks"
    rm -f "$PROJECT_DIR/.claude/settings.local.json" "$PROJECT_DIR/.mcp.json"
    echo "Framework files removed. CLAUDE.md and .env preserved."
    echo "To fully clean up, manually remove CLAUDE.md and .env"
    exit 0
fi

# ── Portable sed -i function ──────────────────────────────────────
sed_inplace() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' "$@"
    else
        sed -i "$@"
    fi
}

echo "======================================"
echo "  Claude Code Framework Setup"
echo "======================================"
echo ""
echo "Project: $PROJECT_NAME"
echo "Directory: $PROJECT_DIR"
echo ""

# ── 1. Project Type ──────────────────────────────────────────────

echo "What type of project is this?"
echo "  1) Salesforce (Apex, LWC, Flows)"
echo "  2) Node.js / TypeScript"
echo "  3) Python"
echo "  4) Go"
echo "  5) Java / Spring Boot"
echo "  6) React / Next.js"
echo "  7) Ruby on Rails"
echo "  8) Other"
while true; do
    read -p "Choice [1-8]: " PROJECT_TYPE
    case "$PROJECT_TYPE" in
        1|2|3|4|5|6|7|8) break ;;
        *) echo "Invalid selection. Please enter a number between 1 and 8." ;;
    esac
done

case $PROJECT_TYPE in
    1) PROJECT_TYPE_NAME="salesforce" ;;
    2) PROJECT_TYPE_NAME="nodejs" ;;
    3) PROJECT_TYPE_NAME="python" ;;
    4) PROJECT_TYPE_NAME="go" ;;
    5) PROJECT_TYPE_NAME="java" ;;
    6) PROJECT_TYPE_NAME="react" ;;
    7) PROJECT_TYPE_NAME="rails" ;;
    8) PROJECT_TYPE_NAME="generic" ;;
esac

# ── 2. Work Item Tracker ────────────────────────────────────────

echo ""
echo "What work item tracker do you use?"
echo "  1) Azure DevOps"
echo "  2) Jira"
echo "  3) Linear"
echo "  4) GitHub Issues"
echo "  5) None"
while true; do
    read -p "Choice [1-5]: " TRACKER_TYPE
    case "$TRACKER_TYPE" in
        1|2|3|4|5) break ;;
        *) echo "Invalid selection. Please enter a number between 1 and 5." ;;
    esac
done

case $TRACKER_TYPE in
    1) TRACKER_NAME="ado" ;;
    2) TRACKER_NAME="jira" ;;
    3) TRACKER_NAME="linear" ;;
    4) TRACKER_NAME="github" ;;
    5) TRACKER_NAME="none" ;;
esac

# Collect tracker-specific user inputs (config values loaded later from JSON)
case $TRACKER_NAME in
    ado)
        read -p "ADO Organization: " ADO_ORG
        read -p "ADO Project: " ADO_PROJECT
        ;;
    jira)
        read -p "Jira Domain (e.g., mycompany.atlassian.net): " JIRA_DOMAIN
        read -p "Jira Project Key (e.g., PROJ): " JIRA_PROJECT
        ;;
    linear)
        read -p "Linear Team ID: " LINEAR_TEAM
        ;;
esac

# ── 3. CI/CD Platform ───────────────────────────────────────────

echo ""
echo "What CI/CD platform do you use?"
echo "  1) GitHub Actions"
echo "  2) GitLab CI"
echo "  3) CircleCI"
echo "  4) None / Manual"
while true; do
    read -p "Choice [1-4]: " CI_TYPE
    case "$CI_TYPE" in
        1|2|3|4) break ;;
        *) echo "Invalid selection. Please enter a number between 1 and 4." ;;
    esac
done

case $CI_TYPE in
    1) CI_NAME="github-actions" ;;
    2) CI_NAME="gitlab-ci" ;;
    3) CI_NAME="circleci" ;;
    4) CI_NAME="none" ;;
esac

# ── 4. Base Branch ──────────────────────────────────────────────

echo ""
read -p "Primary integration branch [main]: " BASE_BRANCH
BASE_BRANCH="${BASE_BRANCH:-main}"

# Check if current branch differs and offer to rename
currentBranch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
if [ -n "$currentBranch" ] && [ "$currentBranch" != "$BASE_BRANCH" ]; then
    read -p "Current branch is '$currentBranch'. Rename to '$BASE_BRANCH' and update remote? [y/N]: " CONFIRM
    if [ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "Y" ]; then
        echo "Skipping branch rename. Using '$currentBranch' as-is."
        BASE_BRANCH="$currentBranch"
    else
        git branch -m "$currentBranch" "$BASE_BRANCH"
        echo "Renamed local branch '$currentBranch' to '$BASE_BRANCH'."
        if git remote get-url origin &>/dev/null; then
            git push origin --delete "$currentBranch" 2>/dev/null || true
            git push origin "$BASE_BRANCH" -u 2>/dev/null || true
            echo "Updated remote branch."
        fi
    fi
fi

# ── 5. Notification System ──────────────────────────────────────

echo ""
echo "What notification system do you use?"
echo "  1) Slack"
echo "  2) Microsoft Teams"
echo "  3) Discord"
echo "  4) None"
while true; do
    read -p "Choice [1-4]: " NOTIFY_TYPE
    case "$NOTIFY_TYPE" in
        1|2|3|4) break ;;
        *) echo "Invalid selection. Please enter a number between 1 and 4." ;;
    esac
done

case $NOTIFY_TYPE in
    1) NOTIFY_NAME="slack" ;;
    2) NOTIFY_NAME="teams" ;;
    3) NOTIFY_NAME="discord" ;;
    4) NOTIFY_NAME="none" ;;
esac

# ── 6. Project Short Name (for worktrees) ───────────────────────

echo ""
read -p "Short project name (for worktrees, e.g., 'myapp'): " PROJECT_SHORT
PROJECT_SHORT="${PROJECT_SHORT:-$PROJECT_NAME}"

# ── 7. Design System ──────────────────────────────────────────────

DESIGN_SYSTEM_NAME="none"
DESIGN_COLOR_RULES=""
DESIGN_COMPONENT_IMPORTS=""
DESIGN_ICON_USAGE=""
DESIGN_CARD_PATTERNS=""
DESIGN_DARK_MODE=""

case $PROJECT_TYPE_NAME in
    react|nodejs)
        echo ""
        echo "What design system foundation does this project use?"
        echo "  1) Untitled UI (premium, React Aria based)"
        echo "  2) shadcn/ui (open source, Radix based)"
        echo "  3) Custom / existing (I'll configure it later)"
        echo "  4) None — no design system"
        while true; do
            read -p "Choice [1-4]: " DESIGN_TYPE
            case "$DESIGN_TYPE" in
                1|2|3|4) break ;;
                *) echo "Invalid selection. Please enter a number between 1 and 4." ;;
            esac
        done

        case $DESIGN_TYPE in
            1) DESIGN_SYSTEM_NAME="untitled-ui" ;;
            2) DESIGN_SYSTEM_NAME="shadcn" ;;
            3) DESIGN_SYSTEM_NAME="custom" ;;
            4|*) DESIGN_SYSTEM_NAME="none" ;;
        esac
        ;;
    *)
        # Non-frontend projects use the _backend preset
        DESIGN_SYSTEM_NAME="_backend"
        ;;
esac

# Load design system values from config/design-systems.json
eval "$(python3 << DESIGN_EOF
import json, os

framework_dir = os.environ.get('FRAMEWORK_DIR', '.')
design_name = '$DESIGN_SYSTEM_NAME'

with open(os.path.join(framework_dir, 'config', 'design-systems.json')) as f:
    systems = json.load(f)

cfg = systems.get(design_name, systems['none'])

def shell_escape(val):
    return val.replace("'", "'\\''")

for var, key in [
    ('DESIGN_COLOR_RULES', 'color_rules'),
    ('DESIGN_COMPONENT_IMPORTS', 'component_imports'),
    ('DESIGN_ICON_USAGE', 'icon_usage'),
    ('DESIGN_CARD_PATTERNS', 'card_patterns'),
    ('DESIGN_DARK_MODE', 'dark_mode'),
]:
    val = shell_escape(cfg.get(key, ''))
    print(f"{var}='{val}'")
DESIGN_EOF
)"

# ═══════════════════════════════════════════════════════════════
# Generate project files
# ═══════════════════════════════════════════════════════════════

if [ "$DRY_RUN" = true ]; then
    echo ""
    echo "[DRY-RUN] Would set up Claude Code framework in $PROJECT_DIR"
    echo "[DRY-RUN] Would create directories: .claude/skills, .claude/statusline, docs/stories"
    echo "[DRY-RUN] Would copy skills from $FRAMEWORK_DIR/skills/"
    echo "[DRY-RUN] Would copy agents from $FRAMEWORK_DIR/templates/agents/"
    echo "[DRY-RUN] Would copy commands from $FRAMEWORK_DIR/templates/commands/"
    echo "[DRY-RUN] Would copy rules from $FRAMEWORK_DIR/templates/rules/"
    echo "[DRY-RUN] Would copy hooks from $FRAMEWORK_DIR/templates/hooks/"
    echo "[DRY-RUN] Would replace all {{PLACEHOLDER}} values in copied files"
    echo "[DRY-RUN] Would copy settings.local.json, .mcp.json, statusline"
    if [ ! -f "$PROJECT_DIR/CLAUDE.md" ]; then
        echo "[DRY-RUN] Would create CLAUDE.md from template"
    else
        echo "[DRY-RUN] CLAUDE.md already exists — would skip"
    fi
    if [ "$CI_NAME" = "github-actions" ]; then
        echo "[DRY-RUN] Would create GitHub Actions workflows in .github/workflows/"
    fi
    if [ ! -f "$PROJECT_DIR/.env" ]; then
        echo "[DRY-RUN] Would create .env template"
    fi
    echo ""
    echo "[DRY-RUN] Configuration summary:"
    echo "  Project:     $PROJECT_NAME"
    echo "  Type:        $PROJECT_TYPE_NAME"
    echo "  Tracker:     $TRACKER_NAME"
    echo "  CI/CD:       $CI_NAME"
    echo "  Base branch: $BASE_BRANCH"
    echo "  Notify:      $NOTIFY_NAME"
    echo "  Design:      $DESIGN_SYSTEM_NAME"
    echo ""
    echo "No files were modified. Run without --dry-run to apply."
    exit 0
fi

echo ""
echo "Setting up Claude Code framework..."
echo ""

# ── Create .claude directory ─────────────────────────────────────

mkdir -p "$PROJECT_DIR/.claude/skills"
mkdir -p "$PROJECT_DIR/.claude/statusline"
mkdir -p "$PROJECT_DIR/docs/stories"

# ── Copy skills ──────────────────────────────────────────────────

echo "Copying skills..."
for skill_dir in "$FRAMEWORK_DIR/skills"/*/; do
    skill_name=$(basename "$skill_dir")
    if [ "$skill_name" = "_template" ]; then continue; fi
    if [ -d "$skill_dir" ]; then
        cp -r "$skill_dir" "$PROJECT_DIR/.claude/skills/$skill_name"
        echo "  + /$(basename "$skill_dir")"
    fi
done

# ── Replace placeholders in skills ───────────────────────────────

echo "Configuring skills for your project..."

# Build tracker-specific command blocks (from config/trackers.json)
export ADO_ORG ADO_PROJECT JIRA_DOMAIN JIRA_PROJECT LINEAR_TEAM FRAMEWORK_DIR

eval "$(python3 << TRACKER_EOF
import json, os

framework_dir = os.environ.get('FRAMEWORK_DIR', '.')
tracker_name = '$TRACKER_NAME'

with open(os.path.join(framework_dir, 'config', 'trackers.json')) as f:
    trackers = json.load(f)

cfg = trackers.get(tracker_name, trackers['none'])

def replace_tracker_placeholders(val):
    val = val.replace('{{ADO_ORG}}', os.environ.get('ADO_ORG', ''))
    val = val.replace('{{ADO_PROJECT}}', os.environ.get('ADO_PROJECT', ''))
    val = val.replace('{{JIRA_DOMAIN}}', os.environ.get('JIRA_DOMAIN', ''))
    val = val.replace('{{JIRA_PROJECT}}', os.environ.get('JIRA_PROJECT', ''))
    val = val.replace('{{LINEAR_TEAM}}', os.environ.get('LINEAR_TEAM', ''))
    return val

def shell_escape(val):
    return val.replace("'", "'\\''")

fields = {
    'TRACKER_FETCH': cfg.get('fetch_ticket', ''),
    'TRACKER_SET_PROGRESS': cfg.get('set_progress', ''),
    'TRACKER_SET_REVIEW': cfg.get('set_review', ''),
    'TRACKER_URL': cfg.get('ticket_url', ''),
    'TRACKER_CREATE': cfg.get('create_ticket', ''),
    'TRACKER_CREATE_BUG': cfg.get('create_bug', ''),
    'TRACKER_LINK_PR': cfg.get('link_pr', ''),
    'TRACKER_UPDATE_FIELDS': cfg.get('update_fields', ''),
    'TRACKER_SET_DEPLOYED': cfg.get('set_deployed', ''),
    'TRACKER_CONFIG': cfg.get('config', ''),
}

for key, val in fields.items():
    val = replace_tracker_placeholders(val)
    print(f"{key}='{shell_escape(val)}'")
TRACKER_EOF
)"

# Build project-type-specific commands and file patterns (from config/project-types.json)
DEFAULT_MODEL="sonnet"

eval "$(python3 << PROJTYPE_EOF
import json, os

framework_dir = os.environ.get('FRAMEWORK_DIR', '.')
project_type = '$PROJECT_TYPE_NAME'

with open(os.path.join(framework_dir, 'config', 'project-types.json')) as f:
    types = json.load(f)

cfg = types.get(project_type, types['generic'])

# Shell-escape single quotes in values
def shell_escape(val):
    return val.replace("'", "'\\''")

# Command variables
for var, key in [
    ('FORMAT_CMD', 'format_cmd'),
    ('FORMAT_VERIFY', 'format_verify'),
    ('TEST_CMD', 'test_cmd'),
    ('DEPLOY_VALIDATE', 'deploy_validate'),
    ('TYPE_CHECK_CMD', 'type_check_cmd'),
    ('DEP_CHECK_CMD', 'dep_check_cmd'),
    ('SECURITY_AUDIT_CMD', 'security_audit_cmd'),
    ('ERROR_TRACKING', 'error_tracking'),
]:
    val = shell_escape(cfg.get(key, ''))
    print(f"{var}='{val}'")

# Pattern variables (arrays joined with comma-space, each element quoted)
for var, key in [
    ('API_ROUTE_PATTERNS', 'api_route_patterns'),
    ('COMPONENT_PATTERNS', 'component_patterns'),
    ('TEST_PATTERNS', 'test_patterns'),
    ('DATABASE_PATTERNS', 'database_patterns'),
    ('SOURCE_PATTERNS', 'source_patterns'),
]:
    patterns = cfg.get(key, [])
    joined = ', '.join(f'"{p}"' for p in patterns)
    print(f"{var}='{shell_escape(joined)}'")
PROJTYPE_EOF
)"

# Build notification commands (from config/notifications.json)
eval "$(python3 << NOTIFY_EOF
import json, os

framework_dir = os.environ.get('FRAMEWORK_DIR', '.')
notify_name = '$NOTIFY_NAME'

with open(os.path.join(framework_dir, 'config', 'notifications.json')) as f:
    notifications = json.load(f)

cfg = notifications.get(notify_name, notifications['none'])

def shell_escape(val):
    return val.replace("'", "'\\''")

for var, key in [
    ('NOTIFY_CMD', 'halt'),
    ('NOTIFY_DEPLOY_CMD', 'deploy_success'),
    ('NOTIFY_MERGE_CMD', 'merge_resolve'),
]:
    val = shell_escape(cfg.get(key, ''))
    print(f"{var}='{val}'")
NOTIFY_EOF
)"

# ── Copy agents ──────────────────────────────────────────────────

echo "Copying agents..."
mkdir -p "$PROJECT_DIR/.claude/agents"
for agent_file in "$FRAMEWORK_DIR/templates/agents"/*.md; do
    if [ -f "$agent_file" ]; then
        cp "$agent_file" "$PROJECT_DIR/.claude/agents/"
        echo "  + $(basename "$agent_file")"
    fi
done

# ── Copy commands ────────────────────────────────────────────────

echo "Copying commands..."
mkdir -p "$PROJECT_DIR/.claude/commands"
for cmd_file in "$FRAMEWORK_DIR/templates/commands"/*.md; do
    if [ -f "$cmd_file" ]; then
        cp "$cmd_file" "$PROJECT_DIR/.claude/commands/"
        echo "  + $(basename "$cmd_file")"
    fi
done

# ── Copy rules ───────────────────────────────────────────────────

echo "Copying rules..."
mkdir -p "$PROJECT_DIR/.claude/rules"
for rule_file in "$FRAMEWORK_DIR/templates/rules"/*.md; do
    if [ -f "$rule_file" ]; then
        cp "$rule_file" "$PROJECT_DIR/.claude/rules/"
        echo "  + $(basename "$rule_file")"
    fi
done

# Skip frontend rules for backend-only projects
case $PROJECT_TYPE_NAME in
    python|go|java)
        if [ -f "$PROJECT_DIR/.claude/rules/components.md" ]; then
            rm -f "$PROJECT_DIR/.claude/rules/components.md"
            echo "  Skipped components.md (backend-only project)"
        fi
        if [ -f "$PROJECT_DIR/.claude/rules/design-system.md" ]; then
            rm -f "$PROJECT_DIR/.claude/rules/design-system.md"
            echo "  Skipped design-system.md (backend-only project)"
        fi
        ;;
esac

# Skip design-system rule if no design system configured
if [ "$DESIGN_SYSTEM_NAME" = "none" ] && [ -f "$PROJECT_DIR/.claude/rules/design-system.md" ]; then
    rm -f "$PROJECT_DIR/.claude/rules/design-system.md"
    echo "  Skipped design-system.md (no design system configured)"
fi

# ── Copy hooks (project-level) ───────────────────────────────────

echo "Copying hooks..."
mkdir -p "$PROJECT_DIR/.claude/hooks"
for hook_file in "$FRAMEWORK_DIR/templates/hooks"/*.sh; do
    if [ -f "$hook_file" ]; then
        cp "$hook_file" "$PROJECT_DIR/.claude/hooks/"
        chmod +x "$PROJECT_DIR/.claude/hooks/$(basename "$hook_file")"
        echo "  + $(basename "$hook_file")"
    fi
done

# ── Replace ALL placeholders in skills, agents, commands, rules, hooks ───

echo "Replacing placeholders..."

# Export all variables needed by the consolidated Python replacement
export PROJECT_DIR BASE_BRANCH PROJECT_SHORT
export FORMAT_CMD FORMAT_VERIFY TEST_CMD DEPLOY_VALIDATE
export TYPE_CHECK_CMD DEP_CHECK_CMD SECURITY_AUDIT_CMD DEFAULT_MODEL
export TRACKER_FETCH TRACKER_SET_PROGRESS TRACKER_SET_REVIEW
export TRACKER_URL TRACKER_LINK_PR TRACKER_CREATE TRACKER_CREATE_BUG
export TRACKER_UPDATE_FIELDS TRACKER_SET_DEPLOYED
export NOTIFY_CMD NOTIFY_DEPLOY_CMD NOTIFY_MERGE_CMD
export ERROR_TRACKING
export API_ROUTE_PATTERNS COMPONENT_PATTERNS TEST_PATTERNS
export DATABASE_PATTERNS SOURCE_PATTERNS
export DESIGN_COLOR_RULES DESIGN_COMPONENT_IMPORTS DESIGN_ICON_USAGE
export DESIGN_CARD_PATTERNS DESIGN_DARK_MODE

python3 << 'REPLACE_ALL_EOF'
import os, glob

project_dir = os.environ.get('PROJECT_DIR', '.')

# All placeholder replacements — simple and multi-line — in one map
replacements = {
    # Simple placeholders (previously handled by sed)
    '{{BASE_BRANCH}}': os.environ.get('BASE_BRANCH', 'main'),
    '{{PROJECT_SHORT_NAME}}': os.environ.get('PROJECT_SHORT', ''),
    '{{FORMAT_COMMAND}}': os.environ.get('FORMAT_CMD', ''),
    '{{FORMAT_VERIFY_COMMAND}}': os.environ.get('FORMAT_VERIFY', ''),
    '{{TEST_COMMAND}}': os.environ.get('TEST_CMD', ''),
    '{{DEPLOY_VALIDATE_COMMAND}}': os.environ.get('DEPLOY_VALIDATE', ''),
    '{{TYPE_CHECK_COMMAND}}': os.environ.get('TYPE_CHECK_CMD', ''),
    '{{DEP_CHECK_COMMAND}}': os.environ.get('DEP_CHECK_CMD', ''),
    '{{SECURITY_AUDIT_COMMAND}}': os.environ.get('SECURITY_AUDIT_CMD', ''),
    '{{DEFAULT_MODEL}}': os.environ.get('DEFAULT_MODEL', 'sonnet'),

    # Tracker placeholders (previously handled by Python skills pass)
    '{{TRACKER_FETCH_TICKET}}': os.environ.get('TRACKER_FETCH', 'Configure tracker fetch command.'),
    '{{TRACKER_SET_IN_PROGRESS}}': os.environ.get('TRACKER_SET_PROGRESS', 'Configure tracker state transition.'),
    '{{TRACKER_SET_IN_REVIEW}}': os.environ.get('TRACKER_SET_REVIEW', 'Configure tracker state transition.'),
    '{{TRACKER_TICKET_URL}}': os.environ.get('TRACKER_URL', '{ticket_url}'),
    '{{TRACKER_LINK_PR}}': os.environ.get('TRACKER_LINK_PR', 'Configure PR-to-ticket linking.'),
    '{{TRACKER_CREATE_TICKET}}': os.environ.get('TRACKER_CREATE', 'Configure ticket creation.'),
    '{{TRACKER_CREATE_BUG}}': os.environ.get('TRACKER_CREATE_BUG', 'Configure bug creation.'),
    '{{TRACKER_UPDATE_FIELDS}}': os.environ.get('TRACKER_UPDATE_FIELDS', 'Configure tracker field update command.'),
    '{{TRACKER_SET_DEPLOYED}}': os.environ.get('TRACKER_SET_DEPLOYED', 'Configure tracker deployed state transition.'),

    # Notification placeholders
    '{{NOTIFY_HALT}}': os.environ.get('NOTIFY_CMD', 'Log halt message.'),
    '{{NOTIFY_HALT_FACTORY}}': os.environ.get('NOTIFY_CMD', 'Log halt message.'),
    '{{NOTIFY_DEPLOY_SUCCESS}}': os.environ.get('NOTIFY_DEPLOY_CMD', 'No notification system configured. Log deploy success.'),
    '{{NOTIFY_MERGE_RESOLVE}}': os.environ.get('NOTIFY_MERGE_CMD', 'No notification system configured. Log merge resolution message.'),

    # Error/deploy placeholders
    '{{ERROR_QUERY_COMMAND}}': 'Configure error query command for your monitoring system.',
    '{{ERROR_UPDATE_STATUS}}': 'Configure error status update command.',
    '{{ERROR_DISMISS}}': 'Configure error dismiss command.',
    '{{DEPLOY_COMMAND}}': os.environ.get('DEPLOY_VALIDATE', 'Configure deploy command.'),
    '{{FACTORY_LOCAL_VALIDATION}}': os.environ.get('DEPLOY_VALIDATE', 'Configure local validation command.'),

    # Pattern placeholders (previously handled by Python agents pass)
    '{{ERROR_TRACKING_PATTERN}}': os.environ.get('ERROR_TRACKING', '// Log the error with full context'),
    '{{API_ROUTE_PATTERNS}}': os.environ.get('API_ROUTE_PATTERNS', '"**/routes/**/*", "**/api/**/*"'),
    '{{COMPONENT_PATTERNS}}': os.environ.get('COMPONENT_PATTERNS', '"**/components/**/*"'),
    '{{TEST_PATTERNS}}': os.environ.get('TEST_PATTERNS', '"**/*test*", "**/*spec*"'),
    '{{DATABASE_PATTERNS}}': os.environ.get('DATABASE_PATTERNS', '"**/models/**/*", "**/migrations/**/*"'),
    '{{SOURCE_PATTERNS}}': os.environ.get('SOURCE_PATTERNS', '"**/*.{ts,js,py,go,java,rb}"'),

    # Design system placeholders
    '{{DESIGN_COLOR_RULES}}': os.environ.get('DESIGN_COLOR_RULES', 'Not configured.'),
    '{{DESIGN_COMPONENT_IMPORTS}}': os.environ.get('DESIGN_COMPONENT_IMPORTS', 'Not configured.'),
    '{{DESIGN_ICON_USAGE}}': os.environ.get('DESIGN_ICON_USAGE', 'Not configured.'),
    '{{DESIGN_CARD_PATTERNS}}': os.environ.get('DESIGN_CARD_PATTERNS', 'Not configured.'),
    '{{DESIGN_DARK_MODE}}': os.environ.get('DESIGN_DARK_MODE', 'Not configured.'),
}

# Process all directories in a single pass
for search_dir in ['skills', 'agents', 'commands', 'rules', 'hooks']:
    dir_path = os.path.join(project_dir, '.claude', search_dir)
    if not os.path.isdir(dir_path):
        continue
    for filepath in glob.glob(os.path.join(dir_path, '**', '*'), recursive=True):
        if not os.path.isfile(filepath):
            continue
        if not (filepath.endswith('.md') or filepath.endswith('.sh')):
            continue
        with open(filepath, 'r') as f:
            content = f.read()
        original = content
        for placeholder, value in replacements.items():
            content = content.replace(placeholder, value)
        if content != original:
            with open(filepath, 'w') as f:
                f.write(content)
REPLACE_ALL_EOF

# ── Copy settings ────────────────────────────────────────────────

echo "Copying settings..."
cp "$FRAMEWORK_DIR/templates/settings.local.json" "$PROJECT_DIR/.claude/settings.local.json"
# Replace model placeholder in settings
sed_inplace "s|{{DEFAULT_MODEL}}|$DEFAULT_MODEL|g" "$PROJECT_DIR/.claude/settings.local.json" 2>/dev/null || true

# ── Copy MCP server config ───────────────────────────────────────

echo "Copying MCP server config..."
cp "$FRAMEWORK_DIR/templates/mcp.json" "$PROJECT_DIR/.mcp.json"
echo "  + .mcp.json (Context7 documentation server)"

# ── Install user-level settings.json ─────────────────────────────

CLAUDE_HOME="$HOME/.claude"
mkdir -p "$CLAUDE_HOME"

if [ ! -f "$CLAUDE_HOME/settings.json" ]; then
    echo "Installing user-level settings.json..."
    cp "$FRAMEWORK_DIR/templates/settings.json" "$CLAUDE_HOME/settings.json"
    echo "  + ~/.claude/settings.json (AI factory permissions)"
else
    echo "  ~/.claude/settings.json already exists — skipping"
fi

# ── Copy statusline ──────────────────────────────────────────────

cp "$FRAMEWORK_DIR/templates/statusline/statusline-command.sh" "$PROJECT_DIR/.claude/statusline/statusline-command.sh"
chmod +x "$PROJECT_DIR/.claude/statusline/statusline-command.sh"

# ── Create initial CLAUDE.md if none exists ──────────────────────

if [ ! -f "$PROJECT_DIR/CLAUDE.md" ]; then
    echo "Creating CLAUDE.md..."
    cp "$FRAMEWORK_DIR/templates/CLAUDE.md.template" "$PROJECT_DIR/CLAUDE.md"

    # Replace known placeholders
    sed_inplace \
        -e "s|{{BASE_BRANCH}}|$BASE_BRANCH|g" \
        -e "s|{{PROJECT_SHORT_NAME}}|$PROJECT_SHORT|g" \
        "$PROJECT_DIR/CLAUDE.md"

    # Replace tracker config, design system, and other placeholders
    export FORMAT_CMD FORMAT_VERIFY TEST_CMD TYPE_CHECK_CMD DEPLOY_VALIDATE TRACKER_CONFIG
    export DESIGN_COLOR_RULES DESIGN_COMPONENT_IMPORTS DESIGN_ICON_USAGE DESIGN_CARD_PATTERNS DESIGN_DARK_MODE
    python3 << 'CLAUDE_MD_EOF'
import os

project_dir = os.environ.get('PROJECT_DIR', '.')
with open(os.path.join(project_dir, 'CLAUDE.md'), 'r') as f:
    content = f.read()

replacements = {
    '{{TRACKER_CONFIG}}': os.environ.get('TRACKER_CONFIG', ''),
    '{{FORMAT_COMMAND}}': os.environ.get('FORMAT_CMD', ''),
    '{{FORMAT_VERIFY_COMMAND}}': os.environ.get('FORMAT_VERIFY', ''),
    '{{TEST_COMMAND}}': os.environ.get('TEST_CMD', ''),
    '{{DEPLOY_VALIDATE_COMMAND}}': os.environ.get('DEPLOY_VALIDATE', ''),
    '{{TYPE_CHECK_COMMAND}}': os.environ.get('TYPE_CHECK_CMD', ''),
    '{{DESIGN_COLOR_RULES}}': os.environ.get('DESIGN_COLOR_RULES', 'Not configured. Run `/improve` to auto-detect or `/scaffold-design-system` to bootstrap.'),
    '{{DESIGN_COMPONENT_IMPORTS}}': os.environ.get('DESIGN_COMPONENT_IMPORTS', 'Not configured.'),
    '{{DESIGN_ICON_USAGE}}': os.environ.get('DESIGN_ICON_USAGE', 'Not configured.'),
    '{{DESIGN_CARD_PATTERNS}}': os.environ.get('DESIGN_CARD_PATTERNS', 'Not configured.'),
    '{{DESIGN_DARK_MODE}}': os.environ.get('DESIGN_DARK_MODE', 'Not configured.'),
}

for placeholder, value in replacements.items():
    content = content.replace(placeholder, value)

with open(os.path.join(project_dir, 'CLAUDE.md'), 'w') as f:
    f.write(content)
CLAUDE_MD_EOF
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
        salesforce)
            if [ -f "$PROJECT_DIR/package.json" ]; then
                if ! grep -q '"husky"' "$PROJECT_DIR/package.json" 2>/dev/null; then
                    echo "  Install pre-commit hooks with:"
                    echo "    npx husky init"
                    echo "    npm install --save-dev lint-staged"
                    echo '    echo "npx lint-staged" > .husky/pre-commit'
                else
                    echo "  husky already configured"
                fi
            fi
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

    # Append tracker env vars from config/trackers.json
    python3 << ENV_TRACKER_EOF
import json, os

framework_dir = os.environ.get('FRAMEWORK_DIR', '.')
project_dir = os.environ.get('PROJECT_DIR', '.')
tracker_name = '$TRACKER_NAME'

with open(os.path.join(framework_dir, 'config', 'trackers.json')) as f:
    trackers = json.load(f)

cfg = trackers.get(tracker_name, trackers['none'])
env_vars = cfg.get('env_vars', [])
if env_vars:
    with open(os.path.join(project_dir, '.env'), 'a') as f:
        for var in env_vars:
            f.write(var + '\n')
ENV_TRACKER_EOF

    # Append notification env vars from config/notifications.json
    python3 << ENV_NOTIFY_EOF
import json, os

framework_dir = os.environ.get('FRAMEWORK_DIR', '.')
project_dir = os.environ.get('PROJECT_DIR', '.')
notify_name = '$NOTIFY_NAME'

with open(os.path.join(framework_dir, 'config', 'notifications.json')) as f:
    notifications = json.load(f)

cfg = notifications.get(notify_name, notifications['none'])
env_var = cfg.get('env_var', '')
env_placeholder = cfg.get('env_placeholder', '')
if env_var and env_placeholder:
    with open(os.path.join(project_dir, '.env'), 'a') as f:
        f.write(f'{env_var}={env_placeholder}\n')
ENV_NOTIFY_EOF

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
echo "Design:     $DESIGN_SYSTEM_NAME"
echo ""
echo "Files created:"
echo "  .claude/skills/         — 17 workflow skills (incl. /team, /improve, /scaffold-design-system)"
echo "  .claude/agents/         — 12 AI agents (full team: architect to framework-improver)"
echo "  .claude/commands/       — 6 quick commands (quick-test, lint-fix, check-types, branch-status, changelog, dep-check)"
echo "  .claude/rules/          — 9 coding guardrails (api-routes, tests, database, config, error-handling, auth-security, data-protection, design-system, components)"
echo "  .claude/hooks/          — 5 lifecycle hooks (guardrails, pre-commit, post-edit-sync, session-start, session-stop)"
echo "  .claude/settings.local.json — project permissions, hooks"
echo "  .mcp.json               — MCP servers (Context7 documentation)"
echo "  ~/.claude/settings.json — user-level AI factory permissions (team orchestration enabled)"
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
echo "  1. Run /improve to auto-fill CLAUDE.md from project analysis"
echo "  2. Configure .env with your credentials"
echo "  3. Try /team review for a full codebase assessment"
echo "  4. Add domain knowledge: /add-reference my-domain topic"
echo "  5. Start developing: /develop TICKET-123"
echo ""
