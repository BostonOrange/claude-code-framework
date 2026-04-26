# Claude Code Framework

A reusable AI development workflow framework for Claude Code. This system reduces human touchpoints from 5+ to 2 per feature.

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

### 1. Clone the framework (once per machine)

Clone this repo anywhere you like. The path is yours to choose — the examples below use `~/claude-code-framework` (macOS/Linux) and `$HOME\claude-code-framework` (Windows).

```bash
# macOS / Linux
git clone https://github.com/<your-fork>/claude-code-framework.git ~/claude-code-framework

# Windows PowerShell
git clone https://github.com/<your-fork>/claude-code-framework.git $HOME\claude-code-framework
```

> **Do not run `setup.sh` inside the framework repo itself.** This repo is the framework; `setup.sh` installs it into a *target project*.

### 2. Run setup in your target project

```bash
# macOS / Linux
cd your-project/
bash ~/claude-code-framework/setup.sh

# Windows PowerShell
cd your-project
& $HOME\claude-code-framework\setup.ps1
```

The setup wizard asks:
- **Project type** (Salesforce, Node.js, React, Python, Go, Java, Rails, Generic)
- **Work item tracker** (Azure DevOps, Jira, Linear, GitHub Issues, None)
- **CI/CD platform** (GitHub Actions, GitLab CI, CircleCI, Jenkins, None)
- **Base branch** (main, develop, master — or custom)
- **Project short name** (used for worktree directories)
- **Notification system** (Slack, Teams, Discord, None)
- **Design system** (Material UI, Tailwind, Chakra, Ant Design, shadcn/ui, custom, or None)

Then generates:
- `.claude/skills/` — 21 workflow skills adapted to your stack (incl. `/team`, `/improve`, `/setup`, `/plan`, `/build`, `/iterative-review`)
- `.claude/agents/` — 36 AI agents covering full team + 12 review specialists + 4 planning specialists + 4 build specialists + 4 meta agents (all opus)
- `.claude/commands/` — 6 quick commands (quick-test, lint-fix, check-types, branch-status, changelog, dep-check)
- `.claude/rules/` — 22 file-pattern-scoped coding guardrails (api-routes, tests, database, config, error-handling, auth-security, data-protection, design-system, components, code-smells, dry, purity, complexity, frontend-architecture, architecture-layering, api-layering, crypto, solid, concurrency, observability, supply-chain, secrets-management)
- `.claude/hooks/` — 6 lifecycle hooks (guardrails, post-edit-sync, session-start, session-stop, post-coding-review, pre-commit)
- `.claude/settings.local.json` — project permissions, hooks
- `.mcp.json` — MCP servers (Context7 documentation)
- `~/.claude/settings.json` — user-level AI factory permissions, team orchestration (safe-by-default)
- `CLAUDE.md` — project instructions (run `/improve` to auto-fill from project state)
- `.github/workflows/` — CI/CD templates (if GitHub Actions)

### 3. Updating the framework in an existing project

When a new version of the framework ships and you want to pull it into an existing target project:

```bash
# In the framework repo:
git pull

# In your target project:
bash ~/claude-code-framework/setup.sh
```

**What gets overwritten:** everything under `.claude/` (skills, agents, commands, rules, hooks, settings), plus `.mcp.json`. Re-running setup reapplies the installer — it replaces these files rather than merging.

**What is preserved:**
- `CLAUDE.md` at the project root — setup refuses to overwrite if it already exists
- `.env` — only created if missing
- Your code, docs, git history — setup never touches anything outside `.claude/`, `.mcp.json`, or `.github/workflows/`
- Files you added under `.claude/skills/{your-domain}/` — setup only copies framework skills, not your custom ones

**Before updating:**
1. Commit or stash any local changes (in case you customized a shipped file)
2. If you customized a file under `.claude/`, diff it against `templates/` in the framework repo first:
   ```bash
   diff .claude/hooks/post-edit-sync.sh ~/claude-code-framework/templates/hooks/post-edit-sync.sh
   ```
3. After updating, run `/improve` — it will repopulate deferred placeholders (`{{PROJECT_DESCRIPTION}}`, `{{TECH_STACK_TABLE}}`, etc.) from current project state if they were stripped.

**To roll back:** restore the previous commit of `.claude/` — the installer is idempotent, so the previous state re-applies cleanly if you re-run the older framework's setup script.

### 4. Add Domain Knowledge

Create domain skills with references:

```bash
# In your project, after setup:
mkdir -p .claude/skills/my-domain/references/

# Use the add-reference skill to scan your codebase
/add-reference my-domain objects        # Scan and document your data model
/add-reference my-domain api-endpoints  # Document your API surface
```

### 5. Start Using

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
| `/team` | Spawn agent teams for parallel analysis (review, architecture, release, quality, design, documentation, full) |
| `/plan` | Multi-agent planning — spawns planner-coordinator + planning specialists, produces `.claude/state/plan-<branch>.md` |
| `/build` | Multi-agent implementation — spawns build-coordinator + build specialists, executes the plan in sequenced phases |
| `/iterative-review` | Plan → code → review → re-code loop with persistent state across iterations (uses `review-coordinator`) |
| `/setup` | First-time onboarding — inventories repo, runs 15-layer detection with tradeoff-explained options, applies confirmed proposal (uses `project-setup`) |
| `/improve` | Self-improvement — update CLAUDE.md, rules, settings from project analysis |
| `/ai-update` | Branch + PR for AI process file changes |
| `/add-reference` | Add/update domain knowledge references |
| `/update-tracker` | Push story docs back to work item tracker |
| `/deploy` | Orchestrate deployments to environments |
| `/fetch-docs` | Fetch and persist external documentation |
| `/mock-endpoint` | Mock external API integrations |
| `/scaffold-design-system` | Scaffold design system tokens, components, and theme config |

### AI Agents (36 specialized teammates)

| Agent | Model | Purpose |
|-------|-------|---------|
| `architect` | opus | System design review, architecture patterns, scalability assessment |
| `code-reviewer` | opus | Reviews diff for bugs, security, performance, design principles, code smells, conventions. Read-only |
| `code-smell-reviewer` | opus | Code smells specialist: long methods, magic numbers, primitive obsession, dead code. Cites `code-smells` rule. Read-only |
| `dry-reviewer` | opus | Duplication specialist: 3+ repeated logic, structural patterns. Cites `dry` rule. Read-only |
| `purity-reviewer` | opus | Pure-function specialist: side effects, query/command separation, SRP, hidden state. Cites `purity` rule. Read-only |
| `complexity-reviewer` | opus | Complexity specialist: function length, cyclomatic complexity, nesting, parameter count. Cites `complexity` rule. Read-only |
| `frontend-architecture-reviewer` | opus | Frontend structure: component composition, state management, hooks, data flow, render-perf architecture. Cites `frontend-architecture` rule. Read-only |
| `architecture-reviewer` | opus | Layering: dependency direction, cross-module reach, circular deps, god modules, public-API leaks. Cites `architecture-layering` rule. Read-only |
| `api-layering-reviewer` | opus | API structure: controller/service/repo separation, validation placement, error contract, idempotency. Cites `api-layering` rule. Read-only |
| `crypto-reviewer` | opus | OWASP A02 specialist: weak hashes, password storage, RNG, encryption modes/IV, JWT, TLS, key derivation, constant-time compare. Cites `crypto`. Read-only |
| `solid-reviewer` | opus | OCP/LSP/ISP/DIP specialist (S is `purity`'s domain). Cites `solid`. Read-only |
| `concurrency-reviewer` | opus | Race conditions, TOCTOU, async/await discipline, lock discipline, mutable shared state, background-work safety, channels. Cites `concurrency`. Read-only |
| `observability-reviewer` | opus | OWASP A09 specialist: structured logging, log levels, metrics, tracing, audit logs, alerting, correlation. Cites `observability`. Read-only |
| `supply-chain-reviewer` | opus | OWASP A06+A08 specialist: lockfiles, version pinning, CVE reachability, signing, dev/prod separation, deserialization, CI pipeline integrity. Cites `supply-chain`. Read-only |
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
| `requirements-clarifier` | opus | Planning specialist: hunts ambiguity in story before planning starts (open questions, undefined terms, missing AC). Read-only |
| `scope-decomposer` | opus | Planning specialist: breaks story into atomic, sequenced steps with parallelism groups and dependencies. Read-only |
| `risk-assessor` | opus | Planning specialist: identifies rollback paths, blast radius, breaking-change and migration risk; proposes mitigations. Read-only |
| `test-strategy-planner` | opus | Planning specialist: decides what tests at what level (unit/integration/e2e/contract) per planned step. Read-only |
| `scaffold-implementer` | opus | Build phase 1: file structure, types, signatures, stubs (no logic). Read/Write, constrained by all relevant rules |
| `happy-path-implementer` | opus | Build phase 2: core successful flow logic (defers errors and edges). Read/Write, constrained by all relevant rules |
| `edge-case-implementer` | opus | Build phase 3: input validation, error handling, edge data, defensive code. Read/Write, tightly bound to error-handling, auth-security, data-protection |
| `refactor-pass-implementer` | opus | Build phase 6 (final): actively applies code-smells/dry/purity/complexity rules; preempts review findings. Read/Write |
| `review-coordinator` | opus | Meta: synthesizes parallel reviewer output, dedupes, filters, classifies risk tier, persists state across iterations |
| `planner-coordinator` | opus | Meta: orchestrates planning specialists, classifies scope, spawns parallel waves, synthesizes one plan |
| `build-coordinator` | opus | Meta: orchestrates build phases sequentially (scaffold → happy-path → edge-case → tests → docs → refactor) |
| `project-setup` | opus | Meta: first-time onboarding — inventories repo, runs 15-layer detection with tradeoff-explained options, applies confirmed proposal (invoked by `/setup`) |

### Agent Teams (pre-configured groups)

| Team | Command | Agents |
|------|---------|--------|
| Review | `/team review` | code-reviewer + security-auditor + ui-ux-reviewer |
| Architecture | `/team architecture` | architect + api-designer + database-architect |
| Release | `/team release` | security-auditor + devops-engineer + performance-optimizer |
| Quality | `/team quality` | code-reviewer + test-writer + performance-optimizer |
| Documentation | `/team documentation` | documentation-writer + api-designer |
| Design | `/team design` | ui-ux-reviewer + performance-optimizer + refactor-advisor |
| Review-deep | `/team review-deep` | code-reviewer + security-auditor + 4 code-quality specialists (smell, dry, purity, complexity) |
| Quality-deep | `/team quality-deep` | The 4 code-quality specialists in parallel (code-smell-reviewer + dry-reviewer + purity-reviewer + complexity-reviewer) |
| Full | `/team full` | All 16 reviewer/implementation agents (excludes meta-agents `review-coordinator` and `framework-improver`) |
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
| `auth-security` | Source files | Fail-closed auth, CSRF, RBAC enforcement, session security, redirects |
| `data-protection` | Source files | No PII in git, no credentials on disk, log redaction, third-party data |
| `design-system` | UI components | Semantic tokens, spacing scale, consistent typography, theme compliance |
| `code-smells` | Source files | Long methods, magic numbers, primitive obsession, data clumps, feature envy, dead code (cited by `code-smell-reviewer`) |
| `dry` | Source files | True duplication threshold (3+ sites), what to extract / what NOT to extract (cited by `dry-reviewer`) |
| `purity` | Source files | Pure-function discipline, query/command separation, hidden state, input mutation, SRP (cited by `purity-reviewer`) |
| `complexity` | Source files | Function length, cyclomatic complexity, nesting, parameter count thresholds (cited by `complexity-reviewer`) |
| `frontend-architecture` | UI components | Component composition, state management, hook discipline, data flow, render-perf architecture (cited by `frontend-architecture-reviewer`) |
| `architecture-layering` | Source files | Layer dependency direction, cross-module reach, circular deps, god modules (cited by `architecture-reviewer`) |
| `api-layering` | API handlers | Controller/service/repo separation, validation placement, error contract, idempotency (cited by `api-layering-reviewer`) |
| `crypto` | Source files | Hashes, password storage, RNG, encryption modes/IV, JWT, TLS, key derivation, constant-time compare (cited by `crypto-reviewer`; OWASP A02) |
| `solid` | Source files | Open/Closed, Liskov Substitution, Interface Segregation, Dependency Inversion (cited by `solid-reviewer`) |
| `concurrency` | Source files | Race conditions, TOCTOU, async discipline, locks, mutable shared state, background workers, channels (cited by `concurrency-reviewer`) |
| `observability` | Source files | Structured logging, log levels, metrics, tracing, audit logs, alerting, correlation (cited by `observability-reviewer`; OWASP A09) |
| `supply-chain` | Manifests/Dockerfiles/CI workflows | Lockfile hygiene, pinning, CVE reachability, signing, dev/prod separation, deserialization, pipeline integrity (cited by `supply-chain-reviewer`; OWASP A06+A08) |
| `secrets-management` | Source files | Storage, loading, rotation, scanning, in-code discipline, service identity (cited by `security-auditor`) |

### Hooks (lifecycle quality gates)

| Hook | When | What |
|------|------|------|
| `guardrails.sh` | PreToolUse (Bash) | Blocks dangerous ops: deploys, migrations, force push, destructive deletes |
| `post-edit-sync.sh` | PostToolUse (Edit/Write) | Flags which docs need updating when files change |
| `session-start.sh` | SessionStart | Stale branch warning, env check, dependency health |
| `session-stop.sh` | SessionEnd | Audio notification (macOS, Linux, Windows) |
| `post-coding-review.sh` | SessionEnd | Nudges `/team review` when substantial source changes exist on branch |
| `pre-commit.sh` | Git pre-commit (`.git/hooks/pre-commit`) | Type check, lint, secret scan (AWS keys / private keys / hardcoded passwords), large-file guard |

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

## Self-Improvement System

The framework has a closed loop that keeps it honest over time. It's not one thing — it's five mechanisms working together:

| Layer | Component | When | What it does |
|-------|-----------|------|--------------|
| Advisory | `post-edit-sync.sh` (hook) | After every Edit/Write | Prints which doc surfaces may need updating based on what changed (e.g. "Agent 'code-reviewer' changed → verify README agents table") |
| Advisory | `post-coding-review.sh` (hook) | SessionEnd, when >=3 source files or >=50 LOC changed vs base | Nudges `/team review` (code-reviewer + security-auditor + ui-ux-reviewer); cooldown per branch+SHA prevents repeat nudges |
| Mutating | `framework-improver` (agent) | End of any session with changes — instructed by CLAUDE.md | Updates CLAUDE.md, `.claude/rules/`, settings, agents from project state; fills deferred placeholders (`{{PROJECT_DESCRIPTION}}` etc.) |
| Verifying | `framework-qa` (agent, framework-repo-only) | End of any session with changes | Validates counts and tables across README, CLAUDE.md, docs are consistent with actual file inventory |
| Deterministic | `tests/run-all.sh` (5 test suites) | CI + before PR | Hard gates for drift: `check-consistency` (counts), `check-agent-registry` (agent JSON ↔ frontmatter ↔ docs, 72 checks), `check-placeholders` (sh/ps1 parity), `check-guardrails` (55 hook patterns), `check-templates` (structural validity) |

The advisory layers surface drift as it happens; the mutating layer fixes it; the verifying + deterministic layers prove it landed. Together they make it hard for documentation to drift from the actual state of the framework or your project.

See `docs/contributing.md` for how to extend each layer when adding new skills, agents, rules, or hooks.

## Integration Configuration

The framework connects to external systems through the **setup wizard** and **environment variables** -- not separate adapter files. During setup, you select your tracker, CI/CD platform, deployment target, and notification system. The wizard writes concrete API calls and commands into your skill files by replacing placeholder tokens (`{{TRACKER_*}}`, `{{CI_*}}`, `{{DEPLOY_*}}`, `{{NOTIFY_*}}`).

### Setup Wizard Integrations

| Category | Options | What Gets Configured |
|----------|---------|---------------------|
| **Work Item Tracker** | Azure DevOps, Jira, Linear, GitHub Issues | Ticket fetch commands, field mappings, state transitions |
| **CI/CD Platform** | GitHub Actions, GitLab CI, CircleCI | Workflow files in `.github/workflows/` or equivalent |
| **Deployment Target** | Salesforce, AWS, Vercel, Docker/K8s, Generic | Deploy commands in `/deploy` skill and CI workflows |
| **Notifications** | Slack, Teams, Discord, None | Post-deploy and review notification commands |

### Credentials via .env

After setup, store API credentials in your project's `.env` file (never committed to git):

| Tracker | Required Variables |
|---------|--------------------|
| Azure DevOps | `AZURE_DEVOPS_EXT_PAT`, org/project in skill files |
| Jira | `JIRA_API_TOKEN`, `JIRA_EMAIL`, domain in skill files |
| Linear | `LINEAR_API_KEY` |
| GitHub Issues | Uses `gh` CLI (already authenticated) |

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
| `docs/troubleshooting.md` | Common issues: hooks, placeholders, Windows paths, MCP, agents |
| `docs/contributing.md` | How to extend the framework — parity rule, adding skills/agents/rules/hooks, testing workflow |
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
│   ├── agents/                  # 36 AI agent definitions
│   │   ├── architect.md         # System design, patterns, scalability
│   │   ├── code-reviewer.md     # Bugs, security, performance in diffs (broad sweep)
│   │   ├── code-smell-reviewer.md   # Smells specialist — cites `code-smells` rule
│   │   ├── dry-reviewer.md          # Duplication specialist — cites `dry` rule
│   │   ├── purity-reviewer.md       # Pure-function specialist — cites `purity` rule
│   │   ├── complexity-reviewer.md   # Complexity specialist — cites `complexity` rule
│   │   ├── frontend-architecture-reviewer.md  # FE structure — cites `frontend-architecture` rule
│   │   ├── architecture-reviewer.md           # Layering/dependency direction — cites `architecture-layering` rule
│   │   ├── api-layering-reviewer.md           # Controller/service/repo — cites `api-layering` rule
│   │   ├── crypto-reviewer.md                 # OWASP A02 — cites `crypto` rule
│   │   ├── solid-reviewer.md                  # OCP/LSP/ISP/DIP — cites `solid` rule
│   │   ├── concurrency-reviewer.md            # Races, async, locks — cites `concurrency` rule
│   │   ├── observability-reviewer.md          # OWASP A09 — cites `observability` rule
│   │   ├── supply-chain-reviewer.md           # OWASP A06+A08 — cites `supply-chain` rule
│   │   ├── security-auditor.md  # OWASP audit, credentials, deps
│   │   ├── refactor-advisor.md  # Duplication, complexity, structure
│   │   ├── devops-engineer.md   # CI/CD, containers, infrastructure
│   │   ├── ui-ux-reviewer.md    # Accessibility, design, responsiveness
│   │   ├── performance-optimizer.md  # Bundle, queries, caching
│   │   ├── api-designer.md      # Endpoint design, schemas, DX
│   │   ├── database-architect.md # Schema, indexes, migrations
│   │   ├── test-writer.md       # Test generation
│   │   ├── documentation-writer.md  # API docs, guides
│   │   ├── requirements-clarifier.md          # Planning: ambiguity, open questions
│   │   ├── scope-decomposer.md                # Planning: atomic steps, sequencing
│   │   ├── risk-assessor.md                   # Planning: rollback, blast radius, migration risk
│   │   ├── test-strategy-planner.md           # Planning: test levels per step
│   │   ├── scaffold-implementer.md            # Build phase 1: skeleton
│   │   ├── happy-path-implementer.md          # Build phase 2: core logic
│   │   ├── edge-case-implementer.md           # Build phase 3: validation, errors, edges
│   │   ├── refactor-pass-implementer.md       # Build phase 6: apply quality rules
│   │   ├── framework-improver.md              # Meta: self-improvement
│   │   ├── review-coordinator.md              # Meta: synthesizes reviewer findings, persists state
│   │   ├── planner-coordinator.md             # Meta: orchestrates planning specialists
│   │   ├── build-coordinator.md               # Meta: orchestrates build phases
│   │   └── project-setup.md                   # Meta: first-time onboarding (15-layer detection)
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
│   │   ├── error-handling.md
│   │   ├── auth-security.md
│   │   ├── data-protection.md
│   │   ├── design-system.md
│   │   ├── code-smells.md                # Cited by `code-smell-reviewer`
│   │   ├── dry.md                        # Cited by `dry-reviewer`
│   │   ├── purity.md                     # Cited by `purity-reviewer`
│   │   ├── complexity.md                 # Cited by `complexity-reviewer`
│   │   ├── frontend-architecture.md      # Cited by `frontend-architecture-reviewer`
│   │   ├── architecture-layering.md      # Cited by `architecture-reviewer`
│   │   ├── api-layering.md               # Cited by `api-layering-reviewer`
│   │   ├── crypto.md                     # Cited by `crypto-reviewer` (OWASP A02)
│   │   ├── solid.md                      # Cited by `solid-reviewer`
│   │   ├── concurrency.md                # Cited by `concurrency-reviewer`
│   │   ├── observability.md              # Cited by `observability-reviewer` (OWASP A09)
│   │   ├── supply-chain.md               # Cited by `supply-chain-reviewer` (OWASP A06+A08)
│   │   └── secrets-management.md         # Cited by `security-auditor`
│   ├── hooks/                   # Lifecycle scripts
│   │   ├── guardrails.sh        # PreToolUse: block dangerous ops
│   │   ├── post-edit-sync.sh    # PostToolUse: flag docs needing sync
│   │   ├── session-start.sh     # SessionStart: branch + env health checks
│   │   ├── session-stop.sh      # SessionEnd: audio notification
│   │   ├── post-coding-review.sh # SessionEnd: nudge /team review after coding
│   │   └── pre-commit.sh        # Git pre-commit: secret scan + size guard
│   └── statusline/              # Custom status bar
├── skills/
│   ├── _template/               # Blueprint for new skills
│   ├── develop/                 # Development cycle (memory-aware)
│   ├── plan/                    # Multi-agent planning (planner-coordinator)
│   ├── build/                   # Multi-agent implementation (build-coordinator)
│   ├── iterative-review/        # Plan → code → review → re-code loop with state
│   ├── setup/                   # First-time onboarding (15-layer detection via project-setup agent)
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
│   ├── mock-endpoint/           # Mock API endpoints
│   └── scaffold-design-system/  # Design system scaffolding
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
