# Agent Teams & AI Factory

How to use agent teams for high-performing AI-assisted development.

## Philosophy

A single AI assistant is powerful. A coordinated team of specialized AI agents — each with restricted tools, appropriate models, and focused expertise — is transformational. The framework provides 12 pre-configured agents that cover every role in a modern development team.

## Agent Roster (12 agents)

### Analysis Agents (read-only)

| Agent | Role | Model | Specialty |
|-------|------|-------|-----------|
| `architect` | System Design | opus | Architecture patterns, layer separation, scalability |
| `code-reviewer` | Code Quality (broad) | opus | Bugs, conventions, error handling, design principles, code smells in diffs |
| `code-smell-reviewer` | Code Smells | opus | Long methods, magic numbers, primitive obsession, dead code, data clumps, feature envy (cites `code-smells`) |
| `dry-reviewer` | Duplication | opus | True duplication at 3+ sites, extraction targets (cites `dry`) |
| `purity-reviewer` | Purity & SRP | opus | Pure functions, side effects, query/command separation, hidden state, function-level SRP (cites `purity`) |
| `complexity-reviewer` | Complexity | opus | Function length, cyclomatic complexity, nesting, parameter count (cites `complexity`) |
| `frontend-architecture-reviewer` | FE Structure | opus | Composition, state, hooks, data flow, render-perf architecture (cites `frontend-architecture`) |
| `architecture-reviewer` | Layering | opus | Dependency direction, cross-module reach, circular deps, god modules (cites `architecture-layering`) |
| `api-layering-reviewer` | API Layering | opus | Controller/service/repo separation, validation placement, error contract (cites `api-layering`) |
| `crypto-reviewer` | Cryptography (OWASP A02) | opus | Weak hashes, password storage, RNG, encryption modes/IV, JWT, TLS, key derivation, constant-time compare (cites `crypto`) |
| `solid-reviewer` | SOLID Principles | opus | OCP/LSP/ISP/DIP (cites `solid`); SRP is `purity-reviewer`'s domain |
| `concurrency-reviewer` | Concurrency | opus | Races, TOCTOU, async discipline, locks, mutable shared state, background workers (cites `concurrency`) |
| `observability-reviewer` | Observability (OWASP A09) | opus | Structured logging, log levels, metrics, tracing, audit logs, alerting, correlation (cites `observability`) |
| `supply-chain-reviewer` | Supply Chain (OWASP A06+A08) | opus | Lockfiles, pinning, CVE reachability, signing, dev/prod separation, CI pipeline integrity (cites `supply-chain`) |
| `security-auditor` | Security (broad) | opus | OWASP audit, credentials, dependencies; cites `secrets-management` for storage findings |
| `devops-engineer` | Operations | opus | CI/CD, containers, infrastructure, monitoring |
| `ui-ux-reviewer` | Design Quality | opus | Accessibility, consistency, responsive, UX patterns |
| `performance-optimizer` | Performance | opus | Bundle size, queries, rendering, caching, memory |
| `api-designer` | API Quality | opus | REST conventions, schemas, versioning, DX |
| `database-architect` | Data Design | opus | Schema, normalization, indexes, migration safety |

### Planning Agents (read-only — used by `/plan`)

| Agent | Role | Model | Specialty |
|-------|------|-------|-----------|
| `requirements-clarifier` | Ambiguity Hunt | opus | Open questions, undefined terms, missing AC, conflicting requirements |
| `scope-decomposer` | Work Breakdown | opus | Atomic steps, sequencing, parallelism groups, dependencies |
| `risk-assessor` | Risk Surfacing | opus | Rollback paths, blast radius, breaking-change & migration risk; mitigations |
| `test-strategy-planner` | Test Strategy | opus | Test levels per planned step (unit/integration/e2e/contract/property) |

### Implementation Agents (can modify code)

| Agent | Role | Model | Specialty |
|-------|------|-------|-----------|
| `scaffold-implementer` | Build Phase 1 | opus | File structure, types, signatures, stubs (no logic) |
| `happy-path-implementer` | Build Phase 2 | opus | Core successful flow logic; defers errors and edges |
| `edge-case-implementer` | Build Phase 3 | opus | Validation, error handling, edge data; binds error-handling/auth-security/data-protection |
| `refactor-pass-implementer` | Build Phase 6 (final) | opus | Actively applies code-smells/dry/purity/complexity rules; preempts review findings |
| `test-writer` | Test Generation | opus | Unit/integration tests following project patterns (used in build phase 4) |
| `documentation-writer` | Documentation | opus | API docs, READMEs, architecture docs, guides (used in build phase 5) |

### Meta Agents (orchestrate other agents)

| Agent | Role | Model | Specialty |
|-------|------|-------|-----------|
| `framework-improver-detector` | Self-Improvement (read-only) | opus | Scans, builds /setup-aware skip-list, writes proposal (invoked by `/improve` Phase 1) |
| `framework-improver-applier` | Self-Improvement (write) | opus | Re-validates skip-list, applies improvements with backup + audit log (invoked by `/improve` Phase 3) |
| `planner-coordinator` | Planning Orchestration | opus | Spawns planning specialists in parallel waves; synthesizes one plan (invoked by `/plan`) |
| `build-coordinator` | Build Orchestration | opus | Sequences build phases; spawns specialist per phase; runs safety gates (invoked by `/build`) |
| `review-coordinator` | Review Orchestration | opus | Synthesizes parallel reviewer findings, classifies risk tier, persists state across iterations (invoked by `/iterative-review`) |
| `project-setup-detector` | Onboarding (read-only) | opus | First-time setup — 17-layer stack detection with tradeoff-explained options; writes proposal (invoked by `/setup` Phase 1) |
| `project-setup-applier` | Onboarding (write) | opus | First-time setup — validates allowlist, snapshots, applies substitutions, writes audit log (invoked by `/setup` Phase 4) |
| `impact-analyzer` | Cascade Analysis | opus | On-demand precise impact analysis — greps callers, classifies, scores confidence, writes per-symbol report (invoked by `/impact`) |
| `docs-staleness-reviewer` | Docs-Drift Review | opus | Catches material changes (framework/test/build swaps, restructures, env vars, CI workflows, breaking API) without CLAUDE.md updates at review time. Cites `docs-staleness` rule |

## Pre-Configured Teams

### `/team review` — Code Review Team
**Agents:** code-reviewer + security-auditor + ui-ux-reviewer
**When:** Before merging PRs, after major feature implementation
**Output:** Combined review with bugs, security issues, and UX findings

### `/team review-deep` — Deep Code Review Team
**Agents:** code-reviewer + security-auditor + code-smell-reviewer + dry-reviewer + purity-reviewer + complexity-reviewer
**When:** Before merging non-trivial PRs (multiple files, business logic changes)
**Output:** Broad sweep + 4 narrow code-quality perspectives, each citing its rule. Use `/iterative-review` for full coordinator-driven dedup + state.

### `/team architecture` — Architecture Review Team
**Agents:** architect + api-designer + database-architect
**When:** Before starting new features, during design phase, quarterly health checks
**Output:** Architecture assessment, API design review, database schema analysis

### `/team release` — Release Readiness Team
**Agents:** security-auditor + devops-engineer + performance-optimizer
**When:** Before releases, after major dependency updates
**Output:** Security audit, deployment readiness check, performance analysis

### `/team quality` — Quality Assurance Team
**Agents:** code-reviewer + test-writer + performance-optimizer
**When:** After implementation, before PR creation
**Output:** Code review + generated tests + performance analysis

### `/team quality-deep` — Code-Quality Specialists
**Agents:** code-smell-reviewer + dry-reviewer + purity-reviewer + complexity-reviewer
**When:** When you want a focused code-quality sweep with rule citations and no security/UI noise
**Output:** Four narrow perspectives in parallel — each cites its rule (`code-smells`, `dry`, `purity`, `complexity`). Findings are easy to triage because each is single-concern.

### `/team design` — Design Review Team
**Agents:** ui-ux-reviewer + performance-optimizer + frontend-architecture-reviewer
**When:** After UI changes, design system updates, component refactoring
**Output:** UX review, performance analysis, refactoring recommendations

### `/team documentation` — Documentation Team
**Agents:** documentation-writer + api-designer
**When:** After API changes, before releases, during onboarding prep
**Output:** Updated docs + API design review

### `/team full` — Full Team Review
**Agents:** All 16 reviewer/implementation agents (excludes meta-agents like `review-coordinator`, the `framework-improver-*` pair, and the `project-setup-*` pair)
**When:** Major milestones, quarterly reviews, new project onboarding
**Output:** Comprehensive analysis across all dimensions

### `/team custom agent1 agent2` — Custom Team
**Agents:** Any combination you specify
**When:** Targeted analysis for specific concerns

## AI Factory Workflow

The framework enables a factory-style development pipeline where AI handles most of the repetitive work and humans focus on decisions:

```
                    PLANNING PHASE
                    ─────────────
Architect/PM:       /draft-story requirements.md
                    ↓
                    /team architecture  (validate design)
                    ↓
                    /refine-story TICKET-xxx  (fill gaps)
                    ↓
                    /check-readiness TICKET-xxx  (gate)

                    IMPLEMENTATION PHASE
                    ───────────────────
Developer:          /factory TICKET-xxx
                    ├─ AI implements from spec
                    ├─ AI validates (code + tests)
                    ├─ AI creates PR
                    └─ CI deploys to test env

                    REVIEW PHASE
                    ────────────
Reviewer:           /team review  (automated review)
                    ↓
                    Human reviews findings + tests in env
                    ↓
                    Approve → auto-merge → deploy

                    MAINTENANCE PHASE
                    ─────────────────
DevOps:             /team release  (pre-release check)
Developer:          /error-analyze  (triage production errors)
Any:                /improve  (evolve the framework)
```

### Human Touchpoints (minimized)

| Step | Who | What | AI Does |
|------|-----|------|---------|
| Story approval | Architect/PM | Approve requirements | AI drafted the story, validated readiness |
| Code review | Developer | Review AI findings, test in env | AI wrote code, tests, ran all agents |
| Deploy approval | DevOps | Approve production deploy | AI validated release readiness |

Everything else is automated: implementation, testing, CI/CD, documentation, monitoring.

## Project Archetype Examples

### Web Application (Next.js, React, etc.)
```
Key agents: ui-ux-reviewer, performance-optimizer, code-reviewer
Key rules: api-routes, components, tests
Key teams: /team review, /team quality
```

### AI Chatbot / Automation Pipeline
```
Key agents: architect, api-designer, security-auditor
Key rules: api-routes, error-handling, config-files
Key teams: /team architecture, /team release
```

### Salesforce Development
```
Key agents: code-reviewer, test-writer, database-architect
Key rules: api-routes (Apex REST), tests (Apex tests), database (objects/fields)
Key teams: /team quality, /team review
```

### Middleware / API Service
```
Key agents: api-designer, performance-optimizer, security-auditor
Key rules: api-routes, database, error-handling
Key teams: /team architecture, /team release
```

### Mobile Application
```
Key agents: ui-ux-reviewer, performance-optimizer, code-reviewer
Key rules: components, tests, error-handling
Key teams: /team review, /team quality
```

## Configuring Teams for Your Project

### Adding a Custom Agent

1. Create `.claude/agents/my-agent.md` with YAML frontmatter
2. Reference it in `/team custom my-agent other-agent`
3. Update CLAUDE.md Agents Available table

### Adjusting Agent Models

Edit the agent's YAML frontmatter to change `model:`:
- `opus` — Complex reasoning tasks (architecture, security)
- `sonnet` — Balanced speed/quality (code review, testing)
- `haiku` — Fast, simple tasks (formatting checks, simple lookups)

### Restricting Agent Tools

Edit the agent's `tools:` field:
- Read-only agents: `Read, Glob, Grep, Bash`
- Implementation agents: `Read, Glob, Grep, Edit, Write, Bash`
- Full access: `Read, Glob, Grep, Edit, Write, Bash, WebFetch, WebSearch`

## Self-Improvement

The `/improve` skill (which orchestrates `framework-improver-detector` → `framework-improver-applier`) enables the framework to evolve:

1. **Run `/improve`** after setup to fill in CLAUDE.md from project analysis
2. **Run `/improve` periodically** to catch drift between docs and code
3. **Use `/improve scan`** for a dry-run report without changes
4. **Use `/ai-update`** after `/improve` to commit changes as a tracked PR
