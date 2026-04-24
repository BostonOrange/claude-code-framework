#!/bin/bash
# Claude Code Framework — Pre-commit Quality Gate
# Runs before every commit. Installed at .git/hooks/pre-commit by setup.sh/ps1.
#
# Checks (in order, any failure aborts the commit):
#   1. Type check  — only if {{TYPE_CHECK_COMMAND}} is configured (not a comment)
#   2. Lint check  — only if {{FORMAT_VERIFY_COMMAND}} is configured
#   3. Secret scan — always runs (AWS keys, private keys, generic secrets)
#   4. Large file  — always runs (>1MB warning)

set -e

# Guard against unreplaced placeholders
if [[ "{{TYPE_CHECK_COMMAND}}" == "{{TYPE_CHECK_COMMAND}}" ]]; then
    echo "ERROR: pre-commit hook has unreplaced placeholders. Re-run setup.sh."
    exit 1
fi

# A command value is "configured" if it is non-empty AND does not start with a comment (#).
# Generic project types set the placeholder to "# Configure your X command" as a no-op sentinel.
is_configured() {
    local cmd="$1"
    [ -n "$cmd" ] && [[ "$cmd" != \#* ]]
}

echo "Running pre-commit checks..."

# ── Step 1: Type Check (optional) ───────────────────────────────
TYPE_CHECK_CMD="{{TYPE_CHECK_COMMAND}}"
if is_configured "$TYPE_CHECK_CMD"; then
    echo "Checking types..."
    if ! eval "$TYPE_CHECK_CMD" 2>/dev/null; then
        echo ""
        echo "ERROR: Type check failed. Fix type errors before committing."
        exit 1
    fi
fi

# ── Step 2: Lint Check (optional) ───────────────────────────────
FORMAT_VERIFY_CMD="{{FORMAT_VERIFY_COMMAND}}"
STAGED_FILES=$(git diff --cached --name-only --diff-filter=ACMR)
if is_configured "$FORMAT_VERIFY_CMD" && [ -n "$STAGED_FILES" ]; then
    echo "Checking lint..."
    if ! eval "$FORMAT_VERIFY_CMD" 2>/dev/null; then
        echo ""
        echo "ERROR: Lint check failed. Run '{{FORMAT_COMMAND}}' to fix."
        exit 1
    fi
fi

# ── Step 3: Secret Scan (always) ────────────────────────────────
echo "Scanning for secrets..."
SECRETS_FOUND=0

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

# Generic secrets (password/secret/token assignment with literal values)
if echo "$STAGED_DIFF" | grep -qiE "(password|secret|token|api_key|apikey)\s*[=:]\s*['\"][^'\"]{8,}['\"]"; then
    MATCHES=$(echo "$STAGED_DIFF" | grep -iE "(password|secret|token|api_key|apikey)\s*[=:]\s*['\"][^'\"]{8,}['\"]" | grep -ivE "(your-|example|placeholder|changeme|xxx|process\.env|os\.environ|\\\$\{)" || true)
    if [ -n "$MATCHES" ]; then
        echo "WARNING: Possible hardcoded secret detected:"
        echo "$MATCHES"
        SECRETS_FOUND=1
    fi
fi

if [ "$SECRETS_FOUND" -eq 1 ]; then
    echo ""
    echo "ERROR: Potential secrets in staged changes. Use environment variables instead."
    echo "If this is a false positive, bypass with: git commit --no-verify"
    exit 1
fi

# ── Step 4: Large File Guard (always) ───────────────────────────
MAX_FILE_SIZE=1048576  # 1MB
for file in $STAGED_FILES; do
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
