#!/bin/bash
# Claude Code Framework — PreToolUse Guardrails
# Catches dangerous Bash operations BEFORE they execute.
# Exit codes: 0 = allow, 1 = soft block (ask user), 2 = hard block (deny).
#
# Claude Code sends tool input as JSON on stdin. See https://code.claude.com/docs/en/hooks

# Source the shared hook library (provides read_tool_input_field)
_LIB="$(dirname "$0")/_lib.sh"
if [ ! -f "$_LIB" ]; then
    echo "GUARDRAILS INACTIVE: _lib.sh not found next to guardrails.sh. Re-run setup.sh."
    exit 1
fi
# shellcheck source=/dev/null
. "$_LIB"

COMMAND=$(read_tool_input_field command)
if [ $? -eq 2 ]; then
    # No JSON parser — soft-block every Bash command so the user sees something is wrong.
    echo "GUARDRAILS INACTIVE: neither 'jq' nor 'python3' is installed."
    echo "  Every Bash command is being soft-blocked until a JSON parser is available."
    echo "  Install jq: macOS 'brew install jq' / Linux 'apt/yum install jq' / Windows via Chocolatey."
    exit 1
fi

# Skip if no command extracted
[ -z "$COMMAND" ] && exit 0

# Normalized form used for destructive-pattern matching. Defeats common bypasses:
#   - Strip quotes:            rm -rf "/etc"  → rm -rf  /etc
#   - Collapse slashes:        rm -rf //etc   → rm -rf /etc
#   - Expand ${HOME}/${USER}:  rm -rf ${HOME} → rm -rf $HOME
#   - Expand ~ prefix:         rm -rf ~/.ssh  → rm -rf $HOME/.ssh (for matching only)
# The displayed $COMMAND in block messages stays original so the user sees what they typed.
COMMAND_NORM=$(printf '%s' "$COMMAND" \
    | sed -e 's/["'\'']/ /g' \
          -e 's|///*|/|g' \
          -e 's/\${HOME}/$HOME/g' \
          -e 's/\${USER}/$USER/g')

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

# Force push — match even when git has -c/-C config flags prepended
[[ "$COMMAND" =~ git([[:space:]]+-[cC][[:space:]]+[^[:space:]]+)*[[:space:]]+push.*(--force|-f[[:space:]]|-f$|--force-with-lease) ]] && \
    block "CAUTION: Force push detected. This can overwrite remote history."

# Force push via +refspec (e.g. "git push origin +main" is equivalent to --force for that ref)
[[ "$COMMAND" =~ git([[:space:]]+-[cC][[:space:]]+[^[:space:]]+)*[[:space:]]+push[[:space:]]+[^[:space:]]+[[:space:]]+\+ ]] && \
    block "CAUTION: Force push via +refspec detected. This can overwrite remote history."

[[ "$COMMAND" =~ git\ reset\ --hard ]] && block "CAUTION: Hard reset detected. This will discard uncommitted changes."

[[ "$COMMAND" =~ git\ clean\ -[a-z]*f ]] && block "CAUTION: Git clean with force flag detected. This will delete untracked files."

# ── Destructive file operations (hard block) ────────────────────

# rm -rf against root / home / $HOME / cwd (original catastrophic check)
[[ "$COMMAND_NORM" =~ rm[[:space:]]+-rf[[:space:]]+(\/|~|\$HOME|\.\/?)([[:space:]]|$) ]] && \
    block "BLOCKED: Catastrophic delete detected." 2

# rm with long-form --recursive --force against system/home roots
[[ "$COMMAND_NORM" =~ rm[[:space:]]+(.*--recursive.*--force|.*--force.*--recursive)[[:space:]]+(\/|~|\$HOME) ]] && \
    block "BLOCKED: rm --recursive --force against system/home path." 2

# rm -rf ~/.* (SSH keys, config, history etc.)
[[ "$COMMAND_NORM" =~ rm[[:space:]]+-[a-zA-Z]*[rRfF][a-zA-Z]*[[:space:]]+~/\. ]] && \
    block "BLOCKED: Destructive rm against home dotfile/directory (e.g., ~/.ssh)." 2

# rm -rf against common system directories
[[ "$COMMAND_NORM" =~ rm[[:space:]]+-[a-zA-Z]*[rRfF][a-zA-Z]*[[:space:]]+/(etc|usr|var|bin|sbin|lib|boot|root|home|Users|opt|System)([[:space:]/]|$) ]] && \
    block "BLOCKED: Destructive rm against system directory." 2

# rm -rf against a system/home target as 2nd positional arg (e.g. "rm -rf /tmp /etc")
[[ "$COMMAND_NORM" =~ rm[[:space:]]+-[a-zA-Z]*[rRfF][a-zA-Z]*[[:space:]]+[^[:space:]]+[[:space:]]+(\/|~|\$HOME|/(etc|usr|var|bin|sbin|lib|boot|root|home|Users|opt|System))([[:space:]/]|$) ]] && \
    block "BLOCKED: Destructive rm against system/home path (multi-arg)." 2

# rm -rf * — wildcard against cwd (realistic footgun, catches "cd /etc && rm -rf *")
[[ "$COMMAND_NORM" =~ rm[[:space:]]+-[a-zA-Z]*[rRfF][a-zA-Z]*[[:space:]]+\*([[:space:]]|$) ]] && \
    block "CAUTION: rm -rf * against current directory — confirm you're not in a parent dir."

# rm -rf .* — wildcard that includes .. (parent traversal)
[[ "$COMMAND_NORM" =~ rm[[:space:]]+-[a-zA-Z]*[rRfF][a-zA-Z]*[[:space:]]+\.\*([[:space:]]|$) ]] && \
    block "BLOCKED: rm -rf .* — matches ../.. and traverses to parent." 2

# find ... -delete against absolute/home paths (split into two checks to avoid regex char-class parsing issues)
if [[ "$COMMAND" =~ find[[:space:]]+(\/|~|\$HOME) ]] && [[ "$COMMAND" =~ -delete ]]; then
    block "BLOCKED: find ... -delete against system/home path." 2
fi

# dd to raw disk devices
[[ "$COMMAND" =~ dd[[:space:]]+.*of=/dev/(sd|nvme|hd|disk|vd) ]] && \
    block "BLOCKED: dd to raw disk device detected." 2

# mkfs against mounted/system filesystems
[[ "$COMMAND" =~ mkfs\.?[a-z0-9]*[[:space:]]+/dev/(sd|nvme|hd|disk) ]] && \
    block "BLOCKED: mkfs against disk device detected." 2

# chmod -R 777 against system/home (bad practice + security risk)
[[ "$COMMAND" =~ chmod[[:space:]]+-R[[:space:]]+[0-7]{3,4}[[:space:]]+(\/|~|\$HOME)([[:space:]/]|$) ]] && \
    block "CAUTION: Recursive chmod against system/home path."

# ── Docker registry push (soft block — ask user) ────────────────

# Allow pushes to localhost/private dev registries. Only specific local hostnames
# are whitelisted — do NOT accept arbitrary "host:port/" patterns (would allow
# docker push attacker.com:443/image to bypass the guard).
if [[ "$COMMAND" =~ docker\ push ]]; then
    if [[ ! "$COMMAND" =~ docker\ push[[:space:]]+(localhost|127\.0\.0\.1|0\.0\.0\.0|registry\.local)(:[0-9]+)?/ ]] && \
       [[ ! "$COMMAND" =~ docker\ push[[:space:]]+[a-z0-9-]+\.local(:[0-9]+)?/ ]]; then
        block "CAUTION: Docker registry push detected."
    fi
fi

# All clear
exit 0
