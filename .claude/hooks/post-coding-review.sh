#!/bin/bash
# Framework Repo — Post-Coding Review Hook
# Runs at SessionEnd. If substantial source changes exist on the current branch
# relative to main, emits a reminder to run /team review.
# (Claude Code schema rejects `SessionStop` — the valid event name is `SessionEnd`.)

REVIEW_MIN_FILES=3
REVIEW_MIN_LOC=50

git rev-parse --git-dir >/dev/null 2>&1 || exit 0

REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
[ -z "$REPO_ROOT" ] && exit 0
COOLDOWN_DIR="$REPO_ROOT/.claude/state"
COOLDOWN_FILE="$COOLDOWN_DIR/last-review-nudge"
if [ -L "$COOLDOWN_FILE" ] || [ -L "$COOLDOWN_DIR" ]; then
    exit 0
fi

CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
[ -z "$CURRENT_BRANCH" ] && exit 0
[ "$CURRENT_BRANCH" = "main" ] && exit 0

git rev-parse --verify main >/dev/null 2>&1 || exit 0

CHANGED_SOURCE=$(git diff --name-only "main...HEAD" -- \
    ':(exclude)*.md' \
    ':(exclude)*.txt' \
    ':(exclude).gitignore' \
    ':(exclude)package-lock.json' \
    ':(exclude)yarn.lock' \
    ':(exclude)pnpm-lock.yaml' \
    ':(exclude)poetry.lock' \
    ':(exclude)Gemfile.lock' \
    ':(exclude)go.sum' \
    2>/dev/null | grep -cv '^$' || echo 0)

SHORTSTAT=$(git diff --shortstat "main...HEAD" -- \
    ':(exclude)*.md' \
    ':(exclude)*.txt' \
    ':(exclude).gitignore' \
    ':(exclude)*.lock' \
    ':(exclude)package-lock.json' \
    ':(exclude)yarn.lock' \
    ':(exclude)pnpm-lock.yaml' \
    ':(exclude)poetry.lock' \
    ':(exclude)Gemfile.lock' \
    ':(exclude)go.sum' \
    2>/dev/null)
INSERTIONS=$(echo "$SHORTSTAT" | grep -oE '[0-9]+ insertion' | grep -oE '[0-9]+' || echo 0)
DELETIONS=$(echo "$SHORTSTAT" | grep -oE '[0-9]+ deletion' | grep -oE '[0-9]+' || echo 0)
SOURCE_LOC=$(( ${INSERTIONS:-0} + ${DELETIONS:-0} ))

if [ "${CHANGED_SOURCE:-0}" -lt "$REVIEW_MIN_FILES" ] && [ "${SOURCE_LOC:-0}" -lt "$REVIEW_MIN_LOC" ]; then
    exit 0
fi

CURRENT_SHA=$(git rev-parse HEAD 2>/dev/null)
if [ -f "$COOLDOWN_FILE" ]; then
    LAST_NUDGE=$(cat "$COOLDOWN_FILE" 2>/dev/null)
    if [ "$LAST_NUDGE" = "${CURRENT_BRANCH}:${CURRENT_SHA}" ]; then
        exit 0
    fi
fi

mkdir -p "$(dirname "$COOLDOWN_FILE")" 2>/dev/null
echo "${CURRENT_BRANCH}:${CURRENT_SHA}" > "$COOLDOWN_FILE" 2>/dev/null

echo ""
echo "─────────────────────────────────────────────"
echo "  Post-Coding Review Recommendation"
echo "─────────────────────────────────────────────"
echo "  Branch:       $CURRENT_BRANCH"
echo "  Source files: $CHANGED_SOURCE changed vs main"
echo "  Source LOC:   $SOURCE_LOC changed (+$INSERTIONS / -$DELETIONS)"
echo ""
echo "  Suggested next step:"
echo "    /team review    — code-reviewer + security-auditor + ui-ux-reviewer"
echo "  Or for broader coverage:"
echo "    /team quality   — code-reviewer + test-writer + performance-optimizer"
echo "─────────────────────────────────────────────"
echo ""
