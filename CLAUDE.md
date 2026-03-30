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
│   ├── agents/                  # 12 AI agent definitions
│   ├── commands/                # 6 quick command definitions
│   ├── rules/                   # 6 file-pattern guardrails
│   ├── hooks/                   # 5 lifecycle scripts
│   └── statusline/              # Status bar config
├── skills/                      # 16 workflow skills + 1 template
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

1. **Prompt** — project type, tracker, CI/CD, base branch, notification system
2. **Build placeholders** — map project type to commands (test, format, deploy, type-check, etc.)
3. **Copy files** — skills, agents, commands, rules, hooks, settings
4. **Replace placeholders** — sed (bash) or .Replace() (PowerShell) in all copied files
5. **Conditional logic** — skip `components.md` rule for backend-only projects
6. **Generate extras** — .env template, GitHub Actions workflows, CLAUDE.md

When modifying `setup.sh`, always mirror changes to `setup.ps1`.

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

## Self-Improvement

This framework has a self-improvement system. When installed in a project:
- `framework-improver` agent auto-runs after every dev cycle
- `post-edit-sync.sh` hook flags docs needing updates after file edits
- `guardrails.sh` hook blocks dangerous operations before execution
- `/improve` skill scans the project and evolves `.claude/` configuration
- CLAUDE.md instructs Claude to run the improver before ending any session with changes
