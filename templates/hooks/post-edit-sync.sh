#!/bin/bash
# Claude Code Framework — Post-Edit Sync Hook
# Triggers after Edit/Write operations to flag documentation that may need updating.
# Configure in settings.json under hooks.PostToolUse

FILE_PATH="$1"

# Skip if no file path provided
[ -z "$FILE_PATH" ] && exit 0

# Normalize path separators
FILE_PATH="${FILE_PATH//\\//}"
BASENAME=$(basename "$FILE_PATH")
DIRNAME=$(dirname "$FILE_PATH")

SUGGESTIONS=""

# ── Skill files changed → CLAUDE.md + README skill listings may need updating ──
if [[ "$FILE_PATH" =~ \.claude/skills/[^/]+/SKILL\.md$ ]]; then
    SKILL_NAME="${FILE_PATH##*skills/}"
    SKILL_NAME="${SKILL_NAME%%/*}"
    SUGGESTIONS="${SUGGESTIONS}Skill '${SKILL_NAME}' was modified — verify CLAUDE.md Skills Available table and README are current.\n"
fi

# ── Agent files changed → CLAUDE.md agent listing may need updating ──
if [[ "$FILE_PATH" =~ \.claude/agents/.*\.md$ ]]; then
    AGENT_NAME="${BASENAME%.md}"
    SUGGESTIONS="${SUGGESTIONS}Agent '${AGENT_NAME}' was modified — verify CLAUDE.md Agents Available table is current.\n"
fi

# ── Rule files changed → check if patterns still match project files ──
if [[ "$FILE_PATH" =~ \.claude/rules/.*\.md$ ]]; then
    RULE_NAME="${BASENAME%.md}"
    SUGGESTIONS="${SUGGESTIONS}Rule '${RULE_NAME}' was modified — verify file patterns still match actual project structure.\n"
fi

# ── Command files changed → CLAUDE.md commands table may need updating ──
if [[ "$FILE_PATH" =~ \.claude/commands/.*\.md$ ]]; then
    CMD_NAME="${BASENAME%.md}"
    SUGGESTIONS="${SUGGESTIONS}Command '${CMD_NAME}' was modified — verify CLAUDE.md Commands Available table is current.\n"
fi

# ── Settings changed → permissions may affect agent/team behavior ──
if [[ "$FILE_PATH" =~ settings\.(local\.)?json$ ]]; then
    SUGGESTIONS="${SUGGESTIONS}Settings changed — verify agent tools and permissions are still appropriate.\n"
fi

# ── CLAUDE.md changed → README may need matching updates ──
if [[ "$BASENAME" =~ ^[Cc][Ll][Aa][Uu][Dd][Ee]\.[Mm][Dd]$ ]]; then
    SUGGESTIONS="${SUGGESTIONS}CLAUDE.md was modified — verify README.md still matches (skills, agents, commands tables).\n"
fi

# ── Source code patterns that may need reference updates ──

# Apex classes
if [[ "$FILE_PATH" =~ \.cls$ ]]; then
    SUGGESTIONS="${SUGGESTIONS}Apex class modified — consider updating codebase reference: /add-reference salesforce apex-classes\n"
fi

# Apex triggers
if [[ "$FILE_PATH" =~ \.trigger$ ]]; then
    SUGGESTIONS="${SUGGESTIONS}Apex trigger modified — consider updating codebase reference: /add-reference salesforce triggers\n"
fi

# Salesforce objects/fields
if [[ "$FILE_PATH" =~ \.(object|field)-meta\.xml$ ]]; then
    SUGGESTIONS="${SUGGESTIONS}Salesforce metadata modified — consider updating codebase reference: /add-reference salesforce objects\n"
fi

# Salesforce flows
if [[ "$FILE_PATH" =~ \.flow-meta\.xml$ ]]; then
    SUGGESTIONS="${SUGGESTIONS}Flow modified — consider updating codebase reference: /add-reference salesforce flows\n"
fi

# API route files
if [[ "$FILE_PATH" =~ (route|controller|endpoint|handler|api)\.(ts|js|py|go|java|rb)$ ]]; then
    SUGGESTIONS="${SUGGESTIONS}API route modified — consider updating API reference: /add-reference api endpoints\n"
fi

# Database models/migrations
if [[ "$FILE_PATH" =~ (model|migration|schema|entity)\.(ts|js|py|go|java|rb|prisma|sql)$ ]]; then
    SUGGESTIONS="${SUGGESTIONS}Database schema modified — consider updating data model reference: /add-reference database models\n"
fi

# Config files (package.json, requirements.txt, etc.)
if [[ "$BASENAME" =~ ^(package\.json|requirements\.txt|go\.mod|Cargo\.toml|build\.gradle|Gemfile|composer\.json|pom\.xml)$ ]]; then
    SUGGESTIONS="${SUGGESTIONS}Dependencies changed — CLAUDE.md Tech Stack may need updating.\n"
fi

# Docker/CI config
if [[ "$BASENAME" =~ ^(Dockerfile|docker-compose|\.github|\.gitlab-ci|Jenkinsfile) ]]; then
    SUGGESTIONS="${SUGGESTIONS}Infrastructure config changed — devops-engineer agent may need review.\n"
fi

# Output suggestions if any
if [ -n "$SUGGESTIONS" ]; then
    echo -e "[sync-check] $SUGGESTIONS"
fi
