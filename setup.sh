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
            1)
                DESIGN_SYSTEM_NAME="untitled-ui"
                DESIGN_COLOR_RULES="**MUST use semantic color classes — never raw colors like \`text-gray-900\` or \`bg-blue-700\`.**

Use \`text-primary\`, \`text-secondary\`, \`text-tertiary\` for text. Use \`border-primary\`, \`border-secondary\` for borders. Use \`bg-primary\`, \`bg-secondary\`, \`bg-brand-solid\` for backgrounds. Use \`fg-primary\`, \`fg-secondary\`, \`fg-quaternary\` for icons/foreground elements.

Semantic variants exist for: \`brand\`, \`error\`, \`warning\`, \`success\`, plus \`_hover\`, \`_on-brand\`, \`_alt\`, \`_subtle\` modifiers. See \`src/styles/theme.css\` for the full color token reference."
                DESIGN_COMPONENT_IMPORTS='```typescript
import { Button } from "@/components/base/buttons/button";
import { Input } from "@/components/base/input/input";
import { Select } from "@/components/base/select/select";
import { Checkbox } from "@/components/base/checkbox/checkbox";
import { Badge } from "@/components/base/badges/badges";
import { Avatar } from "@/components/base/avatar/avatar";
```

Never use raw `<button>`, `<input>`, or `<select>` elements in feature code. Always use the base component library.'
                DESIGN_ICON_USAGE='```typescript
import { Home01, Settings01, ChevronDown } from "@untitledui/icons";
```

Sizing: `size-4` (16px), `size-5` (20px), `size-6` (24px). Color: use semantic text colors (`text-fg-secondary`). Never use inline `<svg>` elements.'
                DESIGN_CARD_PATTERNS='**Glass cards**: `bg-primary/80 backdrop-blur-xl border border-secondary shadow-xs`
**Separator lines**: `border-black/15 dark:border-white/15`
**Default transitions**: `transition duration-100 ease-linear`'
                DESIGN_DARK_MODE="Dark mode is handled at the design token level via CSS custom properties. Components should NOT need per-element \`dark:\` classes when using semantic tokens. If a component needs a dark mode override, the design token system has a gap — fix the token, don't patch the component."
                ;;
            2)
                DESIGN_SYSTEM_NAME="shadcn"
                DESIGN_COLOR_RULES="**Use CSS variable-based colors from the shadcn/ui theme.**

Use \`text-foreground\`, \`text-muted-foreground\`, \`text-primary\`, \`text-destructive\` etc. Never use raw Tailwind colors like \`text-gray-900\`. See \`globals.css\` or \`tailwind.config\` for the full token reference."
                DESIGN_COMPONENT_IMPORTS='```typescript
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Select } from "@/components/ui/select";
import { Card, CardHeader, CardContent } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
```

Never use raw HTML elements for interactive controls in feature code. Always use the shadcn/ui component library.'
                DESIGN_ICON_USAGE='```typescript
import { Home, Settings, ChevronDown } from "lucide-react";
```

Sizing: `size={16}`, `size={20}`, `size={24}` or `className="h-4 w-4"`. Color: inherits from parent text color. Never use inline `<svg>` elements.'
                DESIGN_CARD_PATTERNS='Use `<Card>` component for all card-like containers. Do not hand-roll `rounded-xl border border-gray-200 bg-white` — use the Card abstraction.'
                DESIGN_DARK_MODE="Dark mode is handled via the \`.dark\` class and CSS variables. Components using semantic color tokens adapt automatically. Do not add manual \`dark:bg-gray-*\` overrides."
                ;;
            3)
                DESIGN_SYSTEM_NAME="custom"
                DESIGN_COLOR_RULES="{{DESIGN_COLOR_RULES}} — Run \`/improve\` to auto-detect from project files, or fill in manually."
                DESIGN_COMPONENT_IMPORTS="{{DESIGN_COMPONENT_IMPORTS}} — Run \`/improve\` to auto-detect, or fill in manually."
                DESIGN_ICON_USAGE="{{DESIGN_ICON_USAGE}} — Run \`/improve\` to auto-detect, or fill in manually."
                DESIGN_CARD_PATTERNS="{{DESIGN_CARD_PATTERNS}} — Run \`/improve\` to auto-detect, or fill in manually."
                DESIGN_DARK_MODE="{{DESIGN_DARK_MODE}} — Run \`/improve\` to auto-detect, or fill in manually."
                ;;
            4|*)
                DESIGN_SYSTEM_NAME="none"
                DESIGN_COLOR_RULES="No design system configured. Consider running \`/scaffold-design-system\` to bootstrap one."
                DESIGN_COMPONENT_IMPORTS="No component library configured."
                DESIGN_ICON_USAGE="No icon library configured."
                DESIGN_CARD_PATTERNS="No card patterns documented."
                DESIGN_DARK_MODE="No dark mode conventions documented."
                ;;
        esac
        ;;
    *)
        # Non-frontend projects don't need a design system
        DESIGN_COLOR_RULES="N/A — backend project."
        DESIGN_COMPONENT_IMPORTS="N/A — backend project."
        DESIGN_ICON_USAGE="N/A — backend project."
        DESIGN_CARD_PATTERNS="N/A — backend project."
        DESIGN_DARK_MODE="N/A — backend project."
        ;;
esac

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
    salesforce)
        FORMAT_CMD='npx prettier --write "path/to/specific/file"'
        FORMAT_VERIFY='npm run prettier:verify'
        TEST_CMD='sf apex run test -l RunLocalTests -w 30'
        DEPLOY_VALIDATE='sf project deploy validate -x manifest/package.xml -l RunLocalTests -w 30 -o {alias}'
        ;;
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

# Build type check, dep check, security audit commands
TYPE_CHECK_CMD=""
DEP_CHECK_CMD=""
SECURITY_AUDIT_CMD=""
ERROR_TRACKING=""
DEFAULT_MODEL="sonnet"

case $PROJECT_TYPE_NAME in
    salesforce)
        TYPE_CHECK_CMD='sf apex run test --code-coverage -l RunLocalTests'
        DEP_CHECK_CMD='# N/A for Salesforce'
        SECURITY_AUDIT_CMD='sf scanner run --target . --format csv'
        ERROR_TRACKING='ErrorTrackingUtils.trackException(e)'
        ;;
    nodejs|react)
        TYPE_CHECK_CMD='npx tsc --noEmit'
        DEP_CHECK_CMD='npm outdated && npm audit'
        SECURITY_AUDIT_CMD='npm audit'
        ERROR_TRACKING='console.error(error)'
        ;;
    python)
        TYPE_CHECK_CMD='mypy .'
        DEP_CHECK_CMD='pip list --outdated && pip-audit'
        SECURITY_AUDIT_CMD='pip-audit && bandit -r .'
        ERROR_TRACKING='logger.exception("error", exc_info=True)'
        ;;
    go)
        TYPE_CHECK_CMD='go vet ./...'
        DEP_CHECK_CMD='go list -m -u all'
        SECURITY_AUDIT_CMD='govulncheck ./...'
        ERROR_TRACKING='log.Printf("error: %v", err)'
        ;;
    java)
        TYPE_CHECK_CMD='./gradlew compileJava'
        DEP_CHECK_CMD='./gradlew dependencyUpdates'
        SECURITY_AUDIT_CMD='./gradlew dependencyCheckAnalyze'
        ERROR_TRACKING='log.error("error", e)'
        ;;
    rails)
        TYPE_CHECK_CMD='bundle exec srb tc'
        DEP_CHECK_CMD='bundle outdated && bundle audit check'
        SECURITY_AUDIT_CMD='bundle audit check && brakeman'
        ERROR_TRACKING='Rails.logger.error(e.message)'
        ;;
    *)
        TYPE_CHECK_CMD='# Configure your type check command'
        DEP_CHECK_CMD='# Configure your dependency check command'
        SECURITY_AUDIT_CMD='# Configure your security audit command'
        ERROR_TRACKING='// Log the error with full context'
        ;;
esac

# Build file pattern placeholders for rules (per project type)
API_ROUTE_PATTERNS=""
COMPONENT_PATTERNS=""
TEST_PATTERNS=""
DATABASE_PATTERNS=""
SOURCE_PATTERNS=""

case $PROJECT_TYPE_NAME in
    salesforce)
        API_ROUTE_PATTERNS='"**/RestResource*.cls"'
        COMPONENT_PATTERNS='"**/lwc/**/*.js", "**/lwc/**/*.html"'
        TEST_PATTERNS='"*Test.cls", "*_Test.cls"'
        DATABASE_PATTERNS='"**/*.object-meta.xml", "**/*.field-meta.xml"'
        SOURCE_PATTERNS='"**/*.cls", "**/*.trigger"'
        ;;
    nodejs)
        API_ROUTE_PATTERNS='"**/routes/**/*.ts", "**/routes/**/*.js", "**/*.route.ts", "**/*.api.ts"'
        COMPONENT_PATTERNS='"**/*.tsx", "**/*.jsx"'
        TEST_PATTERNS='"**/*.test.ts", "**/*.spec.ts", "**/__tests__/**/*"'
        DATABASE_PATTERNS='"**/migrations/**/*", "**/models/**/*", "schema.prisma"'
        SOURCE_PATTERNS='"**/*.ts", "**/*.js"'
        ;;
    react)
        API_ROUTE_PATTERNS='"app/api/**/*.ts", "**/routes/**/*.ts", "**/*.api.ts"'
        COMPONENT_PATTERNS='"**/*.tsx", "**/*.jsx", "components/**/*"'
        TEST_PATTERNS='"**/*.test.ts", "**/*.test.tsx", "**/*.spec.ts", "**/__tests__/**/*"'
        DATABASE_PATTERNS='"**/migrations/**/*", "**/models/**/*", "schema.prisma"'
        SOURCE_PATTERNS='"**/*.ts", "**/*.tsx", "**/*.js", "**/*.jsx"'
        ;;
    python)
        API_ROUTE_PATTERNS='"**/routes/*.py", "**/views/*.py", "**/endpoints/*.py"'
        COMPONENT_PATTERNS='"**/templates/**/*.html"'
        TEST_PATTERNS='"test_*.py", "*_test.py", "tests/**/*.py"'
        DATABASE_PATTERNS='"**/models.py", "**/models/*.py", "**/migrations/**/*", "alembic/**/*"'
        SOURCE_PATTERNS='"**/*.py"'
        ;;
    go)
        API_ROUTE_PATTERNS='"**/handlers/*.go", "**/api/*.go", "**/routes/*.go"'
        COMPONENT_PATTERNS='"**/templates/**/*.html", "**/templates/**/*.templ"'
        TEST_PATTERNS='"*_test.go"'
        DATABASE_PATTERNS='"**/models/*.go", "**/migrations/**/*", "**/repository/*.go"'
        SOURCE_PATTERNS='"**/*.go"'
        ;;
    java)
        API_ROUTE_PATTERNS='"**/*Controller.java", "**/*Resource.java", "**/*Endpoint.java"'
        COMPONENT_PATTERNS='"**/templates/**/*.html"'
        TEST_PATTERNS='"**/*Test.java", "**/*Spec.java", "src/test/**/*"'
        DATABASE_PATTERNS='"**/entity/*.java", "**/repository/*.java", "**/migrations/**/*"'
        SOURCE_PATTERNS='"**/*.java"'
        ;;
    rails)
        API_ROUTE_PATTERNS='"app/controllers/**/*.rb", "config/routes.rb"'
        COMPONENT_PATTERNS='"app/views/**/*.erb", "app/helpers/**/*.rb", "app/components/**/*.rb"'
        TEST_PATTERNS='"spec/**/*.rb", "test/**/*.rb"'
        DATABASE_PATTERNS='"db/migrate/**/*", "app/models/**/*.rb"'
        SOURCE_PATTERNS='"**/*.rb"'
        ;;
    *)
        API_ROUTE_PATTERNS='"**/routes/**/*", "**/api/**/*"'
        COMPONENT_PATTERNS='"**/components/**/*"'
        TEST_PATTERNS='"**/*test*", "**/*spec*"'
        DATABASE_PATTERNS='"**/models/**/*", "**/migrations/**/*"'
        SOURCE_PATTERNS='"**/*.{ts,js,py,go,java,rb}"'
        ;;
esac

# Build notification command
NOTIFY_CMD=""
case $NOTIFY_NAME in
    slack)
        NOTIFY_CMD='```bash
export $(grep -v '"'"'^#'"'"' .env | grep -v '"'"'^$'"'"' | xargs) && curl -s -X POST "${SLACK_WEBHOOK_URL}" \
  -H "Content-Type: application/json" \
  -d "{\"text\":\"Factory halted for {TICKET_ID}: {reason}. Manual intervention needed.\"}"
```'
        ;;
    teams)
        NOTIFY_CMD='```bash
export $(grep -v '"'"'^#'"'"' .env | grep -v '"'"'^$'"'"' | xargs) && curl -s -X POST "${TEAMS_WEBHOOK_URL}" \
  -H "Content-Type: application/json" \
  -d "{\"text\":\"Factory halted for {TICKET_ID}: {reason}. Manual intervention needed.\"}"
```'
        ;;
    discord)
        NOTIFY_CMD='```bash
export $(grep -v '"'"'^#'"'"' .env | grep -v '"'"'^$'"'"' | xargs) && curl -s -X POST "${DISCORD_WEBHOOK_URL}" \
  -H "Content-Type: application/json" \
  -d "{\"content\":\"Factory halted for {TICKET_ID}: {reason}. Manual intervention needed.\"}"
```'
        ;;
    none)
        NOTIFY_CMD='No notification system configured. Log the halt message.'
        ;;
esac

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
export TRACKER_URL TRACKER_LINK_PR TRACKER_CREATE NOTIFY_CMD
export ERROR_TRACKING
export API_ROUTE_PATTERNS COMPONENT_PATTERNS TEST_PATTERNS
export DATABASE_PATTERNS SOURCE_PATTERNS

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
    '{{TRACKER_CREATE_BUG}}': os.environ.get('TRACKER_CREATE', 'Configure bug creation.'),
    '{{TRACKER_UPDATE_FIELDS}}': 'Configure tracker field update command.',
    '{{TRACKER_SET_DEPLOYED}}': 'Configure tracker deployed state transition.',

    # Notification placeholders
    '{{NOTIFY_HALT}}': os.environ.get('NOTIFY_CMD', 'Log halt message.'),
    '{{NOTIFY_HALT_FACTORY}}': os.environ.get('NOTIFY_CMD', 'Log halt message.'),
    '{{NOTIFY_MERGE_RESOLVE}}': os.environ.get('NOTIFY_CMD', 'Log merge resolution message.').replace('halted', 'merge-resolved').replace('Manual intervention needed', 'Merged result needs human verification'),
    '{{NOTIFY_DEPLOY_SUCCESS}}': os.environ.get('NOTIFY_CMD', 'Log deploy success.').replace('halted', 'deployed').replace('Manual intervention needed', 'Deployment complete'),

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
