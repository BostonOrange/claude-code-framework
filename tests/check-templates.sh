#!/bin/bash
# Claude Code Framework — Template Structure Validation
# Ensures all template files have correct YAML frontmatter and structure
# Exit 0 if all pass, exit 1 if any failures

set -euo pipefail

FRAMEWORK_DIR="$(cd "$(dirname "$0")/.." && pwd)"

PASS=0
FAIL=0

echo "======================================"
echo "  Template Structure Validation"
echo "======================================"
echo ""

# ── Helper: check YAML frontmatter field ───────────────────────

# Extract YAML frontmatter (between --- markers) and check for a field
check_frontmatter_field() {
    local file="$1"
    local field="$2"
    local basename
    basename=$(basename "$file")

    # Check file starts with ---
    if ! head -1 "$file" | grep -q '^---$'; then
        echo "  [FAIL] $basename — missing YAML frontmatter (no opening ---)"
        FAIL=$((FAIL + 1))
        return 1
    fi

    # Extract frontmatter: lines between first --- and second ---
    local frontmatter
    frontmatter=$(sed -n '2,/^---$/p' "$file" | sed '$d')

    if echo "$frontmatter" | grep -q "^${field}:"; then
        return 0
    else
        echo "  [FAIL] $basename — missing required field: $field"
        FAIL=$((FAIL + 1))
        return 1
    fi
}

# ── Agents: name, description, tools, model ───────────────────

echo "Checking agents (templates/agents/*.md)..."
AGENT_COUNT=0
for file in "$FRAMEWORK_DIR/templates/agents"/*.md; do
    [ -f "$file" ] || continue
    AGENT_COUNT=$((AGENT_COUNT + 1))
    basename=$(basename "$file")
    ALL_OK=true

    for field in name description tools model; do
        if ! check_frontmatter_field "$file" "$field"; then
            ALL_OK=false
        fi
    done

    if [ "$ALL_OK" = true ]; then
        echo "  [PASS] $basename (name, description, tools, model)"
        PASS=$((PASS + 1))
    fi
done
echo "  Checked $AGENT_COUNT agent files"
echo ""

# ── Skills: name, description ─────────────────────────────────

echo "Checking skills (skills/*/SKILL.md)..."
SKILL_COUNT=0
for file in "$FRAMEWORK_DIR/skills"/*/SKILL.md; do
    [ -f "$file" ] || continue
    SKILL_COUNT=$((SKILL_COUNT + 1))
    # Get skill directory name for context
    skill_dir=$(basename "$(dirname "$file")")
    basename="${skill_dir}/SKILL.md"
    ALL_OK=true

    for field in name description; do
        if ! check_frontmatter_field "$file" "$field"; then
            ALL_OK=false
        fi
    done

    if [ "$ALL_OK" = true ]; then
        echo "  [PASS] $basename (name, description)"
        PASS=$((PASS + 1))
    fi
done
echo "  Checked $SKILL_COUNT skill files"
echo ""

# ── Rules: patterns ───────────────────────────────────────────

echo "Checking rules (templates/rules/*.md)..."
RULE_COUNT=0
for file in "$FRAMEWORK_DIR/templates/rules"/*.md; do
    [ -f "$file" ] || continue
    RULE_COUNT=$((RULE_COUNT + 1))
    basename=$(basename "$file")

    if check_frontmatter_field "$file" "patterns"; then
        echo "  [PASS] $basename (patterns)"
        PASS=$((PASS + 1))
    fi
done
echo "  Checked $RULE_COUNT rule files"
echo ""

# ── Commands: name, description, allowed-tools ─────────────────

echo "Checking commands (templates/commands/*.md)..."
CMD_COUNT=0
for file in "$FRAMEWORK_DIR/templates/commands"/*.md; do
    [ -f "$file" ] || continue
    CMD_COUNT=$((CMD_COUNT + 1))
    basename=$(basename "$file")
    ALL_OK=true

    for field in name description allowed-tools; do
        if ! check_frontmatter_field "$file" "$field"; then
            ALL_OK=false
        fi
    done

    if [ "$ALL_OK" = true ]; then
        echo "  [PASS] $basename (name, description, allowed-tools)"
        PASS=$((PASS + 1))
    fi
done
echo "  Checked $CMD_COUNT command files"
echo ""

# ── Hooks: shebang ────────────────────────────────────────────

echo "Checking hooks (templates/hooks/*.sh)..."
HOOK_COUNT=0
for file in "$FRAMEWORK_DIR/templates/hooks"/*.sh; do
    [ -f "$file" ] || continue
    HOOK_COUNT=$((HOOK_COUNT + 1))
    basename=$(basename "$file")

    # Check for #!/bin/bash shebang (handle potential \r from Windows)
    if head -1 "$file" | tr -d '\r' | grep -q '^#!/bin/bash'; then
        echo "  [PASS] $basename (#!/bin/bash shebang)"
        PASS=$((PASS + 1))
    else
        echo "  [FAIL] $basename — missing #!/bin/bash shebang"
        echo "         first line: $(head -1 "$file" | cat -v)"
        FAIL=$((FAIL + 1))
    fi
done
echo "  Checked $HOOK_COUNT hook files"
echo ""

echo "--------------------------------------"
echo "  Results: $PASS passed, $FAIL failed"
echo "--------------------------------------"

if [ "$FAIL" -gt 0 ]; then
    echo ""
    echo "FAILED: $FAIL template structure issue(s) found"
    exit 1
else
    echo ""
    echo "All templates structurally valid."
    exit 0
fi
