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

# ── Skill files changed → CLAUDE.md skill listing may need updating ──
if echo "$FILE_PATH" | grep -qE "\.claude/skills/.*/SKILL\.md$"; then
    SKILL_NAME=$(echo "$FILE_PATH" | grep -oE "skills/[^/]+" | cut -d/ -f2)
    SUGGESTIONS="${SUGGESTIONS}Skill '${SKILL_NAME}' was modified — verify CLAUDE.md Skills Available table is current.\n"
fi

# ── New skill added → CLAUDE.md + README need updating ──
if echo "$FILE_PATH" | grep -qE "\.claude/skills/[^/]+/SKILL\.md$" && [ ! -s "$FILE_PATH.prev" ]; then
    SKILL_NAME=$(echo "$FILE_PATH" | grep -oE "skills/[^/]+" | cut -d/ -f2)
    SUGGESTIONS="${SUGGESTIONS}New skill '${SKILL_NAME}' detected — add to CLAUDE.md Skills Available and README.\n"
fi

# ── Agent files changed → CLAUDE.md agent listing may need updating ──
if echo "$FILE_PATH" | grep -qE "\.claude/agents/.*\.md$"; then
    AGENT_NAME="${BASENAME%.md}"
    SUGGESTIONS="${SUGGESTIONS}Agent '${AGENT_NAME}' was modified — verify CLAUDE.md Agents Available table is current.\n"
fi

# ── Rule files changed → check if patterns still match project files ──
if echo "$FILE_PATH" | grep -qE "\.claude/rules/.*\.md$"; then
    RULE_NAME="${BASENAME%.md}"
    SUGGESTIONS="${SUGGESTIONS}Rule '${RULE_NAME}' was modified — verify file patterns still match actual project structure.\n"
fi

# ── Command files changed → CLAUDE.md commands table may need updating ──
if echo "$FILE_PATH" | grep -qE "\.claude/commands/.*\.md$"; then
    CMD_NAME="${BASENAME%.md}"
    SUGGESTIONS="${SUGGESTIONS}Command '${CMD_NAME}' was modified — verify CLAUDE.md Commands Available table is current.\n"
fi

# ── Settings changed → permissions may affect agent/team behavior ──
if echo "$FILE_PATH" | grep -qE "settings\.(local\.)?json$"; then
    SUGGESTIONS="${SUGGESTIONS}Settings changed — verify agent tools and permissions are still appropriate.\n"
fi

# ── CLAUDE.md changed → README may need matching updates ──
if echo "$BASENAME" | grep -qiE "^claude\.md$"; then
    SUGGESTIONS="${SUGGESTIONS}CLAUDE.md was modified — verify README.md still matches (skills, agents, commands tables).\n"
fi

# ── Source code patterns that may need reference updates ──

# Apex classes
if echo "$FILE_PATH" | grep -qE "\.cls$"; then
    SUGGESTIONS="${SUGGESTIONS}Apex class modified — consider updating codebase reference: /add-reference salesforce apex-classes\n"
fi

# Apex triggers
if echo "$FILE_PATH" | grep -qE "\.trigger$"; then
    SUGGESTIONS="${SUGGESTIONS}Apex trigger modified — consider updating codebase reference: /add-reference salesforce triggers\n"
fi

# Salesforce objects/fields
if echo "$FILE_PATH" | grep -qE "\.(object|field)-meta\.xml$"; then
    SUGGESTIONS="${SUGGESTIONS}Salesforce metadata modified — consider updating codebase reference: /add-reference salesforce objects\n"
fi

# Salesforce flows
if echo "$FILE_PATH" | grep -qE "\.flow-meta\.xml$"; then
    SUGGESTIONS="${SUGGESTIONS}Flow modified — consider updating codebase reference: /add-reference salesforce flows\n"
fi

# API route files
if echo "$FILE_PATH" | grep -qiE "(route|controller|endpoint|handler|api)\.(ts|js|py|go|java|rb)$"; then
    SUGGESTIONS="${SUGGESTIONS}API route modified — consider updating API reference: /add-reference api endpoints\n"
fi

# Database models/migrations
if echo "$FILE_PATH" | grep -qiE "(model|migration|schema|entity)\.(ts|js|py|go|java|rb|prisma|sql)$"; then
    SUGGESTIONS="${SUGGESTIONS}Database schema modified — consider updating data model reference: /add-reference database models\n"
fi

# Config files (package.json, requirements.txt, etc.)
if echo "$BASENAME" | grep -qiE "^(package\.json|requirements\.txt|go\.mod|Cargo\.toml|build\.gradle|Gemfile|composer\.json|pom\.xml)$"; then
    SUGGESTIONS="${SUGGESTIONS}Dependencies changed — CLAUDE.md Tech Stack may need updating.\n"
fi

# Docker/CI config
if echo "$BASENAME" | grep -qiE "^(Dockerfile|docker-compose|\.github|\.gitlab-ci|Jenkinsfile)"; then
    SUGGESTIONS="${SUGGESTIONS}Infrastructure config changed — devops-engineer agent may need review.\n"
fi

# Output suggestions if any
if [ -n "$SUGGESTIONS" ]; then
    echo -e "[sync-check] $SUGGESTIONS"
fi
