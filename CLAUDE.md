# CLAUDE.md — Claude Code Framework

## Project Overview

This is the **claude-code-framework** — a reusable AI development workflow framework. It provides skills, agents, commands, rules, hooks, and templates that get installed into target projects via `setup.sh` or `setup.ps1`.

**This repo is the framework itself, NOT a target project.** Do not run setup.sh here.

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Skills | Markdown (YAML frontmatter + instructions) |
| Agents | Markdown (YAML frontmatter + multi-step processes) |
| Commands | Markdown (YAML frontmatter + steps) |
| Rules | Markdown (YAML frontmatter with `patterns` + guardrails) |
| Hooks | Bash scripts |
| Setup | Bash (`setup.sh`) + PowerShell (`setup.ps1`) |
| CI/CD templates | GitHub Actions YAML |
| Config | JSON (settings.json, settings.local.json) |

## System Structure

```
claude-code-framework/
├── CLAUDE.md                    # This file (framework instructions)
├── README.md                    # User-facing documentation
├── setup.sh                     # Bash setup wizard
├── setup.ps1                    # PowerShell setup wizard
├── templates/                   # Files copied to target projects
│   ├── CLAUDE.md.template       # Target project's CLAUDE.md
│   ├── settings.json            # User-level permissions (~/.claude/)
│   ├── settings.local.json      # Project-level permissions
│   ├── mcp.json                 # MCP server config (→ .mcp.json)
│   ├── agents/                  # 36 AI agent definitions
│   ├── commands/                # 6 quick command definitions
│   ├── rules/                   # 22 file-pattern guardrails
│   ├── hooks/                   # 6 lifecycle scripts
│   └── statusline/              # Status bar config
├── skills/                      # 21 workflow skills + 1 template
├── workflows/                   # 4 GitHub Actions CI/CD templates
├── memory/                      # Memory system templates
└── docs/                        # Framework documentation
```

## Key Conventions

### Placeholder System

Templates use `{{PLACEHOLDER}}` syntax. `setup.sh` replaces these with project-specific values at install time.

Common placeholders:
- `{{BASE_BRANCH}}` — primary integration branch (main/develop)
- `{{PROJECT_SHORT_NAME}}` — short name for worktree directories
- `{{TEST_COMMAND}}` — project test runner (npm test, pytest, etc.)
- `{{FORMAT_COMMAND}}` — project formatter (prettier, black, etc.)
- `{{TRACKER_FETCH_TICKET}}` — API call to fetch work items
- `{{API_ROUTE_PATTERNS}}` — glob patterns for rule file scoping
- `{{SOURCE_PATTERNS}}` — glob patterns for source files (used by auth-security, data-protection, error-handling rules)
- `{{COMPONENT_PATTERNS}}` — glob patterns for UI components (used by components, design-system rules)
- `{{DATABASE_PATTERNS}}` — glob patterns for DB files
- `{{DEFAULT_MODEL}}` — default Claude model (sonnet)
- `{{DESIGN_COLOR_RULES}}`, `{{DESIGN_COMPONENT_IMPORTS}}`, `{{DESIGN_ICON_USAGE}}`, `{{DESIGN_CARD_PATTERNS}}`, `{{DESIGN_DARK_MODE}}` — design system conventions

### Adding New Skills

Copy `skills/_template/` and edit `SKILL.md`. Use YAML frontmatter with `name` and `description`. See `docs/skill-authoring.md`.

### Adding New Agents

Create a `.md` file in `templates/agents/` with YAML frontmatter: `name`, `description`, `tools`, `model`. See `docs/agents-commands-rules.md`.

### Adding New Commands

Create a `.md` file in `templates/commands/` with YAML frontmatter: `name`, `description`, `allowed-tools`. Keep commands simple (single-purpose).

### Adding New Rules

Create a `.md` file in `templates/rules/` with YAML frontmatter: `patterns` array. Rules are guardrails, not suggestions.

### Adding New Hooks

Create a `.sh` file in `templates/hooks/`. Wire it up in `templates/settings.local.json` under the `hooks` section.

## Setup Script Architecture

Both `setup.sh` and `setup.ps1` follow the same flow:

1. **Prompt** — project type, tracker, CI/CD, base branch, notification system, project short name, design system
2. **Build placeholders** — map project type to commands (test, format, deploy, type-check, etc.)
3. **Copy files** — skills, agents, commands, rules, hooks, settings
4. **Replace placeholders** — sed (bash) or .Replace() (PowerShell) in all copied files
5. **Conditional logic** — skip `components.md` and `design-system.md` rules for backend-only projects or when no design system is configured
6. **Generate extras** — .env template, GitHub Actions workflows, CLAUDE.md

When modifying `setup.sh`, always mirror changes to `setup.ps1`.

## Agent Teams

Spawn pre-configured teams for parallel analysis of the framework:

| Team | Command | Agents |
|------|---------|--------|
| **Review** | `/team review` | code-reviewer, security-auditor, ui-ux-reviewer |
| **Architecture** | `/team architecture` | architect, api-designer, database-architect |
| **Release** | `/team release` | security-auditor, devops-engineer, performance-optimizer |
| **Quality** | `/team quality` | code-reviewer, test-writer, performance-optimizer |
| **Documentation** | `/team documentation` | documentation-writer, api-designer |
| **Design** | `/team design` | ui-ux-reviewer, performance-optimizer, refactor-advisor |
| **Full** | `/team full` | All 12 agents |
| **Custom** | `/team custom a b c` | Any combination |

## Agents Available

| Agent | Purpose | Model |
|-------|---------|-------|
| `architect` | System design, patterns, scalability | opus |
| `code-reviewer` | Bugs, security, performance in diffs (broad sweep) | opus |
| `code-smell-reviewer` | Code smells: long methods, magic numbers, primitive obsession, dead code (cites `code-smells` rule) | opus |
| `dry-reviewer` | Duplication: 3+ repeated logic (cites `dry` rule) | opus |
| `purity-reviewer` | Pure functions, side effects, query/command separation, SRP (cites `purity` rule) | opus |
| `complexity-reviewer` | Function length, cyclomatic complexity, nesting, parameter count (cites `complexity` rule) | opus |
| `security-auditor` | OWASP audit, credentials, dependencies | opus |
| `refactor-advisor` | Duplication, complexity, extraction | opus |
| `devops-engineer` | CI/CD, containers, infrastructure | opus |
| `ui-ux-reviewer` | Accessibility, design, responsiveness | opus |
| `performance-optimizer` | Bundle, queries, caching, memory | opus |
| `api-designer` | Endpoint design, schemas, versioning | opus |
| `database-architect` | Schema, indexes, migrations | opus |
| `test-writer` | Test generation following conventions | opus |
| `documentation-writer` | API docs, READMEs, guides | opus |
| `frontend-architecture-reviewer` | FE structure: composition, state, hooks, data flow, render-perf (cites `frontend-architecture` rule) | opus |
| `architecture-reviewer` | Layering: dependency direction, cross-module reach, circular deps, god modules (cites `architecture-layering` rule) | opus |
| `api-layering-reviewer` | API structure: controller/service/repo separation, validation placement, error contract (cites `api-layering` rule) | opus |
| `crypto-reviewer` | OWASP A02: weak hashes, password storage, RNG, encryption modes/IV, JWT, TLS (cites `crypto` rule) | opus |
| `solid-reviewer` | OCP/LSP/ISP/DIP (cites `solid` rule); SRP is purity-reviewer's domain | opus |
| `concurrency-reviewer` | Race conditions, TOCTOU, async/lock discipline, mutable shared state, background workers (cites `concurrency` rule) | opus |
| `observability-reviewer` | OWASP A09: structured logging, log levels, metrics, tracing, audit logs, alerting (cites `observability` rule) | opus |
| `supply-chain-reviewer` | OWASP A06+A08: lockfiles, pinning, CVE reachability, signing, dev/prod separation, CI integrity (cites `supply-chain` rule) | opus |
| `requirements-clarifier` | Planning specialist: ambiguity hunt, open questions, missing AC | opus |
| `scope-decomposer` | Planning specialist: atomic steps, sequencing, parallelism groups | opus |
| `risk-assessor` | Planning specialist: rollback paths, blast radius, migration risk + mitigations | opus |
| `test-strategy-planner` | Planning specialist: test levels per planned step | opus |
| `scaffold-implementer` | Build phase 1: skeleton (file structure, types, signatures, stubs) | opus |
| `happy-path-implementer` | Build phase 2: core successful flow (defers errors and edges) | opus |
| `edge-case-implementer` | Build phase 3: validation, errors, edge data (binds error-handling, auth-security, data-protection) | opus |
| `refactor-pass-implementer` | Build phase 6 (final): actively applies code-smells/dry/purity/complexity rules | opus |
| `framework-improver` | Self-improvement of .claude/ config | opus |
| `review-coordinator` | Synthesizes parallel reviewer output (dedupe, filter, risk-tier classify, cross-iteration state) | opus |
| `planner-coordinator` | Orchestrates planning specialists, classifies scope, synthesizes one plan | opus |
| `build-coordinator` | Orchestrates build phases sequentially (scaffold → happy-path → edge-case → tests → docs → refactor) | opus |
| `project-setup` | First-time onboarding orchestrator (invoked by `/setup`); 15-layer detection + tradeoff-explained decisions + apply pass | opus |

> `framework-qa` is available in this repo's own `.claude/agents/` but is not a distributable template agent.

## Testing Changes

After modifying the framework, test by running setup in a temp directory:

```bash
mkdir /tmp/test-project && cd /tmp/test-project && git init
bash ~/Developer/claude-code-framework/setup.sh
# Verify: all files copied, placeholders replaced, no {{...}} remaining
grep -r "{{" .claude/ CLAUDE.md | grep -v ".git"
```

## Version Control

- **Branch**: `main`
- Commit messages follow conventional format: `Add`, `Fix`, `Update`, `Remove`
- Co-author attribution for AI-assisted commits

## Self-Improvement (always active)

**Before ending any session where framework files were modified**, spawn the `framework-improver` agent in the background. This keeps CLAUDE.md, README.md, docs, and setup scripts in sync with the actual framework state.

Additionally, run the `framework-qa` agent to validate that all counts and tables are consistent across README, CLAUDE.md template, setup scripts, and docs.

**This is not optional.** If files changed during the session, run the improver and QA agent before wrapping up.

### How the self-improvement system works

| Layer | Mechanism | When | What |
|-------|-----------|------|------|
| **Hook** | `guardrails.sh` (PreToolUse) | Before every Bash command | Blocks dangerous ops (deploys, migrations, force push) |
| **Hook** | `post-edit-sync.sh` (PostToolUse) | After every Edit/Write | Flags which docs need updating based on what changed |
| **Agent** | `framework-improver` | End of every session with changes | Updates CLAUDE.md, rules, settings from project state |
| **Agent** | `framework-qa` | End of every session with changes | Validates all doc counts and tables match actual files |
| **CLAUDE.md** | This instruction | Always | Enforces the above as non-optional behavior |
