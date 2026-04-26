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

## The Agent Registry — `config/agents.json`

The framework maintains a canonical registry of all distributable agents at `config/agents.json`. This is the **source of truth** for every agent description that appears in docs — the short "blurb" in tables, the "description" that matches the agent's frontmatter, the category (analysis / implementation / meta), and the model.

**Why it exists.** Agent descriptions were previously hand-maintained in five places (README, CLAUDE.md.template, docs/teams.md, docs/agents-commands-rules.md, and the agent's own frontmatter) with drift happening on every edit. The registry consolidates the canonical values into one JSON file; the test `tests/check-agent-registry.sh` then enforces that every downstream location matches.

**What the registry enforces (72 checks, run via `bash tests/run-all.sh`):**
1. Every entry in `config/agents.json` has a matching `templates/agents/{name}.md` file.
2. Each entry's `description` field is **byte-identical** to the frontmatter `description` in that file.
3. Every agent file has a registry entry — no orphans allowed.
4. Each agent is referenced by name in all four user-facing docs: `README.md`, `templates/CLAUDE.md.template`, `docs/teams.md`, and `docs/agents-commands-rules.md`.

**Adding or updating an agent:** edit the frontmatter in `templates/agents/{name}.md` AND update the matching entry in `config/agents.json` in the same commit. Run `bash tests/check-agent-registry.sh` to confirm. See `docs/contributing.md` for the full procedure.

## Included Templates

### Agents (12)

> **MCP tools:** In addition to the tools listed below, all agents have access to project-level MCP servers configured in `.mcp.json`. The `architect`, `api-designer`, `documentation-writer`, `performance-optimizer`, and `test-writer` agents actively use Context7 (`resolve-library-id` / `get-library-docs`) to fetch current library documentation before making recommendations.

**Analysis Agents (read-only)**

| Agent | Tools | Model | Purpose |
|-------|-------|-------|---------|
| `architect` | Read, Glob, Grep, Bash | opus | System design, patterns, scalability |
| `code-reviewer` | Read, Glob, Grep, Bash | opus | Reviews diff for bugs, security, performance, design, smells (broad sweep) |
| `code-smell-reviewer` | Read, Glob, Grep, Bash | opus | Code smells specialist — long methods, magic numbers, primitive obsession, dead code (cites `code-smells`) |
| `dry-reviewer` | Read, Glob, Grep, Bash | opus | Duplication specialist — 3+ repeated logic, structural patterns (cites `dry`) |
| `purity-reviewer` | Read, Glob, Grep, Bash | opus | Pure-function specialist — side effects, query/command separation, hidden state, SRP (cites `purity`) |
| `complexity-reviewer` | Read, Glob, Grep, Bash | opus | Complexity specialist — function length, cyclomatic complexity, nesting, params (cites `complexity`) |
| `frontend-architecture-reviewer` | Read, Glob, Grep, Bash | opus | FE structure — composition, state, hooks, data flow, render-perf (cites `frontend-architecture`) |
| `architecture-reviewer` | Read, Glob, Grep, Bash | opus | Layering — dependency direction, cross-module reach, circular deps, god modules (cites `architecture-layering`) |
| `api-layering-reviewer` | Read, Glob, Grep, Bash | opus | API structure — controller/service/repo separation, validation placement, error contract (cites `api-layering`) |
| `crypto-reviewer` | Read, Glob, Grep, Bash | opus | OWASP A02 — weak hashes, password storage, RNG, encryption modes, JWT, TLS, key derivation (cites `crypto`) |
| `solid-reviewer` | Read, Glob, Grep, Bash | opus | OCP/LSP/ISP/DIP (cites `solid`); SRP is `purity-reviewer`'s domain |
| `concurrency-reviewer` | Read, Glob, Grep, Bash | opus | Races, TOCTOU, async/lock discipline, mutable shared state, background workers (cites `concurrency`) |
| `observability-reviewer` | Read, Glob, Grep, Bash | opus | OWASP A09 — structured logging, metrics, tracing, audit logs, alerting (cites `observability`) |
| `supply-chain-reviewer` | Read, Glob, Grep, Bash | opus | OWASP A06+A08 — lockfiles, pinning, CVE reachability, signing, CI pipeline integrity (cites `supply-chain`) |
| `security-auditor` | Read, Glob, Grep, Bash | opus | OWASP-categorized security audit; cites `secrets-management` for storage findings |
| `refactor-advisor` | Read, Glob, Grep, Bash | opus | Cross-cutting refactor opportunities (broader than `dry-reviewer`) |
| `devops-engineer` | Read, Glob, Grep, Bash | opus | CI/CD, containers, infrastructure |
| `ui-ux-reviewer` | Read, Glob, Grep, Bash | opus | Accessibility, design, responsiveness |
| `performance-optimizer` | Read, Glob, Grep, Bash | opus | Bundle, queries, rendering, caching |
| `api-designer` | Read, Glob, Grep, Bash | opus | Endpoint design, schemas, versioning |
| `database-architect` | Read, Glob, Grep, Bash | opus | Schema, indexes, migrations, queries |

**Planning Agents (read-only — used by `/plan`)**

| Agent | Tools | Model | Purpose |
|-------|-------|-------|---------|
| `requirements-clarifier` | Read, Glob, Grep, Bash | opus | Hunts ambiguity in story before planning starts |
| `scope-decomposer` | Read, Glob, Grep, Bash | opus | Breaks story into atomic, sequenced steps with parallelism groups |
| `risk-assessor` | Read, Glob, Grep, Bash | opus | Identifies rollback paths, blast radius, breaking-change & migration risk |
| `test-strategy-planner` | Read, Glob, Grep, Bash | opus | Decides test levels per planned step |

**Implementation Agents (read/write)**

| Agent | Tools | Model | Purpose |
|-------|-------|-------|---------|
| `scaffold-implementer` | Read, Glob, Grep, Edit, Write, Bash | opus | Build phase 1 — file structure, types, signatures, stubs (no logic) |
| `happy-path-implementer` | Read, Glob, Grep, Edit, Write, Bash | opus | Build phase 2 — core successful flow logic |
| `edge-case-implementer` | Read, Glob, Grep, Edit, Write, Bash | opus | Build phase 3 — validation, errors, edge data |
| `refactor-pass-implementer` | Read, Glob, Grep, Edit, Write, Bash | opus | Build phase 6 (final) — apply code-quality rules actively |
| `test-writer` | Read, Glob, Grep, Edit, Write, Bash | opus | Generates tests for changed code (build phase 4) |
| `documentation-writer` | Read, Glob, Grep, Edit, Write, Bash | opus | API docs, READMEs, architecture docs (build phase 5) |

**Meta Agents (orchestrate other agents)**

| Agent | Tools | Model | Purpose |
|-------|-------|-------|---------|
| `framework-improver` | Read, Glob, Grep, Edit, Write, Bash | opus | Updates CLAUDE.md, rules, settings, agents |
| `planner-coordinator` | Read, Glob, Grep, Bash, Agent | opus | Orchestrates planning specialists (invoked by `/plan`) |
| `build-coordinator` | Read, Glob, Grep, Bash, Agent | opus | Orchestrates build phases sequentially (invoked by `/build`) |
| `review-coordinator` | Read, Glob, Grep, Bash, Agent | opus | Synthesizes parallel reviewer output (invoked by `/iterative-review`) |
| `project-setup` | Read, Glob, Grep, Edit, Write, Bash | opus | First-time onboarding — 15-layer stack detection + apply pass (invoked by `/setup`) |

### Commands (6)

| Command | Purpose |
|---------|---------|
| `/quick-test` | Run tests on changed files |
| `/lint-fix` | Auto-fix lint issues |
| `/check-types` | Run type checker |
| `/branch-status` | Show diff stats, PR, CI status |
| `/changelog` | Generate changelog from commits |
| `/dep-check` | Check for outdated dependencies |

### Rules (22)

| Rule | Patterns | Key Standards |
|------|----------|---------------|
| `api-routes` | API handlers | Input validation, auth, structured errors |
| `components` | UI components | Accessibility, size limits, state management |
| `tests` | Test files | Factories, descriptive names, reliability |
| `database` | Models, migrations | Parameterized queries, indexes, transactions |
| `config-files` | JSON, YAML, TOML | No secrets, document values |
| `error-handling` | Source files | No silent catches, context, tracking |
| `auth-security` | Source files | Fail-closed auth, CSRF, RBAC, session security, SSRF |
| `data-protection` | Source files | No PII in git, credentials, log redaction, third-party data |
| `design-system` | UI components | Semantic tokens, spacing, typography, theme compliance |
| `code-smells` | Source files | Long methods, magic numbers, primitive obsession, dead code, data clumps, feature envy (cited by `code-smell-reviewer`) |
| `dry` | Source files | True duplication threshold (3+ sites), what to extract / what NOT (cited by `dry-reviewer`) |
| `purity` | Source files | Pure-function discipline, query/command separation, hidden state, input mutation, SRP (cited by `purity-reviewer`) |
| `complexity` | Source files | Function length, cyclomatic complexity, nesting, parameter count thresholds (cited by `complexity-reviewer`) |
| `frontend-architecture` | UI components | Component composition, state, hook discipline, data flow, render-perf architecture (cited by `frontend-architecture-reviewer`) |
| `architecture-layering` | Source files | Layer dependency direction, cross-module reach, circular deps, god modules (cited by `architecture-reviewer`) |
| `api-layering` | API handlers | Controller/service/repo separation, validation placement, error contract, idempotency (cited by `api-layering-reviewer`) |
| `crypto` | Source files | Hash algorithms, password storage, RNG, encryption modes/IV, JWT, TLS, key derivation, constant-time compare (cited by `crypto-reviewer`; OWASP A02) |
| `solid` | Source files | OCP/LSP/ISP/DIP (cited by `solid-reviewer`); SRP is `purity`'s domain |
| `concurrency` | Source files | Race conditions, TOCTOU, async discipline, locks, mutable shared state, background workers, channels (cited by `concurrency-reviewer`) |
| `observability` | Source files | Structured logging, log levels, metrics, tracing, audit logs, alerting, correlation (cited by `observability-reviewer`; OWASP A09) |
| `supply-chain` | Manifests / Dockerfiles / CI workflows | Lockfile hygiene, pinning, CVE reachability, signing, dev/prod separation, deserialization, pipeline integrity (cited by `supply-chain-reviewer`; OWASP A06+A08) |
| `secrets-management` | Source files | Storage, loading, rotation, scanning, in-code discipline, service identity (cited by `security-auditor`) |

### Hooks (6)

| Hook | Event | Purpose |
|------|-------|---------|
| `guardrails.sh` | PreToolUse (Bash) | Blocks dangerous ops: deploys, migrations, force push, destructive deletes |
| `post-edit-sync.sh` | PostToolUse (Edit/Write) | Flags which docs need updating when files change |
| `session-start.sh` | SessionStart | Stale branch warning, env check, dep health |
| `session-stop.sh` | SessionEnd | Audio notification |
| `post-coding-review.sh` | SessionEnd | Nudges `/team review` when substantial source changes exist |
| `pre-commit.sh` | Git pre-commit | Type/lint check (if configured), secret scan, large-file guard |

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
