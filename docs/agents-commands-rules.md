# Agents, Commands, Rules & Hooks

This guide explains the four Claude Code native features the framework templates alongside skills.

## Feature Comparison

| Feature | Purpose | Complexity | Invocation | Location |
|---------|---------|-----------|------------|----------|
| **Skills** | Multi-phase workflows with decision trees | High | `/skill-name` | `.claude/skills/` |
| **Commands** | Single-purpose automations | Low | `/command-name` | `.claude/commands/` |
| **Agents** | Specialized AI teammates with restricted tools | Medium | Spawned by Claude | `.claude/agents/` |
| **Rules** | File-pattern-scoped guardrails | Low | Automatic on file match | `.claude/rules/` |
| **Hooks** | Shell scripts triggered by lifecycle events | Low | Automatic on event | `.claude/hooks/` |

## When to Use Each

### Use a **Skill** when:
- The task has multiple phases or conditional branches
- It orchestrates other tools (tracker, CI, deploy)
- It needs to interact with external systems
- Example: `/develop` (8 phases from ticket fetch to PR creation)

### Use a **Command** when:
- The task is a single action with a clear output
- It wraps one or two shell commands with formatting
- It takes less than 30 seconds
- Example: `/quick-test` (run tests on changed files, report results)

### Use an **Agent** when:
- The task benefits from a specialized AI persona
- Tool access should be restricted (e.g., read-only for audits)
- A different model is appropriate (e.g., opus for security analysis)
- Example: `code-reviewer` (read-only analysis with structured report)

### Use a **Rule** when:
- The guidance applies automatically to specific file types
- It's a non-negotiable standard, not a suggestion
- Claude should follow it without being asked
- Example: "Always validate input at API route boundaries"

### Use a **Hook** when:
- A script should run at a specific lifecycle event
- It's a quality gate (pre-commit) or health check (session-start)
- It's a shell command, not AI-driven logic
- Example: secret scanning before every commit

## File Formats

### Agent Definition

```markdown
---
name: agent-name
description: What this agent does
tools: Read, Glob, Grep, Bash
model: opus
---

# Agent Name

Instructions for the agent...

## Process

### Step 1: ...
### Step 2: ...
```

**Fields:**
- `name` — identifier used to reference the agent
- `description` — one-line purpose (used by Claude to decide when to invoke)
- `tools` — comma-separated list of allowed tools
- `model` — which model to use (`sonnet`, `opus`, `haiku`)

### Command Definition

```markdown
---
name: command-name
description: What this command does
allowed-tools: Bash, Read
---

Instructions for the command...

## Steps

1. Do this...
2. Then this...
```

**Fields:**
- `name` — invoked as `/command-name`
- `description` — shown in help
- `allowed-tools` — tools the command can use

### Rule Definition

```markdown
---
patterns:
  - "**/*.ts"
  - "**/*.tsx"
---

# Rule Title

Rules Claude follows when editing matching files...
```

**Fields:**
- `patterns` — glob patterns that trigger this rule when Claude edits matching files

### Hook Script

```bash
#!/bin/bash
# Description of what this hook does

# Your script here...
echo "Running check..."
```

Hooks are bash scripts placed in `.claude/hooks/`. They run at lifecycle events (pre-commit, session-start, session-stop).

## Included Templates

### Agents (12)

> **MCP tools:** In addition to the tools listed below, all agents have access to project-level MCP servers configured in `.mcp.json`. The `architect`, `api-designer`, `documentation-writer`, `performance-optimizer`, and `test-writer` agents actively use Context7 (`resolve-library-id` / `get-library-docs`) to fetch current library documentation before making recommendations.

**Analysis Agents (read-only)**

| Agent | Tools | Model | Purpose |
|-------|-------|-------|---------|
| `architect` | Read, Glob, Grep, Bash | opus | System design, patterns, scalability |
| `code-reviewer` | Read, Glob, Grep, Bash | opus | Reviews diff for bugs, security, performance |
| `security-auditor` | Read, Glob, Grep, Bash | opus | OWASP-categorized security audit |
| `refactor-advisor` | Read, Glob, Grep, Bash | opus | Duplication, complexity, extraction |
| `devops-engineer` | Read, Glob, Grep, Bash | opus | CI/CD, containers, infrastructure |
| `ui-ux-reviewer` | Read, Glob, Grep, Bash | opus | Accessibility, design, responsiveness |
| `performance-optimizer` | Read, Glob, Grep, Bash | opus | Bundle, queries, rendering, caching |
| `api-designer` | Read, Glob, Grep, Bash | opus | Endpoint design, schemas, versioning |
| `database-architect` | Read, Glob, Grep, Bash | opus | Schema, indexes, migrations, queries |

**Implementation Agents (read/write)**

| Agent | Tools | Model | Purpose |
|-------|-------|-------|---------|
| `test-writer` | Read, Glob, Grep, Edit, Write, Bash | opus | Generates tests for changed code |
| `documentation-writer` | Read, Glob, Grep, Edit, Write, Bash | opus | API docs, READMEs, architecture docs |

**Meta Agents (modify framework)**

| Agent | Tools | Model | Purpose |
|-------|-------|-------|---------|
| `framework-improver` | Read, Glob, Grep, Edit, Write, Bash | opus | Updates CLAUDE.md, rules, settings, agents |

### Commands (6)

| Command | Purpose |
|---------|---------|
| `/quick-test` | Run tests on changed files |
| `/lint-fix` | Auto-fix lint issues |
| `/check-types` | Run type checker |
| `/branch-status` | Show diff stats, PR, CI status |
| `/changelog` | Generate changelog from commits |
| `/dep-check` | Check for outdated dependencies |

### Rules (6)

| Rule | Patterns | Key Standards |
|------|----------|---------------|
| `api-routes` | API handlers | Input validation, auth, structured errors |
| `components` | UI components | Accessibility, size limits, state management |
| `tests` | Test files | Factories, descriptive names, reliability |
| `database` | Models, migrations | Parameterized queries, indexes, transactions |
| `config-files` | JSON, YAML, TOML | No secrets, document values |
| `error-handling` | Source files | No silent catches, context, tracking |

### Hooks (5)

| Hook | Event | Purpose |
|------|-------|---------|
| `guardrails.sh` | PreToolUse (Bash) | Blocks dangerous ops: deploys, migrations, force push, destructive deletes |
| `pre-commit.sh` | Pre-commit | Type check, lint, secret scan, file size guard |
| `post-edit-sync.sh` | PostToolUse (Edit/Write) | Flags which docs need updating when files change |
| `session-start.sh` | Session start | Stale branch warning, env check, dep health |
| `session-stop.sh` | Session stop | Audio notification |

## Adding Custom Entries

### Custom Agent

1. Create `.claude/agents/my-agent.md`
2. Add YAML frontmatter with `name`, `description`, `tools`, `model`
3. Write step-by-step instructions

### Custom Command

1. Create `.claude/commands/my-command.md`
2. Add YAML frontmatter with `name`, `description`, `allowed-tools`
3. Write simple step-by-step instructions

### Custom Rule

1. Create `.claude/rules/my-rule.md`
2. Add YAML frontmatter with `patterns` array
3. Write rules as clear directives

### Custom Hook

1. Create `.claude/hooks/my-hook.sh`
2. Make it executable: `chmod +x .claude/hooks/my-hook.sh`
3. The hook runs at the appropriate lifecycle event based on naming convention
