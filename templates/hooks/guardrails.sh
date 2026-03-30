#!/bin/bash
# Claude Code Framework — PreToolUse Guardrails
# Catches dangerous Bash operations BEFORE they execute.
# Returns non-zero exit + message to block the operation and prompt user.

COMMAND="$1"

# Skip if no command provided
[ -z "$COMMAND" ] && exit 0

# ── Destructive deployments (must ask) ───────────────────────────

# Salesforce deploy (not validate)
if echo "$COMMAND" | grep -qE "sf (project )?deploy (start|quick)" && ! echo "$COMMAND" | grep -q "validate"; then
    echo "BLOCKED: Salesforce deployment detected. This will push code to an org."
    echo "Command: $COMMAND"
    echo "If this is intentional, run the command manually."
    exit 1
fi

# Salesforce org delete
if echo "$COMMAND" | grep -qE "sf org delete"; then
    echo "BLOCKED: Salesforce org deletion detected."
    echo "Command: $COMMAND"
    exit 1
fi

# Vercel production deploy
if echo "$COMMAND" | grep -qE "vercel (deploy|promote).*--prod"; then
    echo "BLOCKED: Production deployment detected."
    echo "Command: $COMMAND"
    exit 1
fi

# Kubernetes apply/delete
if echo "$COMMAND" | grep -qE "kubectl (apply|delete|scale)"; then
    echo "BLOCKED: Kubernetes mutation detected."
    echo "Command: $COMMAND"
    exit 1
fi

# Terraform apply/destroy
if echo "$COMMAND" | grep -qE "terraform (apply|destroy)"; then
    echo "BLOCKED: Terraform state mutation detected."
    echo "Command: $COMMAND"
    exit 1
fi

# ── Database migrations (must ask) ───────────────────────────────

if echo "$COMMAND" | grep -qiE "(prisma (db push|migrate deploy)|alembic upgrade|knex migrate|rake db:migrate|flyway migrate|sequelize db:migrate)"; then
    echo "BLOCKED: Database migration detected. This will modify the database schema."
    echo "Command: $COMMAND"
    exit 1
fi

# ── Git force operations (must ask) ──────────────────────────────

if echo "$COMMAND" | grep -qE "git push.*(-f|--force)"; then
    echo "BLOCKED: Force push detected. This can overwrite remote history."
    echo "Command: $COMMAND"
    exit 1
fi

if echo "$COMMAND" | grep -qE "git reset --hard"; then
    echo "BLOCKED: Hard reset detected. This will discard uncommitted changes."
    echo "Command: $COMMAND"
    exit 1
fi

if echo "$COMMAND" | grep -qE "git clean -[a-z]*f"; then
    echo "BLOCKED: Git clean with force flag detected. This will delete untracked files."
    echo "Command: $COMMAND"
    exit 1
fi

# ── Destructive file operations (catastrophic) ───────────────────

if echo "$COMMAND" | grep -qE "rm -rf\s+(/|~|\\\$HOME)"; then
    echo "BLOCKED: Catastrophic delete detected."
    echo "Command: $COMMAND"
    exit 2
fi

# ── Docker registry push (must ask) ──────────────────────────────

if echo "$COMMAND" | grep -qE "docker push"; then
    echo "BLOCKED: Docker registry push detected."
    echo "Command: $COMMAND"
    exit 1
fi

# All clear
exit 0
