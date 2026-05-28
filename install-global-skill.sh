#!/bin/bash
# Installs the global /install-framework skill into ~/.claude/skills/.
# Run from a clone of claude-code-framework.
set -e

FRAMEWORK_DIR="$(cd "$(dirname "$0")" && pwd)"
SRC="$FRAMEWORK_DIR/global-skills/install-framework"
DEST="$HOME/.claude/skills/install-framework"

if [ ! -d "$SRC" ]; then
    echo "ERROR: $SRC not found. Run this from a clone of claude-code-framework."
    exit 1
fi

mkdir -p "$HOME/.claude/skills"
if [ -d "$DEST" ]; then
    echo "Updating existing global skill at $DEST"
    rm -rf "$DEST"
fi
cp -r "$SRC" "$DEST"
echo "Installed /install-framework to $DEST"
echo "It is now available in Claude Code (CLI, desktop, web)."
