#!/bin/bash
# Claude Code Framework — PreToolUse Guardrails
# Catches dangerous Bash operations BEFORE they execute.
# Exit codes: 0 = allow, 1 = soft block (ask user), 2 = hard block (deny).
#
# Claude Code sends tool input as JSON on stdin. Extract tool_input.command
# using jq if available, else python3.

_LIB="$(dirname "$0")/_lib.sh"
if [ ! -f "$_LIB" ]; then
    echo "GUARDRAILS INACTIVE: _lib.sh not found next to guardrails.sh."
    exit 1
fi
# shellcheck source=/dev/null
. "$_LIB"

COMMAND=$(read_tool_input_field command)
if [ $? -eq 2 ]; then
    echo "GUARDRAILS INACTIVE: neither 'jq' nor 'python3' is installed."
    echo "  Install jq or python3 to restore normal guardrail operation."
    exit 1
fi

[ -z "$COMMAND" ] && exit 0

# Normalized form for pattern matching (strips quotes, collapses //, expands ${HOME})
COMMAND_NORM=$(printf '%s' "$COMMAND" \
    | sed -e 's/["'\'']/ /g' \
          -e 's|///*|/|g' \
          -e 's/\${HOME}/$HOME/g' \
          -e 's/\${USER}/$USER/g')

block() { echo "$1"; echo "Command: $COMMAND"; exit "${2:-1}"; }

# ── Destructive deployments (must ask) ───────────────────────────

# Salesforce deploy (not validate)
if echo "$COMMAND" | grep -qE "sf (project )?deploy (start|quick)" && ! echo "$COMMAND" | grep -q "validate"; then
    block "BLOCKED: Salesforce deployment detected. This will push code to an org."
fi

# Salesforce org delete
echo "$COMMAND" | grep -qE "sf org delete" && block "BLOCKED: Salesforce org deletion detected."

# Vercel production deploy
echo "$COMMAND" | grep -qE "vercel (deploy|promote).*--prod" && block "BLOCKED: Production deployment detected."

# Kubernetes apply/delete
echo "$COMMAND" | grep -qE "kubectl (apply|delete|scale)" && block "BLOCKED: Kubernetes mutation detected."

# Terraform apply/destroy
echo "$COMMAND" | grep -qE "terraform (apply|destroy)" && block "BLOCKED: Terraform state mutation detected."

# ── Database migrations (must ask) ───────────────────────────────

echo "$COMMAND" | grep -qiE "(prisma (db push|migrate deploy)|alembic upgrade|knex migrate|rake db:migrate|flyway migrate|sequelize db:migrate)" && \
    block "BLOCKED: Database migration detected. This will modify the database schema."

# ── Git force operations (must ask) ──────────────────────────────

# Force push — match even when git has -c/-C config flags prepended
echo "$COMMAND" | grep -qE "git([[:space:]]+-[cC][[:space:]]+[^[:space:]]+)*[[:space:]]+push.*(--force|-f[[:space:]]|-f$|--force-with-lease)" && \
    block "BLOCKED: Force push detected. This can overwrite remote history."

# Force push via +refspec (e.g. "git push origin +main")
echo "$COMMAND" | grep -qE "git([[:space:]]+-[cC][[:space:]]+[^[:space:]]+)*[[:space:]]+push[[:space:]]+[^[:space:]]+[[:space:]]+\+" && \
    block "BLOCKED: Force push via +refspec detected. This can overwrite remote history."

echo "$COMMAND" | grep -qE "git reset --hard" && \
    block "BLOCKED: Hard reset detected. This will discard uncommitted changes."

echo "$COMMAND" | grep -qE "git clean -[a-z]*f" && \
    block "BLOCKED: Git clean with force flag detected. This will delete untracked files."

# ── Destructive file operations (catastrophic) ───────────────────

# rm -rf /, ~, $HOME, .
echo "$COMMAND_NORM" | grep -qE "rm -rf[[:space:]]+(/|~|\\\$HOME|\.\/?)([[:space:]]|$)" && \
    block "BLOCKED: Catastrophic delete detected." 2

# rm --recursive --force against system/home
echo "$COMMAND_NORM" | grep -qE "rm[[:space:]]+.*(--recursive.*--force|--force.*--recursive)[[:space:]]+(/|~|\\\$HOME)" && \
    block "BLOCKED: rm --recursive --force against system/home path." 2

# rm -rf ~/.* (ssh keys, config, etc.)
echo "$COMMAND_NORM" | grep -qE "rm[[:space:]]+-[a-zA-Z]*[rRfF][a-zA-Z]*[[:space:]]+~/\." && \
    block "BLOCKED: Destructive rm against home dotfile/directory." 2

# rm against common system directories
echo "$COMMAND_NORM" | grep -qE "rm[[:space:]]+-[a-zA-Z]*[rRfF][a-zA-Z]*[[:space:]]+/(etc|usr|var|bin|sbin|lib|boot|root|home|Users|opt|System)([[:space:]/]|$)" && \
    block "BLOCKED: Destructive rm against system directory." 2

# Multi-arg: rm -rf /tmp /etc -- catch dangerous 2nd positional
echo "$COMMAND_NORM" | grep -qE "rm[[:space:]]+-[a-zA-Z]*[rRfF][a-zA-Z]*[[:space:]]+[^[:space:]]+[[:space:]]+(/|~|\\\$HOME|/(etc|usr|var|bin|sbin|lib|boot|root|home|Users|opt|System))([[:space:]/]|$)" && \
    block "BLOCKED: Destructive rm against system/home path (multi-arg)." 2

# rm -rf * (wildcard against cwd, realistic footgun)
echo "$COMMAND_NORM" | grep -qE "rm[[:space:]]+-[a-zA-Z]*[rRfF][a-zA-Z]*[[:space:]]+\*([[:space:]]|$)" && \
    block "BLOCKED: rm -rf * against current directory." 1

# rm -rf .* (matches .., traverses to parent)
echo "$COMMAND_NORM" | grep -qE "rm[[:space:]]+-[a-zA-Z]*[rRfF][a-zA-Z]*[[:space:]]+\.\*([[:space:]]|$)" && \
    block "BLOCKED: rm -rf .* — matches .. and traverses." 2

# find ... -delete against absolute/home paths
if echo "$COMMAND" | grep -qE "find[[:space:]]+(/|~|\\\$HOME)" && echo "$COMMAND" | grep -qE "\-delete"; then
    block "BLOCKED: find ... -delete against system/home path." 2
fi

# dd to raw disk devices
echo "$COMMAND" | grep -qE "dd[[:space:]]+.*of=/dev/(sd|nvme|hd|disk|vd)" && \
    block "BLOCKED: dd to raw disk device detected." 2

# mkfs against disk devices
echo "$COMMAND" | grep -qE "mkfs\.?[a-z0-9]*[[:space:]]+/dev/(sd|nvme|hd|disk)" && \
    block "BLOCKED: mkfs against disk device detected." 2

# ── Docker registry push (must ask) ──────────────────────────────

# Allow pushes to localhost/.local dev registries ONLY — reject generic host:port/
if echo "$COMMAND" | grep -qE "docker push"; then
    if ! echo "$COMMAND" | grep -qE "docker push[[:space:]]+(localhost|127\.0\.0\.1|0\.0\.0\.0|registry\.local)(:[0-9]+)?/" && \
       ! echo "$COMMAND" | grep -qE "docker push[[:space:]]+[a-z0-9-]+\.local(:[0-9]+)?/"; then
        block "BLOCKED: Docker registry push detected."
    fi
fi

exit 0
