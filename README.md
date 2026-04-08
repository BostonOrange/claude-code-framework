# Claude Code Framework

A reusable AI development workflow framework for Claude Code. Extracted from a production Salesforce FSL project where this system reduced human touchpoints from 5+ to 2 per feature.

## What This Is

A portable set of **skills**, **agents**, **commands**, **rules**, **hooks**, **templates**, **workflows**, and **memory patterns** that give any project an advanced AI-powered development pipeline:

```
SA/PM drafts story → AI readiness gate → AI implements → AI validates → PR → CI deploys → human reviews → merge → deploy
```

## Architecture

Three separable layers:

| Layer | What | Examples | Portable? |
|-------|------|----------|-----------|
| **Workflow skills** | Development lifecycle patterns | `/develop`, `/validate`, `/factory`, `/check-readiness` | Yes — core of this framework |
| **Integration adapters** | Connect to external systems | ADO/Jira/Linear, Slack/Teams, GitHub Actions/GitLab CI | Swappable — configure per project |
| **Domain knowledge** | Project-specific references | Object inventories, API specs, business rules | Project-specific — you build these |

## Quick Start

### 1. Run Setup

```bash
cd your-project/
bash ~/Developer/claude-code-framework/setup.sh
```

The setup wizard asks:
- Project type (Salesforce, Node.js, Python, Go, etc.)
- Work item tracker (Azure DevOps, Jira, Linear, GitHub Issues)
- CI/CD platform (GitHub Actions, GitLab CI, CircleCI)
- Deployment target (Salesforce org, AWS, Vercel, Docker, etc.)
- Notification system (Slack, Teams, Discord, none)

Then generates:
- `.claude/skills/` — 16 workflow skills adapted to your stack (incl. `/team`, `/improve`)
- `.claude/agents/` — 12 AI agents covering full team roles (all opus)
- `.claude/commands/` — 6 quick commands (quick-test, lint-fix, check-types, branch-status, changelog, dep-check)
- `.claude/rules/` — file-pattern-scoped coding guardrails
- `.claude/hooks/` — 5 lifecycle hooks (guardrails, pre-commit, post-edit-sync, session-start, session-stop)
- `.claude/settings.local.json` — project permissions, hooks
- `.mcp.json` — MCP servers (Context7 documentation)
- `~/.claude/settings.json` — user-level AI factory permissions, team orchestration (safe-by-default)
- `CLAUDE.md` — project instructions (run `/improve` to auto-fill from project state)
- `.github/workflows/` — CI/CD templates (if GitHub Actions)

### 2. Add Domain Knowledge

Create domain skills with references:

```bash
# In your project, after setup:
mkdir -p .claude/skills/my-domain/references/

# Use the add-reference skill to scan your codebase
/add-reference my-domain objects        # Scan and document your data model
/add-reference my-domain api-endpoints  # Document your API surface
```

### 3. Start Using

| You are a... | Start with | Purpose |
|--------------|------------|---------|
| Architect/PM | `/draft-story` | Requirements → implementation-ready stories |
| Architect/PM | `/team architecture` | Architecture review before implementation |
| Developer | `/develop TICKET-123` | Full dev cycle: implement, validate, PR |
| Reviewer | `/team review` | Parallel code + security + UX review |
| DevOps | `/team release` | Release readiness check |
| Any | `/factory TICKET-123` | End-to-end: readiness → develop → validate → PR → deploy |
| Any | `/improve` | Auto-evolve CLAUDE.md and .claude/ config from project state |

## Skills Included

### Core Workflow Skills (portable)

| Skill | Purpose |
|-------|---------|
| `/develop` | Full development cycle: fetch ticket, analyze, implement, validate, PR. Memory-aware (worktree prefs, env aliases, build fixes) |
| `/validate` | Code standards + project conventions checking |
| `/factory` | End-to-end pipeline: readiness → develop → validate → PR → CI deploy. Produces execution logs |
| `/check-readiness` | Validates a ticket is implementation-ready before `/develop` |
| `/draft-story` | Create stories from requirements or design docs |
| `/refine-story` | Improve existing stories with gap analysis |
| `/merge-resolve` | AI-powered merge conflict resolution — reads both features' story docs to understand intent, resolves per file type |
| `/error-analyze` | Triage errors from monitoring, create tickets |
| `/team` | Spawn agent teams for parallel analysis (review, architecture, release, quality, full) |
| `/improve` | Self-improvement — update CLAUDE.md, rules, settings from project analysis |
| `/ai-update` | Branch + PR for AI process file changes |
| `/add-reference` | Add/update domain knowledge references |
| `/update-tracker` | Push story docs back to work item tracker |
| `/deploy` | Orchestrate deployments to environments |
| `/fetch-docs` | Fetch and persist external documentation |
| `/mock-endpoint` | Mock external API integrations |

### AI Agents (12 specialized teammates)

| Agent | Model | Purpose |
|-------|-------|---------|
| `architect` | opus | System design review, architecture patterns, scalability assessment |
| `code-reviewer` | opus | Reviews diff for bugs, security, performance, conventions. Read-only |
| `security-auditor` | opus | OWASP audit: credentials, dependencies, auth, compliance |
| `refactor-advisor` | opus | Duplication, complexity, extraction opportunities. Read-only |
| `devops-engineer` | opus | CI/CD, containers, infrastructure, deployment readiness |
| `ui-ux-reviewer` | opus | Accessibility, design consistency, responsive, UX patterns |
| `performance-optimizer` | opus | Bundle size, queries, rendering, caching, memory |
| `api-designer` | opus | Endpoint design, schemas, versioning, developer experience |
| `database-architect` | opus | Schema, normalization, indexes, migration safety |
| `test-writer` | opus | Generates tests following project conventions. Read/Write |
| `documentation-writer` | opus | API docs, READMEs, architecture docs. Read/Write |
| `framework-improver` | opus | Self-improvement: updates CLAUDE.md, rules, settings. Read/Write |

### Agent Teams (pre-configured groups)

| Team | Command | Agents |
|------|---------|--------|
| Review | `/team review` | code-reviewer + security-auditor + ui-ux-reviewer |
| Architecture | `/team architecture` | architect + api-designer + database-architect |
| Release | `/team release` | security-auditor + devops-engineer + performance-optimizer |
| Quality | `/team quality` | code-reviewer + test-writer + performance-optimizer |
| Documentation | `/team documentation` | documentation-writer + api-designer |
| Full | `/team full` | All 12 agents |
| Custom | `/team custom a b` | Any combination |

### Commands (one-word automations)

| Command | Purpose |
|---------|---------|
| `/quick-test` | Run tests on changed files only |
| `/lint-fix` | Auto-fix lint issues in changed files |
| `/check-types` | Run type checker |
| `/branch-status` | Show diff stats, PR status, CI checks |
| `/changelog` | Generate changelog from commits since last tag |
| `/dep-check` | Check for outdated or vulnerable dependencies |

### Rules (automatic guardrails)

File-pattern-scoped rules that Claude follows automatically when editing matching files:

| Rule | Applies To | Key Standards |
|------|-----------|---------------|
| `api-routes` | API handlers | Input validation, auth checks, structured errors, no PII in logs |
| `components` | UI components | Accessibility, error boundaries, <200 lines, loading/error states |
| `tests` | Test files | Use factories, descriptive names, no sleep waits, cleanup |
| `database` | Models, migrations | Parameterized queries, indexes, reversible migrations |
| `config-files` | JSON, YAML, TOML | No secrets, document values, validate at startup |
| `error-handling` | Source files | No silent catches, error tracking, context on re-throw |

### Hooks (lifecycle quality gates)

| Hook | When | What |
|------|------|------|
| `guardrails.sh` | PreToolUse (Bash) | Blocks dangerous ops: deploys, migrations, force push, destructive deletes |
| `pre-commit.sh` | Before commits | Type check, lint, secret scan, large file guard |
| `post-edit-sync.sh` | PostToolUse (Edit/Write) | Flags which docs need updating when files change |
| `session-start.sh` | Session start | Stale branch warning, env check, dependency health |
| `session-stop.sh` | Session stop | Audio notification (macOS, Linux, Windows) |

### Skill Chaining (Factory Pipeline)

```
/draft-story (architect resolves questions)
    → Ticket "Ready for Sprint"
    ↓
/factory TICKET-xxx
    ↓
┌──────────────────────┐
│  READINESS GATE      │ → FAIL: return to architect with gap report
│  /check-readiness    │ → PASS: continue
└──────────┬───────────┘
           ↓
┌──────────────────────┐
│  IMPLEMENT           │ /develop (phases 1-5)
│  + VALIDATE          │ /validate (code standards)
└──────────┬───────────┘
           ↓
┌──────────────────────┐
│  COMMIT & PR         │ Push + create PR (triggers CI)
└──────────┬───────────┘
           ↓ (CI/CD)
┌──────────────────────┐
│  DEPLOY TO TEST ENV  │ CI workflow deploys, posts link
└──────────┬───────────┘
           ↓
┌──────────────────────┐
│  HUMAN REVIEW        │ Reviewer tests in deployed env
└──────────┬───────────┘
           ↓
┌──────────────────────┐
│  MERGE & DEPLOY      │ Auto-merge → deploy to staging/prod
└──────────┬───────────┘
           ↓ (background)
┌──────────────────────┐
│  FRAMEWORK IMPROVE   │ framework-improver auto-evolves .claude/ config
└──────────────────────┘
```

> The `framework-improver` agent runs automatically in the background after **any session where files were modified** — not just `/develop` and `/factory`. This is enforced via CLAUDE.md instructions, so documentation and `.claude/` config always stay in sync with the actual project state. Changes are logged to `docs/ai-improvements.md`.

## Integration Adapters

The framework uses adapter placeholders (`{{TRACKER_*}}`, `{{CI_*}}`, `{{DEPLOY_*}}`, `{{NOTIFY_*}}`) that `setup.sh` replaces with your specific tools:

### Work Item Trackers

| Tracker | Adapter | What It Configures |
|---------|---------|-------------------|
| Azure DevOps | `adapters/ado.env` | REST API endpoints, PAT auth, field mappings, WIQL queries |
| Jira | `adapters/jira.env` | REST API v3, API token auth, JQL queries, custom fields |
| Linear | `adapters/linear.env` | GraphQL API, API key auth, team/project IDs |
| GitHub Issues | `adapters/github.env` | `gh` CLI, labels, milestones, project boards |

### CI/CD Platforms

| Platform | Adapter | What It Generates |
|----------|---------|-------------------|
| GitHub Actions | `workflows/*.yml` | Factory validate, auto-merge, deploy, cleanup |
| GitLab CI | `.gitlab-ci.yml` | Equivalent pipeline stages |

### Deployment Targets

| Target | Adapter | Deploy Commands |
|--------|---------|----------------|
| Salesforce | `adapters/salesforce.env` | `sf project deploy`, scratch orgs, sandbox pool |
| Vercel | `adapters/vercel.env` | `vercel deploy`, preview URLs |
| AWS (CDK/SAM) | `adapters/aws.env` | `cdk deploy`, `sam deploy` |
| Docker/K8s | `adapters/docker.env` | `docker build`, `kubectl apply` |
| Generic | `adapters/generic.env` | Custom deploy script path |

## Permissions (Safe-by-Default)

Setup installs `~/.claude/settings.json` with granular Bash permissions:

| Category | Behavior | Examples |
|----------|----------|---------|
| **Auto-allowed** | Runs without asking | `git commit`, `npm test`, `cat`, `find`, `curl`, `sf apex run test`, `pytest` |
| **Must ask** | Prompts for confirmation | `git push`, `rm`, `sf project deploy`, `kubectl apply`, DB migrations |
| **Blocked** | Denied entirely | `rm -rf /`, `rm -rf ~`, `mkfs`, `dd if=` |

All non-Bash tools are auto-allowed: file editing, agents, tasks, teams, web access, worktrees, cron, plan mode. The framework-improver can freely update `.claude/` and `CLAUDE.md` without prompting.

## MCP Servers

The framework generates a `.mcp.json` at project root with pre-configured MCP servers:

| Server | Package | Purpose |
|--------|---------|---------|
| **Context7** | `@upstash/context7-mcp` | Fetches up-to-date, version-specific documentation for 9,000+ libraries. Works across all project types (Node.js, Python, Go, Java, Rails, etc.) |

Context7 tools (`resolve-library-id`, `get-library-docs`) are auto-allowed in the project permissions. Several skills and agents use Context7 proactively — they fetch current library docs before making implementation decisions, without requiring you to ask:

| Component | When It Uses Context7 |
|-----------|----------------------|
| `/develop` | Before implementing — fetches docs for project dependencies |
| `/draft-story` | When solution involves external dependencies — verifies API capabilities |
| `/refine-story` | During gap analysis — checks library APIs match ticket assumptions |
| `/mock-endpoint` | When mocking SDK endpoints — fetches real signatures and response shapes |
| `architect` | When reviewing integrations — verifies patterns match library recommendations |
| `api-designer` | When reviewing API frameworks/validators — checks current best practices |
| `documentation-writer` | When documenting library wrappers — ensures docs match actual API |
| `performance-optimizer` | When analyzing framework performance — fetches current optimization APIs |
| `test-writer` | When generating tests — fetches current test framework API patterns |

You can also trigger Context7 manually by adding "use context7" to any prompt when asking about specific libraries.

## Memory System

The framework sets up Claude Code's persistent memory:

```
~/.claude/projects/{project-path}/memory/
├── MEMORY.md          # Index (auto-loaded each conversation)
├── user_role.md       # Who you are, preferences
├── feedback_*.md      # Corrections and guidance
├── project_*.md       # Ongoing work context
└── reference_*.md     # External system pointers
```

## Customization

### Adding a Domain Skill

```bash
cp -r .claude/skills/_template .claude/skills/my-domain
# Edit .claude/skills/my-domain/SKILL.md
# Add references: .claude/skills/my-domain/references/*.md
```

### Adding Validation Rules

Edit `.claude/skills/validate/SKILL.md` to add project-specific checks to the check matrix.

### Changing the Pipeline

Edit `.claude/skills/factory/SKILL.md` to add/remove pipeline stages.

## Documentation

| Doc | What It Covers |
|-----|---------------|
| `docs/architecture.md` | System design — layers, skill format, adapter pattern, memory lifecycle |
| `docs/agents-commands-rules.md` | Agents, commands, rules, hooks — formats, comparison, customization |
| `docs/teams.md` | Agent teams, AI factory workflow, project archetype examples |
| `docs/skill-authoring.md` | How to write new skills — format, patterns, categories, testing |
| `docs/sub-agent-orchestration.md` | How skills spawn parallel agents, pass context, run background tasks |
| `docs/memory-patterns.md` | How skills read/write memory for smarter behavior across conversations |
| `docs/examples/` | Example configs for Salesforce, Next.js, Python API projects |

## Files Reference

```
claude-code-framework/
├── README.md                    # This file
├── setup.sh                     # Interactive setup wizard (Bash)
├── setup.ps1                    # Interactive setup wizard (PowerShell)
├── .gitignore
├── templates/
│   ├── CLAUDE.md.template       # Project instructions template
│   ├── settings.json            # User-level AI factory permissions
│   ├── settings.local.json      # Project-level permissions & model config
│   ├── mcp.json                 # MCP server config (copied to .mcp.json)
│   ├── agents/                  # 12 AI agent definitions
│   │   ├── architect.md         # System design, patterns, scalability
│   │   ├── code-reviewer.md     # Bugs, security, performance in diffs
│   │   ├── security-auditor.md  # OWASP audit, credentials, deps
│   │   ├── refactor-advisor.md  # Duplication, complexity, structure
│   │   ├── devops-engineer.md   # CI/CD, containers, infrastructure
│   │   ├── ui-ux-reviewer.md    # Accessibility, design, responsiveness
│   │   ├── performance-optimizer.md  # Bundle, queries, caching
│   │   ├── api-designer.md      # Endpoint design, schemas, DX
│   │   ├── database-architect.md # Schema, indexes, migrations
│   │   ├── test-writer.md       # Test generation
│   │   ├── documentation-writer.md  # API docs, guides
│   │   └── framework-improver.md # Self-improvement meta-agent
│   ├── commands/                # One-word automations
│   │   ├── quick-test.md
│   │   ├── lint-fix.md
│   │   ├── check-types.md
│   │   ├── branch-status.md
│   │   ├── changelog.md
│   │   └── dep-check.md
│   ├── rules/                   # File-pattern guardrails
│   │   ├── api-routes.md
│   │   ├── components.md
│   │   ├── tests.md
│   │   ├── database.md
│   │   ├── config-files.md
│   │   └── error-handling.md
│   ├── hooks/                   # Lifecycle scripts
│   │   ├── guardrails.sh        # PreToolUse: block dangerous ops
│   │   ├── pre-commit.sh
│   │   ├── post-edit-sync.sh    # PostToolUse: flag docs needing sync
│   │   ├── session-start.sh
│   │   └── session-stop.sh
│   └── statusline/              # Custom status bar
├── skills/
│   ├── _template/               # Blueprint for new skills
│   ├── develop/                 # Development cycle (memory-aware)
│   ├── validate/                # Code validation
│   ├── draft-story/             # Story creation
│   ├── refine-story/            # Story refinement + templates
│   ├── check-readiness/         # Readiness gate (auto/semi-auto classification)
│   ├── factory/                 # End-to-end pipeline (execution logging)
│   ├── merge-resolve/           # AI merge conflict resolution
│   ├── error-analyze/           # Error triage (interactive + CI mode)
│   ├── ai-update/               # AI process updates
│   ├── add-reference/           # Knowledge management
│   ├── update-tracker/          # Work item sync
│   ├── deploy/                  # Deployment orchestration
│   ├── team/                    # Agent team spawning
│   ├── improve/                 # Framework self-improvement
│   ├── fetch-docs/              # External documentation fetch
│   └── mock-endpoint/           # Mock API endpoints
├── workflows/                   # CI/CD templates
│   ├── factory-validate.yml     # Deploy PR to test env
│   ├── factory-auto-merge.yml   # Auto-merge after approval
│   ├── factory-deploy.yml       # Deploy to staging (auto/semi-auto classification)
│   └── factory-cleanup.yml      # Tear down ephemeral environments
├── memory/                      # Memory system templates
└── docs/
    ├── architecture.md          # System design
    ├── agents-commands-rules.md # Agents, commands, rules & hooks guide
    ├── teams.md                 # Agent teams & AI factory workflow
    ├── skill-authoring.md       # How to write skills
    ├── sub-agent-orchestration.md  # Parallel agents, chaining, background tasks
    ├── memory-patterns.md       # Memory-aware skill patterns
    └── examples/                # Example configs per project type
```
