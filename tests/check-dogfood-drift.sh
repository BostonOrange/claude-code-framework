#!/bin/bash
# Claude Code Framework — Dogfood Drift Policy
# Compares this repo's own .claude/ config with distributable templates/skills
# and fails if drift is not listed in config/dogfood-drift-allowlist.txt.

set -euo pipefail

FRAMEWORK_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ALLOWLIST="$FRAMEWORK_DIR/config/dogfood-drift-allowlist.txt"
TMP_DIR=$(mktemp -d "${TMPDIR:-/tmp}/ccf-dogfood-drift.XXXXXX")
trap 'rm -rf "$TMP_DIR"' EXIT

ACTUAL="$TMP_DIR/actual.txt"
EXPECTED="$TMP_DIR/expected.txt"
UNEXPECTED="$TMP_DIR/unexpected.txt"
STALE="$TMP_DIR/stale.txt"

echo "======================================"
echo "  Dogfood Drift Policy"
echo "======================================"
echo ""

if [ ! -f "$ALLOWLIST" ]; then
    echo "ERROR: Missing allowlist: $ALLOWLIST"
    exit 1
fi

{
    diff -qr "$FRAMEWORK_DIR/.claude/agents" "$FRAMEWORK_DIR/templates/agents" || true
    diff -qr "$FRAMEWORK_DIR/.claude/hooks" "$FRAMEWORK_DIR/templates/hooks" || true
    diff -qr "$FRAMEWORK_DIR/.claude/skills" "$FRAMEWORK_DIR/skills" || true
    diff -q "$FRAMEWORK_DIR/.claude/settings.local.json" "$FRAMEWORK_DIR/templates/settings.local.json" || true
    diff -qr "$FRAMEWORK_DIR/.claude/statusline" "$FRAMEWORK_DIR/templates/statusline" || true
} | sed "s|$FRAMEWORK_DIR/||g" | sort > "$ACTUAL"

grep -vE '^\s*(#|$)' "$ALLOWLIST" | sort > "$EXPECTED"

comm -23 "$ACTUAL" "$EXPECTED" > "$UNEXPECTED"
comm -13 "$ACTUAL" "$EXPECTED" > "$STALE"

ACTUAL_COUNT=$(wc -l < "$ACTUAL" | tr -d ' ')
UNEXPECTED_COUNT=$(wc -l < "$UNEXPECTED" | tr -d ' ')
STALE_COUNT=$(wc -l < "$STALE" | tr -d ' ')

echo "Actual drift entries:     $ACTUAL_COUNT"
echo "Unexpected drift entries: $UNEXPECTED_COUNT"
echo "Stale allowlist entries:  $STALE_COUNT"
echo ""

if [ "$UNEXPECTED_COUNT" -gt 0 ]; then
    echo "Unexpected .claude/template drift:"
    sed 's/^/  /' "$UNEXPECTED"
    echo ""
fi

if [ "$STALE_COUNT" -gt 0 ]; then
    echo "Stale allowlist entries no longer present:"
    sed 's/^/  /' "$STALE"
    echo ""
fi

if [ "$UNEXPECTED_COUNT" -gt 0 ] || [ "$STALE_COUNT" -gt 0 ]; then
    echo "FAILED: Update $ALLOWLIST intentionally, or sync the drifting files."
    exit 1
fi

echo "All dogfood drift is explicitly allowlisted."
