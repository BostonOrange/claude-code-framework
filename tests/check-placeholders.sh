#!/bin/bash
# Claude Code Framework — Placeholder Validation
# Ensures every {{PLACEHOLDER}} in templates/skills has a replacement in setup.sh
# Exit 0 if all pass, exit 1 if any orphaned placeholders found

set -euo pipefail

FRAMEWORK_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SETUP_SH="$FRAMEWORK_DIR/setup.sh"

PASS=0
FAIL=0
WARNINGS=0

# Deferred placeholders intentionally left for /improve to fill in
DEFERRED_PLACEHOLDERS=(
    "PROJECT_DESCRIPTION"
    "TECH_STACK_TABLE"
    "CODE_STRUCTURE"
    "CODING_STANDARDS"
    "ERROR_HANDLING_PATTERN"
    "TESTING_STRATEGY"
    "INTEGRATIONS"
)

# Meta-reference placeholders used as examples in skill instructions (not real placeholders)
META_PLACEHOLDERS=(
    "PLACEHOLDER"
)

echo "======================================"
echo "  Placeholder Validation"
echo "======================================"
echo ""

# Collect all unique {{...}} placeholders from templates/ and skills/
ALL_PLACEHOLDERS=$(grep -roh '{{[A-Z_]*}}' "$FRAMEWORK_DIR/templates/" "$FRAMEWORK_DIR/skills/" 2>/dev/null \
    | sort -u \
    | sed 's/^{{//;s/}}$//')

if [ -z "$ALL_PLACEHOLDERS" ]; then
    echo "WARNING: No placeholders found. Something may be wrong."
    exit 1
fi

TOTAL=$(echo "$ALL_PLACEHOLDERS" | wc -l | tr -d ' ')
echo "Found $TOTAL unique placeholders across templates/ and skills/"
echo ""

for placeholder in $ALL_PLACEHOLDERS; do
    # Check if this is a deferred placeholder
    IS_DEFERRED=false
    for deferred in "${DEFERRED_PLACEHOLDERS[@]}"; do
        if [ "$placeholder" = "$deferred" ]; then
            IS_DEFERRED=true
            break
        fi
    done

    if [ "$IS_DEFERRED" = true ]; then
        echo "  [SKIP] {{$placeholder}} (deferred — filled by /improve)"
        WARNINGS=$((WARNINGS + 1))
        continue
    fi

    # Check if this is a meta-reference placeholder
    IS_META=false
    for meta in "${META_PLACEHOLDERS[@]}"; do
        if [ "$placeholder" = "$meta" ]; then
            IS_META=true
            break
        fi
    done

    if [ "$IS_META" = true ]; then
        echo "  [SKIP] {{$placeholder}} (meta-reference — used as example in skill docs)"
        WARNINGS=$((WARNINGS + 1))
        continue
    fi

    # Check if setup.sh has a replacement for this placeholder
    # Look for the placeholder string in setup.sh (either in sed commands or python replacement dicts)
    if grep -q "{{${placeholder}}}" "$SETUP_SH" 2>/dev/null; then
        echo "  [PASS] {{$placeholder}}"
        PASS=$((PASS + 1))
    else
        echo "  [FAIL] {{$placeholder}} — not found in setup.sh"
        # Show which files use this placeholder
        FILES=$(grep -rl "{{${placeholder}}}" "$FRAMEWORK_DIR/templates/" "$FRAMEWORK_DIR/skills/" 2>/dev/null | sed "s|$FRAMEWORK_DIR/||g" | head -5)
        for f in $FILES; do
            echo "         used in: $f"
        done
        FAIL=$((FAIL + 1))
    fi
done

echo ""
echo "--------------------------------------"
echo "  Results: $PASS passed, $FAIL failed, $WARNINGS skipped (deferred)"
echo "--------------------------------------"

if [ "$FAIL" -gt 0 ]; then
    echo ""
    echo "FAILED: $FAIL placeholder(s) have no replacement in setup.sh"
    exit 1
else
    echo ""
    echo "All placeholders accounted for."
    exit 0
fi
