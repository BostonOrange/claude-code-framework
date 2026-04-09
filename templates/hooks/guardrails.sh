#!/bin/bash
# Claude Code Framework — PreToolUse Guardrails
# Catches dangerous Bash operations BEFORE they execute.
# Exit codes: 0 = allow, 1 = soft block (ask user), 2 = hard block (deny).

COMMAND="$1"

# Skip if no command provided
[ -z "$COMMAND" ] && exit 0

# Helper: print message and exit with given code (default: soft block)
block() { echo "$1"; echo "Command: $COMMAND"; exit "${2:-1}"; }

# ── Destructive deployments (soft block — ask user) ─────────────

# Salesforce deploy (not validate)
if [[ "$COMMAND" =~ sf\ (project\ )?deploy\ (start|quick) ]] && [[ ! "$COMMAND" =~ validate ]]; then
    block "CAUTION: Salesforce deployment detected. This will push code to an org."
fi

# Salesforce org delete
[[ "$COMMAND" =~ sf\ org\ delete ]] && block "CAUTION: Salesforce org deletion detected."

# Vercel production deploy
[[ "$COMMAND" =~ vercel\ (deploy|promote).*--prod ]] && block "CAUTION: Production deployment detected."

# Kubernetes apply/delete
[[ "$COMMAND" =~ kubectl\ (apply|delete|scale) ]] && block "CAUTION: Kubernetes mutation detected."

# Terraform apply/destroy
[[ "$COMMAND" =~ terraform\ (apply|destroy) ]] && block "CAUTION: Terraform state mutation detected."

# ── Database migrations (soft block — ask user) ─────────────────

[[ "$COMMAND" =~ (prisma\ (db\ push|migrate\ deploy)|alembic\ upgrade|knex\ migrate|rake\ db:migrate|flyway\ migrate|sequelize\ db:migrate) ]] && \
    block "CAUTION: Database migration detected. This will modify the database schema."

# ── Git force operations (soft block — ask user) ────────────────

[[ "$COMMAND" =~ git\ push.*(-f|--force) ]] && block "CAUTION: Force push detected. This can overwrite remote history."

[[ "$COMMAND" =~ git\ reset\ --hard ]] && block "CAUTION: Hard reset detected. This will discard uncommitted changes."

[[ "$COMMAND" =~ git\ clean\ -[a-z]*f ]] && block "CAUTION: Git clean with force flag detected. This will delete untracked files."

# ── Destructive file operations (hard block) ────────────────────

[[ "$COMMAND" =~ rm\ -rf[[:space:]]+(\/|~|\$HOME|\.\/?)([[:space:]]|$) ]] && block "BLOCKED: Catastrophic delete detected." 2

# ── Docker registry push (soft block — ask user) ────────────────

[[ "$COMMAND" =~ docker\ push ]] && block "CAUTION: Docker registry push detected."

# All clear
exit 0
