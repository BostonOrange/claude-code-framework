#!/bin/bash
# Claude Code Framework — Global install-framework skill sanity checks
set -euo pipefail

FRAMEWORK_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SKILL="$FRAMEWORK_DIR/global-skills/install-framework/SKILL.md"
PASS=0
FAIL=0

check() {
    local label="$1"; shift
    if "$@" >/dev/null 2>&1; then
        echo "  [PASS] $label"; PASS=$((PASS + 1))
    else
        echo "  [FAIL] $label"; FAIL=$((FAIL + 1))
    fi
}

echo "======================================"
echo "  Global Skill Sanity Checks"
echo "======================================"
echo ""

check "SKILL.md exists" test -f "$SKILL"
check "frontmatter declares name: install-framework" grep -q "^name: install-framework$" "$SKILL"
check "frontmatter has a description" grep -q "^description:" "$SKILL"
check "references the GitHub remote" grep -q "github.com/BostonOrange/claude-code-framework" "$SKILL"
check "passes --non-interactive to setup.sh" grep -q -- "--non-interactive" "$SKILL"
check "passes -NonInteractive to setup.ps1" grep -q -- "-NonInteractive" "$SKILL"

echo ""
echo "--------------------------------------"
echo "  Results: $PASS passed, $FAIL failed"
echo "--------------------------------------"

if [ "$FAIL" -gt 0 ]; then
    echo "FAILED: $FAIL global-skill check(s) failed"
    exit 1
fi
echo "All global-skill checks passed."
exit 0
