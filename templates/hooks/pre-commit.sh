#!/bin/bash
# Claude Code Framework — Pre-commit Quality Gate
# Runs before every commit to catch common issues

set -e

echo "Running pre-commit checks..."

# ── Step 1: Type Check ──────────────────────────────────────────
echo "Checking types..."
if ! {{TYPE_CHECK_COMMAND}} 2>/dev/null; then
    echo ""
    echo "ERROR: Type check failed. Fix type errors before committing."
    exit 1
fi

# ── Step 2: Lint Check ──────────────────────────────────────────
echo "Checking lint..."
STAGED_FILES=$(git diff --cached --name-only --diff-filter=ACMR)
if [ -n "$STAGED_FILES" ]; then
    if ! {{FORMAT_VERIFY_COMMAND}} 2>/dev/null; then
        echo ""
        echo "ERROR: Lint check failed. Run '{{FORMAT_COMMAND}}' to fix."
        exit 1
    fi
fi

# ── Step 3: Secret Scan ─────────────────────────────────────────
echo "Scanning for secrets..."
SECRETS_FOUND=0

# Check staged diff for common secret patterns
STAGED_DIFF=$(git diff --cached --unified=0)

# AWS Access Keys
if echo "$STAGED_DIFF" | grep -qE "AKIA[0-9A-Z]{16}"; then
    echo "ERROR: Possible AWS access key detected in staged changes"
    SECRETS_FOUND=1
fi

# Private keys
if echo "$STAGED_DIFF" | grep -qE "-----BEGIN (RSA |EC |DSA )?PRIVATE KEY"; then
    echo "ERROR: Private key detected in staged changes"
    SECRETS_FOUND=1
fi

# Generic secrets (password/secret/token assignment with actual values)
if echo "$STAGED_DIFF" | grep -qiE "(password|secret|token|api_key|apikey)\s*[=:]\s*['\"][^'\"]{8,}['\"]"; then
    # Exclude common false positives (placeholder values, variable references)
    MATCHES=$(echo "$STAGED_DIFF" | grep -iE "(password|secret|token|api_key|apikey)\s*[=:]\s*['\"][^'\"]{8,}['\"]" | grep -ivE "(your-|example|placeholder|changeme|xxx|process\.env|os\.environ|\$\{)" || true)
    if [ -n "$MATCHES" ]; then
        echo "WARNING: Possible hardcoded secret detected in staged changes:"
        echo "$MATCHES"
        SECRETS_FOUND=1
    fi
fi

if [ "$SECRETS_FOUND" -eq 1 ]; then
    echo ""
    echo "ERROR: Potential secrets found in staged changes. Use environment variables instead."
    exit 1
fi

# ── Step 4: Large File Guard ────────────────────────────────────
echo "Checking file sizes..."
MAX_FILE_SIZE=1048576  # 1MB in bytes

for file in $(git diff --cached --name-only --diff-filter=ACMR); do
    if [ -f "$file" ]; then
        FILE_SIZE=$(wc -c < "$file" 2>/dev/null || echo 0)
        if [ "$FILE_SIZE" -gt "$MAX_FILE_SIZE" ]; then
            echo "ERROR: $file is $(( FILE_SIZE / 1024 ))KB — exceeds 1MB limit."
            echo "  Consider using Git LFS for large files."
            exit 1
        fi
    fi
done

echo "All pre-commit checks passed."
