#!/bin/bash
# Framework Repo — Post-Edit Sync Hook
# Flags documentation that needs updating when framework files change.

FILE_PATH="$1"
[ -z "$FILE_PATH" ] && exit 0
FILE_PATH="${FILE_PATH//\\//}"
BASENAME=$(basename "$FILE_PATH")

SUGGESTIONS=""

# Template agents changed → update README agent table, CLAUDE.md template, docs
if echo "$FILE_PATH" | grep -qE "templates/agents/.*\.md$"; then
    AGENT_NAME="${BASENAME%.md}"
    SUGGESTIONS="${SUGGESTIONS}Agent '${AGENT_NAME}' changed → update README.md agents table, templates/CLAUDE.md.template agents tables, docs/agents-commands-rules.md, docs/teams.md, skills/team/SKILL.md\n"
fi

# Template commands changed
if echo "$FILE_PATH" | grep -qE "templates/commands/.*\.md$"; then
    CMD_NAME="${BASENAME%.md}"
    SUGGESTIONS="${SUGGESTIONS}Command '${CMD_NAME}' changed → update README.md commands table, templates/CLAUDE.md.template commands table, docs/agents-commands-rules.md\n"
fi

# Template rules changed
if echo "$FILE_PATH" | grep -qE "templates/rules/.*\.md$"; then
    RULE_NAME="${BASENAME%.md}"
    SUGGESTIONS="${SUGGESTIONS}Rule '${RULE_NAME}' changed → update README.md rules table, docs/agents-commands-rules.md\n"
fi

# Template hooks changed
if echo "$FILE_PATH" | grep -qE "templates/hooks/.*\.sh$"; then
    HOOK_NAME="${BASENAME%.sh}"
    SUGGESTIONS="${SUGGESTIONS}Hook '${HOOK_NAME}' changed → update README.md hooks table, docs/agents-commands-rules.md\n"
fi

# Skills changed
if echo "$FILE_PATH" | grep -qE "skills/.*/SKILL\.md$"; then
    SKILL_NAME=$(echo "$FILE_PATH" | grep -oE "skills/[^/]+" | cut -d/ -f2)
    SUGGESTIONS="${SUGGESTIONS}Skill '${SKILL_NAME}' changed → update README.md skills table, templates/CLAUDE.md.template skills table\n"
fi

# Setup scripts changed → check parity
if echo "$BASENAME" | grep -qE "^setup\.(sh|ps1)$"; then
    SUGGESTIONS="${SUGGESTIONS}Setup script changed → verify setup.sh and setup.ps1 have parity (same prompts, placeholders, copy ops, summary)\n"
fi

# Settings templates changed
if echo "$FILE_PATH" | grep -qE "templates/settings.*\.json$"; then
    SUGGESTIONS="${SUGGESTIONS}Settings template changed → update README.md permissions section, docs/agents-commands-rules.md\n"
fi

# README changed → check CLAUDE.md template parity
if echo "$BASENAME" | grep -qiE "^README\.md$"; then
    SUGGESTIONS="${SUGGESTIONS}README changed → verify templates/CLAUDE.md.template tables still match\n"
fi

# CLAUDE.md template changed → check README parity
if echo "$FILE_PATH" | grep -qE "templates/CLAUDE\.md\.template$"; then
    SUGGESTIONS="${SUGGESTIONS}CLAUDE.md template changed → verify README.md tables still match\n"
fi

if [ -n "$SUGGESTIONS" ]; then
    echo -e "[framework-sync] $SUGGESTIONS"
fi
