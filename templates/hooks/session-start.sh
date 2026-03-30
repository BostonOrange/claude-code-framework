#!/bin/bash
# Claude Code Framework — Session Start Health Check
# Runs at session start for informational warnings

# ── Stale Branch Warning ────────────────────────────────────────
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
if [ -n "$CURRENT_BRANCH" ] && [ "$CURRENT_BRANCH" != "{{BASE_BRANCH}}" ]; then
    # Fetch latest (silently)
    git fetch origin {{BASE_BRANCH}} --quiet 2>/dev/null || true

    BEHIND=$(git rev-list --count HEAD..origin/{{BASE_BRANCH}} 2>/dev/null || echo 0)
    if [ "$BEHIND" -gt 10 ]; then
        echo "WARNING: Branch '$CURRENT_BRANCH' is $BEHIND commits behind {{BASE_BRANCH}}. Consider rebasing."
    fi
fi

# ── Environment Check ───────────────────────────────────────────
if [ -f ".env" ]; then
    EMPTY_VARS=$(grep -E "^[A-Z_]+=\s*$" .env 2>/dev/null | head -5)
    PLACEHOLDER_VARS=$(grep -E "(your-|changeme|xxx|placeholder)" .env 2>/dev/null | head -5)
    if [ -n "$EMPTY_VARS" ] || [ -n "$PLACEHOLDER_VARS" ]; then
        echo "WARNING: .env has unconfigured variables. Check .env and fill in real values."
    fi
elif [ -f ".env.example" ]; then
    echo "NOTE: .env file not found. Copy .env.example to .env and configure."
fi

# ── Dependency Health ───────────────────────────────────────────
if [ -f "package.json" ] && [ ! -d "node_modules" ]; then
    echo "NOTE: node_modules not found. Run 'npm install' to install dependencies."
elif [ -f "requirements.txt" ] && ! python3 -c "import pkg_resources; pkg_resources.require(open('requirements.txt').readlines())" 2>/dev/null; then
    echo "NOTE: Python dependencies may be outdated. Run 'pip install -r requirements.txt'."
elif [ -f "go.mod" ] && [ ! -d "vendor" ] && ! go mod verify 2>/dev/null; then
    echo "NOTE: Go modules may need syncing. Run 'go mod download'."
fi
