#!/bin/bash
# Claude Code Framework — Placeholder Validation
# Ensures every {{PLACEHOLDER}} in templates/skills has a replacement in BOTH
# setup.sh and setup.ps1 (parity enforcement — see .claude/rules/setup-scripts.md).
# Exit 0 if all pass, exit 1 if any orphaned placeholders found.

set -euo pipefail

FRAMEWORK_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SETUP_SH="$FRAMEWORK_DIR/setup.sh"
SETUP_PS1="$FRAMEWORK_DIR/setup.ps1"
PLACEHOLDERS_JSON="$FRAMEWORK_DIR/config/placeholders.json"

# Pre-collect placeholder names defined in config/placeholders.json (one per line).
# A placeholder listed here counts as "present" for both setup.sh and setup.ps1
# since both scripts consume the JSON as their source of truth.
JSON_NAMES=""
if [ -f "$PLACEHOLDERS_JSON" ] && command -v python3 >/dev/null 2>&1; then
    JSON_NAMES=$(cat "$PLACEHOLDERS_JSON" | python3 -c "
import json, sys
data = json.load(sys.stdin)
for group in ('placeholders', 'claude_md_only'):
    for p in data.get(group, []):
        sys.stdout.write(p['name'] + '\n')
" 2>/dev/null)
fi

PASS=0
FAIL=0
WARNINGS=0

# Placeholders with friendly defaults in setup.sh/ps1 AND also filled by /improve on first run.
# They resolve to placeholder-aware instructional text at setup, then get replaced with real
# content by /improve. We still expect both scripts to reference them.
DEFERRED_PLACEHOLDERS=()

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
    for deferred in ${DEFERRED_PLACEHOLDERS[@]+"${DEFERRED_PLACEHOLDERS[@]}"}; do
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
    for meta in ${META_PLACEHOLDERS[@]+"${META_PLACEHOLDERS[@]}"}; do
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

    # Check both setup.sh AND setup.ps1 for a replacement (parity enforcement).
    # config/placeholders.json is a shared source of truth — if a placeholder
    # is defined there, it counts as present for both scripts (they consume the JSON).
    IN_SH=false
    IN_PS1=false
    IN_JSON=false
    grep -q "{{${placeholder}}}" "$SETUP_SH" 2>/dev/null && IN_SH=true
    [ -f "$SETUP_PS1" ] && grep -q "{{${placeholder}}}" "$SETUP_PS1" 2>/dev/null && IN_PS1=true
    if [ -n "$JSON_NAMES" ] && echo "$JSON_NAMES" | grep -qx "$placeholder"; then
        IN_JSON=true
        IN_SH=true   # JSON-backed — script consumes it
        IN_PS1=true
    fi

    if [ "$IN_SH" = true ] && [ "$IN_PS1" = true ]; then
        if [ "$IN_JSON" = true ]; then
            echo "  [PASS] {{$placeholder}} (config/placeholders.json)"
        else
            echo "  [PASS] {{$placeholder}} (sh + ps1)"
        fi
        PASS=$((PASS + 1))
    elif [ "$IN_SH" = true ] && [ "$IN_PS1" = false ]; then
        echo "  [FAIL] {{$placeholder}} — in setup.sh but missing from setup.ps1"
        FAIL=$((FAIL + 1))
    elif [ "$IN_SH" = false ] && [ "$IN_PS1" = true ]; then
        echo "  [FAIL] {{$placeholder}} — in setup.ps1 but missing from setup.sh"
        FAIL=$((FAIL + 1))
    else
        echo "  [FAIL] {{$placeholder}} — not found in setup.sh or setup.ps1"
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
