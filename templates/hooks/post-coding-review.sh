#!/bin/bash
# Claude Code Framework — Post-Coding Review Hook
# Runs at SessionEnd. If substantial source changes exist on the current branch
# relative to {{BASE_BRANCH}}, emits a reminder to run /team review.
# (Claude Code schema rejects `SessionStop` — the valid event name is `SessionEnd`.)
#
# Hooks cannot directly spawn agents — the recommendation appears at session end
# and the user invokes /team review manually. A cooldown flag prevents repeat
# nudges within the same branch.

# Thresholds — changes below these are not worth suggesting a review for
REVIEW_MIN_FILES=3
REVIEW_MIN_LOC=50

# Must be inside a git repo
git rev-parse --git-dir >/dev/null 2>&1 || exit 0

# Resolve cooldown file to an absolute path under the git root so the hook
# behaves identically regardless of which subdirectory triggered it.
# A pre-existing symlink at this path is rejected (potential TOCTOU / misuse).
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
[ -z "$REPO_ROOT" ] && exit 0
COOLDOWN_DIR="$REPO_ROOT/.claude/state"
COOLDOWN_FILE="$COOLDOWN_DIR/last-review-nudge"
if [ -L "$COOLDOWN_FILE" ] || [ -L "$COOLDOWN_DIR" ]; then
    # Refuse to write through a symlink
    exit 0
fi

CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
[ -z "$CURRENT_BRANCH" ] && exit 0
[ "$CURRENT_BRANCH" = "{{BASE_BRANCH}}" ] && exit 0

# Verify BASE_BRANCH is a valid ref before attempting a three-dot diff
# (silently exits on fresh clones where base isn't tracked locally)
git rev-parse --verify "{{BASE_BRANCH}}" >/dev/null 2>&1 || exit 0

# Count changed source files vs base branch (exclude docs/lockfiles)
CHANGED_SOURCE=$(git diff --name-only "{{BASE_BRANCH}}...HEAD" -- \
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

# Count changed lines of source (insertions + deletions — a 500-line delete
# warrants review just as much as a 500-line add)
SHORTSTAT=$(git diff --shortstat "{{BASE_BRANCH}}...HEAD" -- \
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

# Threshold check
if [ "${CHANGED_SOURCE:-0}" -lt "$REVIEW_MIN_FILES" ] && [ "${SOURCE_LOC:-0}" -lt "$REVIEW_MIN_LOC" ]; then
    exit 0
fi

# Cooldown: skip if we already nudged for this branch+HEAD
CURRENT_SHA=$(git rev-parse HEAD 2>/dev/null)
if [ -f "$COOLDOWN_FILE" ]; then
    LAST_NUDGE=$(cat "$COOLDOWN_FILE" 2>/dev/null)
    if [ "$LAST_NUDGE" = "${CURRENT_BRANCH}:${CURRENT_SHA}" ]; then
        exit 0
    fi
fi

# Record this nudge
mkdir -p "$(dirname "$COOLDOWN_FILE")" 2>/dev/null
echo "${CURRENT_BRANCH}:${CURRENT_SHA}" > "$COOLDOWN_FILE" 2>/dev/null

# Emit the recommendation
echo ""
echo "─────────────────────────────────────────────"
echo "  Post-Coding Review Recommendation"
echo "─────────────────────────────────────────────"
echo "  Branch:       $CURRENT_BRANCH"
echo "  Source files: $CHANGED_SOURCE changed vs {{BASE_BRANCH}}"
echo "  Source LOC:   $SOURCE_LOC changed (+$INSERTIONS / -$DELETIONS)"
echo ""
echo "  Suggested next step:"
echo "    /team review    — code-reviewer + security-auditor + ui-ux-reviewer"
echo "  Or for broader coverage:"
echo "    /team quality   — code-reviewer + test-writer + performance-optimizer"
echo "─────────────────────────────────────────────"
echo ""
