#!/bin/bash
# Claude Code Framework — Agent Registry Consistency Test
# Validates that config/agents.json stays in lockstep with:
#   1. The actual agent files in templates/agents/*.md (name + frontmatter description)
#   2. Each agent appears by name in README.md, templates/CLAUDE.md.template,
#      docs/teams.md, and docs/agents-commands-rules.md
#
# run-all.sh picks this up automatically via the check-*.sh pattern.

set -uo pipefail

FRAMEWORK_DIR="$(cd "$(dirname "$0")/.." && pwd)"
REGISTRY="$FRAMEWORK_DIR/config/agents.json"
AGENTS_DIR="$FRAMEWORK_DIR/templates/agents"

PASS=0
FAIL=0
TOTAL=0

echo "======================================"
echo "  Agent Registry Consistency"
echo "======================================"
echo ""

if [ ! -f "$REGISTRY" ]; then
    echo "ERROR: $REGISTRY not found"
    exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
    echo "SKIP: python3 not available — cannot parse config/agents.json"
    exit 0
fi

# Extract agent entries from config/agents.json as NAME|DESCRIPTION lines.
# Read the registry via cat+stdin so bash/Windows-Python path conversion isn't an issue.
# Python on Windows writes stdout in text mode (LF → CRLF); switch to binary so bash
# comparisons don't see a stray \r at the end of each description.
REGISTRY_ENTRIES=$(cat "$REGISTRY" | python3 -c "
import json, sys, os
sys.stdout.reconfigure(newline='\n') if hasattr(sys.stdout, 'reconfigure') else None
data = json.load(sys.stdin)
for a in data.get('agents', []):
    sys.stdout.write(a['name'] + '|' + a['description'] + '\n')
")

# ── Check 1: every registry entry has a matching file with matching frontmatter description ──
echo "Checking registry entries match agent file frontmatter..."
while IFS='|' read -r name description; do
    [ -z "$name" ] && continue
    TOTAL=$((TOTAL + 1))
    agent_file="$AGENTS_DIR/${name}.md"
    if [ ! -f "$agent_file" ]; then
        echo "  [FAIL] $name listed in registry but $agent_file does not exist"
        FAIL=$((FAIL + 1))
        continue
    fi
    frontmatter_desc=$(grep -m1 '^description:' "$agent_file" | sed 's/^description: *//')
    if [ "$frontmatter_desc" = "$description" ]; then
        echo "  [PASS] $name: frontmatter matches registry"
        PASS=$((PASS + 1))
    else
        echo "  [FAIL] $name: frontmatter drift"
        echo "         registry:    $description"
        echo "         frontmatter: $frontmatter_desc"
        FAIL=$((FAIL + 1))
    fi
done <<< "$REGISTRY_ENTRIES"

# ── Check 2: every agent file is represented in the registry ──
echo ""
echo "Checking every agent file has a registry entry..."
for agent_file in "$AGENTS_DIR"/*.md; do
    [ -f "$agent_file" ] || continue
    name=$(basename "$agent_file" .md)
    TOTAL=$((TOTAL + 1))
    if echo "$REGISTRY_ENTRIES" | grep -q "^${name}|"; then
        echo "  [PASS] $name: present in registry"
        PASS=$((PASS + 1))
    else
        echo "  [FAIL] $name: agent file exists but not in config/agents.json"
        FAIL=$((FAIL + 1))
    fi
done

# ── Check 3: every registry agent is named in each downstream doc ──
echo ""
echo "Checking every agent is named in downstream docs..."
DOCS=(
    "$FRAMEWORK_DIR/README.md"
    "$FRAMEWORK_DIR/templates/CLAUDE.md.template"
    "$FRAMEWORK_DIR/docs/teams.md"
    "$FRAMEWORK_DIR/docs/agents-commands-rules.md"
)

while IFS='|' read -r name _description; do
    [ -z "$name" ] && continue
    for doc in "${DOCS[@]}"; do
        TOTAL=$((TOTAL + 1))
        doc_name=$(basename "$doc")
        if grep -q "\`${name}\`\|${name}\.md\| ${name} " "$doc" 2>/dev/null; then
            echo "  [PASS] $name referenced in $doc_name"
            PASS=$((PASS + 1))
        else
            echo "  [FAIL] $name NOT referenced in $doc_name"
            FAIL=$((FAIL + 1))
        fi
    done
done <<< "$REGISTRY_ENTRIES"

# ── Summary ────────────────────────────────────────────────────

echo ""
echo "--------------------------------------"
echo "  Results: $PASS passed, $FAIL failed ($TOTAL total)"
echo "--------------------------------------"

if [ "$FAIL" -gt 0 ]; then
    echo ""
    echo "FAILED: update config/agents.json, the agent frontmatter, or the missing doc."
    exit 1
else
    echo ""
    echo "All agent registry checks passed."
    exit 0
fi
