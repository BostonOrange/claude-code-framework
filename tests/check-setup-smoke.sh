#!/bin/bash
# Claude Code Framework — Setup Smoke Tests
# Exercises setup.sh in throwaway target projects with an isolated HOME.

set -euo pipefail

FRAMEWORK_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TMP_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/ccf-setup-smoke.XXXXXX")
PASS=0
FAIL=0

cleanup() {
    rm -rf "$TMP_ROOT"
}
trap cleanup EXIT

echo "======================================"
echo "  Setup Smoke Tests"
echo "======================================"
echo ""

pass() {
    echo "  [PASS] $1"
    PASS=$((PASS + 1))
}

fail() {
    echo "  [FAIL] $1"
    FAIL=$((FAIL + 1))
}

assert_file_exists() {
    local path="$1"
    local label="$2"
    if [ -e "$path" ]; then
        pass "$label"
    else
        fail "$label"
    fi
}

assert_file_absent() {
    local path="$1"
    local label="$2"
    if [ ! -e "$path" ]; then
        pass "$label"
    else
        fail "$label"
    fi
}

assert_contains() {
    local file="$1"
    local pattern="$2"
    local label="$3"
    if grep -q "$pattern" "$file" 2>/dev/null; then
        pass "$label"
    else
        fail "$label"
    fi
}

assert_no_traceback() {
    local output="$1"
    local label="$2"
    if grep -q "Traceback" "$output"; then
        fail "$label"
        sed -n '1,80p' "$output"
    else
        pass "$label"
    fi
}

assert_no_unreplaced_placeholders() {
    local target="$1"
    local label="$2"
    local remaining

    remaining=$(grep -R "{{[A-Z_][A-Z_]*}}" "$target/.claude" "$target/CLAUDE.md" "$target/.mcp.json" 2>/dev/null \
        | grep -v ".claude/agents/framework-improver.md" \
        | grep -v ".claude/skills/improve/SKILL.md" \
        || true)

    if [ -z "$remaining" ]; then
        pass "$label"
    else
        fail "$label"
        echo "$remaining" | sed -n '1,20p'
    fi
}

assert_no_placeholders_in_tree() {
    local target="$1"
    local label="$2"
    local remaining

    remaining=$(grep -R "{{[A-Z_][A-Z_]*}}" "$target" \
        --exclude-dir ".git" \
        --exclude-dir "node_modules" \
        --exclude-dir ".next" \
        2>/dev/null \
        | grep -v ".claude/agents/framework-improver.md" \
        | grep -v ".claude/skills/improve/SKILL.md" \
        || true)

    if [ -z "$remaining" ]; then
        pass "$label"
    else
        fail "$label"
        echo "$remaining" | sed -n '1,20p'
    fi
}

run_setup_case() {
    local name="$1"
    local input="$2"
    local target="$TMP_ROOT/$name"
    local home="$TMP_ROOT/home-$name"
    local output="$TMP_ROOT/$name.out"

    mkdir -p "$target" "$home"
    if (cd "$target" && printf '%s' "$input" | HOME="$home" bash "$FRAMEWORK_DIR/setup.sh" >"$output" 2>&1); then
        pass "$name setup exits 0"
    else
        fail "$name setup exits 0"
        sed -n '1,120p' "$output"
        return
    fi

    assert_no_traceback "$output" "$name has no Python traceback"
    assert_file_exists "$target/.claude/skills/develop/SKILL.md" "$name installs skills"
    assert_file_exists "$target/.claude/agents/code-reviewer.md" "$name installs agents"
    assert_file_exists "$target/.claude/hooks/guardrails.sh" "$name installs hooks"
    assert_file_exists "$target/.claude/settings.local.json" "$name installs project settings"
    assert_file_exists "$target/.mcp.json" "$name installs MCP config"
    assert_file_exists "$target/CLAUDE.md" "$name creates CLAUDE.md"
    assert_file_exists "$home/.claude/settings.json" "$name isolates user settings under test HOME"
    assert_no_unreplaced_placeholders "$target" "$name has no operational placeholders"
}

echo "Node.js target, no tracker, no CI, no design system..."
run_setup_case "node-none" $'2\n5\n4\nmain\n4\nsample\n4\n'
assert_file_absent "$TMP_ROOT/node-none/.claude/rules/design-system.md" "node-none skips design-system rule"
assert_contains "$TMP_ROOT/node-none/CLAUDE.md" "No design system configured" "node-none documents no design system"

echo ""
echo "Python target..."
run_setup_case "python-none" $'3\n5\n4\nmain\n4\nsample\n'
assert_file_absent "$TMP_ROOT/python-none/.claude/rules/components.md" "python-none skips components rule"
assert_file_absent "$TMP_ROOT/python-none/.claude/rules/design-system.md" "python-none skips design-system rule"
assert_contains "$TMP_ROOT/python-none/CLAUDE.md" "N/A .* backend project" "python-none documents backend design status"

echo ""
echo "React target with GitHub Actions and shadcn/ui..."
run_setup_case "react-gh-shadcn" $'6\n5\n1\nmain\n4\nsample\n2\n'
assert_file_exists "$TMP_ROOT/react-gh-shadcn/.github/workflows/factory-validate.yml" "react-gh-shadcn installs GitHub workflows"
WORKFLOW_COUNT=$(find "$TMP_ROOT/react-gh-shadcn/.github/workflows" -maxdepth 1 -name "*.yml" -type f | wc -l | tr -d ' ')
if [ "$WORKFLOW_COUNT" = "4" ]; then
    pass "react-gh-shadcn installs 4 workflow files"
else
    fail "react-gh-shadcn installs 4 workflow files (found $WORKFLOW_COUNT)"
fi
assert_file_exists "$TMP_ROOT/react-gh-shadcn/.claude/rules/design-system.md" "react-gh-shadcn keeps design-system rule"
assert_contains "$TMP_ROOT/react-gh-shadcn/CLAUDE.md" "Use CSS variable-based colors" "react-gh-shadcn documents shadcn color rules"

echo ""
echo "Internal Next.js business app preset..."
run_setup_case "internal-app-vercel" $'7\n2\n3\n2\n5\n1\nmain\n4\nsample\n'
assert_file_exists "$TMP_ROOT/internal-app-vercel/package.json" "internal-app installs package.json"
assert_file_exists "$TMP_ROOT/internal-app-vercel/prisma/schema.prisma" "internal-app installs Prisma schema"
assert_file_exists "$TMP_ROOT/internal-app-vercel/src/lib/blob/client.ts" "internal-app installs blob boundary"
assert_file_exists "$TMP_ROOT/internal-app-vercel/src/lib/auth/session.ts" "internal-app installs auth/session files"
assert_file_exists "$TMP_ROOT/internal-app-vercel/src/app/api/health/route.ts" "internal-app installs Next.js API route"
assert_file_exists "$TMP_ROOT/internal-app-vercel/.env.example" "internal-app creates .env.example"
assert_file_exists "$TMP_ROOT/internal-app-vercel/docs/setup.md" "internal-app creates setup docs"
assert_file_exists "$TMP_ROOT/internal-app-vercel/.claude/internal-app.json" "internal-app stores setup choices"
assert_file_absent "$TMP_ROOT/internal-app-vercel/node_modules" "internal-app excludes node_modules"
assert_file_absent "$TMP_ROOT/internal-app-vercel/.next" "internal-app excludes .next"
assert_file_absent "$TMP_ROOT/internal-app-vercel/.env.local" "internal-app excludes .env.local"
assert_file_absent "$TMP_ROOT/internal-app-vercel/src/generated/prisma" "internal-app excludes generated Prisma client"
assert_file_absent "$TMP_ROOT/internal-app-vercel/tsconfig.tsbuildinfo" "internal-app excludes tsbuildinfo"
assert_contains "$TMP_ROOT/internal-app-vercel/.env.example" "Vercel" "internal-app .env.example contains Vercel notes"
assert_contains "$TMP_ROOT/internal-app-vercel/.env.example" "Azure Container Apps" "internal-app .env.example contains Azure notes"
assert_contains "$TMP_ROOT/internal-app-vercel/docs/setup.md" "do not fork it into hosting-specific stacks" "internal-app setup docs preserve one stack"
assert_contains "$TMP_ROOT/internal-app-vercel/package.json" "prisma generate && tsc --noEmit" "internal-app typecheck can generate Prisma after install"
assert_no_placeholders_in_tree "$TMP_ROOT/internal-app-vercel" "internal-app tree has no setup placeholders"

echo ""
echo "Dry-run branch rename safety..."
DRY_TARGET="$TMP_ROOT/dry-run-target"
DRY_HOME="$TMP_ROOT/home-dry-run"
DRY_OUTPUT="$TMP_ROOT/dry-run.out"
mkdir -p "$DRY_TARGET" "$DRY_HOME"
git init -b old "$DRY_TARGET" >/dev/null 2>&1
(
    cd "$DRY_TARGET"
    git config user.email "setup-smoke@example.com"
    git config user.name "Setup Smoke"
    printf 'setup smoke\n' > README.md
    git add README.md
    git commit -m "Initial commit" >/dev/null 2>&1
)

if (cd "$DRY_TARGET" && printf '9\n5\n4\nnew\ny\n4\nsample\n' | HOME="$DRY_HOME" bash "$FRAMEWORK_DIR/setup.sh" --dry-run >"$DRY_OUTPUT" 2>&1); then
    pass "dry-run setup exits 0"
else
    fail "dry-run setup exits 0"
    sed -n '1,120p' "$DRY_OUTPUT"
fi

DRY_BRANCH=$(git -C "$DRY_TARGET" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
if [ "$DRY_BRANCH" = "old" ]; then
    pass "dry-run does not rename branch"
else
    fail "dry-run does not rename branch (found $DRY_BRANCH)"
fi
assert_file_absent "$DRY_TARGET/.claude" "dry-run does not create .claude"
assert_file_absent "$DRY_TARGET/CLAUDE.md" "dry-run does not create CLAUDE.md"
assert_contains "$DRY_OUTPUT" "Would rename local branch 'old' to 'new'" "dry-run reports branch rename preview"
DRY_STATUS=$(git -C "$DRY_TARGET" status --short)
if [ -z "$DRY_STATUS" ]; then
    pass "dry-run leaves git status clean"
else
    fail "dry-run leaves git status clean"
    echo "$DRY_STATUS"
fi

echo ""
echo "--------------------------------------"
echo "  Results: $PASS passed, $FAIL failed"
echo "--------------------------------------"

if [ "$FAIL" -gt 0 ]; then
    echo ""
    echo "FAILED: $FAIL setup smoke check(s) failed"
    exit 1
else
    echo ""
    echo "All setup smoke tests passed."
    exit 0
fi
