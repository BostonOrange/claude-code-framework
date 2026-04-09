#!/bin/bash
# Claude Code status line — shows project context at a glance
# Install: add to ~/.claude/settings.json:
#   "statusLine": { "type": "command", "command": "~/.claude/statusline-command.sh" }

# Line 1: Project directory
PROJECT_DIR=$(basename "$(pwd)")
echo "📂 ${PROJECT_DIR}"

# Line 2: Git branch + remote URL
BRANCH=$(git branch --show-current 2>/dev/null || echo "no-branch")
REMOTE_URL=$(git remote get-url origin 2>/dev/null | sed 's/\.git$//' || echo "")
if [ -n "$REMOTE_URL" ]; then
    echo "🌿 ${BRANCH} 🔗 ${REMOTE_URL}/tree/${BRANCH}"
else
    echo "🌿 ${BRANCH}"
fi

# Line 3: Environment info (customize per project type)
# Examples:
#   Node.js:    node --version
#   Python:     python --version
#   Go:         go version | awk '{print $3}'
#   Java:       java --version 2>&1 | head -1
#   Salesforce: sf org display --target-org default 2>/dev/null | grep "Username" | awk '{print $2}'
echo "📦 $(git log --oneline -1 2>/dev/null | head -c 50)"
