# Agent Teams & AI Factory

How to use agent teams for high-performing AI-assisted development.

## Philosophy

A single AI assistant is powerful. A coordinated team of specialized AI agents — each with restricted tools, appropriate models, and focused expertise — is transformational. The framework provides 12 pre-configured agents that cover every role in a modern development team.

## Agent Roster (12 agents)

### Analysis Agents (read-only)

| Agent | Role | Model | Specialty |
|-------|------|-------|-----------|
| `architect` | System Design | opus | Architecture patterns, layer separation, scalability |
| `code-reviewer` | Code Quality | opus | Bugs, conventions, error handling in diffs |
| `security-auditor` | Security | opus | OWASP vulnerabilities, credentials, dependencies |
| `refactor-advisor` | Code Structure | opus | Duplication, complexity, extraction opportunities |
| `devops-engineer` | Operations | opus | CI/CD, containers, infrastructure, monitoring |
| `ui-ux-reviewer` | Design Quality | opus | Accessibility, consistency, responsive, UX patterns |
| `performance-optimizer` | Performance | opus | Bundle size, queries, rendering, caching, memory |
| `api-designer` | API Quality | opus | REST conventions, schemas, versioning, DX |
| `database-architect` | Data Design | opus | Schema, normalization, indexes, migration safety |

### Implementation Agents (can modify code)

| Agent | Role | Model | Specialty |
|-------|------|-------|-----------|
| `test-writer` | Test Generation | opus | Unit/integration tests following project patterns |
| `documentation-writer` | Documentation | opus | API docs, READMEs, architecture docs, guides |

### Meta Agents (modify framework)

| Agent | Role | Model | Specialty |
|-------|------|-------|-----------|
| `framework-improver` | Self-Improvement | opus | Updates CLAUDE.md, rules, settings, agents |

## Pre-Configured Teams

### `/team review` — Code Review Team
**Agents:** code-reviewer + security-auditor + ui-ux-reviewer
**When:** Before merging PRs, after major feature implementation
**Output:** Combined review with bugs, security issues, and UX findings

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

### `/team documentation` — Documentation Team
**Agents:** documentation-writer + api-designer
**When:** After API changes, before releases, during onboarding prep
**Output:** Updated docs + API design review

### `/team full` — Full Team Review
**Agents:** All 12 agents
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

The `framework-improver` agent and `/improve` skill enable the framework to evolve:

1. **Run `/improve`** after setup to fill in CLAUDE.md from project analysis
2. **Run `/improve` periodically** to catch drift between docs and code
3. **Use `/improve scan`** for a dry-run report without changes
4. **Use `/ai-update`** after `/improve` to commit changes as a tracked PR
