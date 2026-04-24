#!/bin/bash
# Claude Code Framework — File Count Consistency Validation
# Ensures documented counts match actual file counts
# Exit 0 if all pass, exit 1 if any mismatches

set -euo pipefail

FRAMEWORK_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SETUP_SH="$FRAMEWORK_DIR/setup.sh"
README="$FRAMEWORK_DIR/README.md"

PASS=0
FAIL=0

echo "======================================"
echo "  File Count Consistency"
echo "======================================"
echo ""

# ── Count actual files ─────────────────────────────────────────

# Skills: count directories in skills/ excluding _template
ACTUAL_SKILLS=$(find "$FRAMEWORK_DIR/skills" -mindepth 1 -maxdepth 1 -type d ! -name "_template" | wc -l | tr -d ' ')

# Agents: count .md files in templates/agents/
ACTUAL_AGENTS=$(find "$FRAMEWORK_DIR/templates/agents" -maxdepth 1 -name "*.md" -type f | wc -l | tr -d ' ')

# Commands: count .md files in templates/commands/
ACTUAL_COMMANDS=$(find "$FRAMEWORK_DIR/templates/commands" -maxdepth 1 -name "*.md" -type f | wc -l | tr -d ' ')

# Rules: count .md files in templates/rules/
ACTUAL_RULES=$(find "$FRAMEWORK_DIR/templates/rules" -maxdepth 1 -name "*.md" -type f | wc -l | tr -d ' ')

# Hooks: count .sh files in templates/hooks/ — exclude _prefixed library files (convention: _lib.sh, _helpers.sh)
ACTUAL_HOOKS=$(find "$FRAMEWORK_DIR/templates/hooks" -maxdepth 1 -name "*.sh" -type f -not -name "_*" | wc -l | tr -d ' ')

# Workflows: count .yml files in workflows/
ACTUAL_WORKFLOWS=$(find "$FRAMEWORK_DIR/workflows" -maxdepth 1 -name "*.yml" -type f | wc -l | tr -d ' ')

echo "Actual file counts:"
echo "  Skills:    $ACTUAL_SKILLS"
echo "  Agents:    $ACTUAL_AGENTS"
echo "  Commands:  $ACTUAL_COMMANDS"
echo "  Rules:     $ACTUAL_RULES"
echo "  Hooks:     $ACTUAL_HOOKS"
echo "  Workflows: $ACTUAL_WORKFLOWS"
echo ""

# ── Helper: check a count against a source ─────────────────────

check_count() {
    local label="$1"
    local actual="$2"
    local documented="$3"
    local source="$4"

    if [ "$actual" = "$documented" ]; then
        echo "  [PASS] $label: $actual (matches $source)"
        PASS=$((PASS + 1))
    else
        echo "  [FAIL] $label: actual=$actual, documented=$documented in $source"
        FAIL=$((FAIL + 1))
    fi
}

# ── Extract counts from setup.sh summary ───────────────────────

echo "Checking setup.sh summary..."

SETUP_SKILLS=$(grep -o '[0-9]\+ workflow skills' "$SETUP_SH" | head -1 | grep -o '^[0-9]\+' || echo "?")
SETUP_AGENTS=$(grep -o '[0-9]\+ AI agents' "$SETUP_SH" | head -1 | grep -o '^[0-9]\+' || echo "?")
SETUP_COMMANDS=$(grep -o '[0-9]\+ quick commands' "$SETUP_SH" | head -1 | grep -o '^[0-9]\+' || echo "?")
SETUP_RULES=$(grep -o '[0-9]\+ coding guardrails' "$SETUP_SH" | head -1 | grep -o '^[0-9]\+' || echo "?")
SETUP_HOOKS=$(grep -o '[0-9]\+ lifecycle hooks' "$SETUP_SH" | head -1 | grep -o '^[0-9]\+' || echo "?")
SETUP_WORKFLOWS=$(grep -o '[0-9]\+ CI/CD pipelines' "$SETUP_SH" | head -1 | grep -o '^[0-9]\+' || echo "?")

check_count "Skills (setup.sh)"    "$ACTUAL_SKILLS"    "$SETUP_SKILLS"    "setup.sh"
check_count "Agents (setup.sh)"    "$ACTUAL_AGENTS"    "$SETUP_AGENTS"    "setup.sh"
check_count "Commands (setup.sh)"  "$ACTUAL_COMMANDS"  "$SETUP_COMMANDS"  "setup.sh"
check_count "Rules (setup.sh)"     "$ACTUAL_RULES"     "$SETUP_RULES"     "setup.sh"
check_count "Hooks (setup.sh)"     "$ACTUAL_HOOKS"     "$SETUP_HOOKS"     "setup.sh"
check_count "Workflows (setup.sh)" "$ACTUAL_WORKFLOWS" "$SETUP_WORKFLOWS" "setup.sh"

echo ""

# ── Extract counts from README.md ──────────────────────────────

echo "Checking README.md..."

# README uses various patterns to state counts
README_SKILLS=$(grep -o '[0-9]\+ workflow skills' "$README" | head -1 | grep -o '^[0-9]\+' || echo "?")
README_AGENTS=$(grep -o '[0-9]\+ AI agents\|[0-9]\+ specialized teammates\|[0-9]\+ AI agent definitions' "$README" | head -1 | grep -o '^[0-9]\+' || echo "?")
README_COMMANDS=$(grep -o '[0-9]\+ quick commands\|[0-9]\+ one-word\|[0-9]\+ Commands' "$README" | head -1 | grep -o '^[0-9]\+' || echo "?")
README_RULES=$(grep -o '[0-9]\+ file-pattern\|[0-9]\+ coding guardrails\|[0-9]\+ guardrails' "$README" | head -1 | grep -o '^[0-9]\+' || echo "?")
README_HOOKS=$(grep -o '[0-9]\+ lifecycle hooks' "$README" | head -1 | grep -o '^[0-9]\+' || echo "?")
README_WORKFLOWS=$(grep -o '[0-9]\+ CI/CD pipelines\|[0-9]\+ CI/CD templates\|[0-9]\+ GitHub Actions' "$README" | head -1 | grep -o '^[0-9]\+' || echo "?")

check_count "Skills (README)"    "$ACTUAL_SKILLS"    "$README_SKILLS"    "README.md"
check_count "Agents (README)"    "$ACTUAL_AGENTS"    "$README_AGENTS"    "README.md"
check_count "Commands (README)"  "$ACTUAL_COMMANDS"  "$README_COMMANDS"  "README.md"
check_count "Rules (README)"     "$ACTUAL_RULES"     "$README_RULES"     "README.md"
check_count "Hooks (README)"     "$ACTUAL_HOOKS"     "$README_HOOKS"     "README.md"
if [ "$README_WORKFLOWS" = "?" ]; then
    echo "  [SKIP] Workflows (README): no explicit count found in README.md"
else
    check_count "Workflows (README)" "$ACTUAL_WORKFLOWS" "$README_WORKFLOWS" "README.md"
fi

echo ""

# ── Cross-check: agent table rows vs agent files ───────────────

echo "Checking agent table consistency..."

# Count rows in the AI Agents table specifically (rows with | `name` | opus | pattern)
README_AGENT_ROWS=$(grep -cE '^\| `[a-z-]+` \| opus \|' "$README" || echo "0")
if [ "$ACTUAL_AGENTS" = "$README_AGENT_ROWS" ]; then
    echo "  [PASS] Agent table rows in README: $README_AGENT_ROWS (matches $ACTUAL_AGENTS files)"
    PASS=$((PASS + 1))
else
    echo "  [FAIL] Agent table rows in README: $README_AGENT_ROWS, but $ACTUAL_AGENTS agent files exist"
    FAIL=$((FAIL + 1))
fi

echo ""
echo "--------------------------------------"
echo "  Results: $PASS passed, $FAIL failed"
echo "--------------------------------------"

if [ "$FAIL" -gt 0 ]; then
    echo ""
    echo "FAILED: $FAIL count mismatch(es) found"
    exit 1
else
    echo ""
    echo "All counts consistent."
    exit 0
fi
