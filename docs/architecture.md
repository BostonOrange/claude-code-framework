# Framework Architecture

## System Design

```
┌──────────────────────────────────────────────────────────────────────┐
│                        Claude Code Framework                         │
├──────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  ┌────────────────────────────────────────────────────────────────┐  │
│  │  CLAUDE.md — Project Instructions                              │  │
│  │  Loaded every conversation. Defines coding standards,          │  │
│  │  branching strategy, deployment patterns, skill catalog.       │  │
│  └────────────────────────────────────────────────────────────────┘  │
│                                                                      │
│  ┌─────────────────┐  ┌──────────────┐  ┌──────────────────────┐     │
│  │ Workflow        │  │ Integration  │  │ Domain Knowledge     │     │
│  │ Skills (17)     │  │ Adapters     │  │ Skills               │     │
│  │                 │  │              │  │                      │     │
│  │ /develop        │  │ Tracker:     │  │ /your-domain         │     │
│  │ /validate       │  │  ADO/Jira/   │  │   references/        │     │
│  │ /factory        │  │  Linear/GH   │  │     objects.md       │     │
│  │ /check-ready    │  │              │  │     api-specs.md     │     │
│  │ /draft-story    │  │ CI/CD:       │  │     patterns.md      │     │
│  │ /refine-story   │  │  GH Actions/ │  │                      │     │
│  │ /mock-endpoint  │  │  GitLab CI   │  │ /another-domain      │     │
│  │ /merge-resolve  │  │              │  │   references/        │     │
│  │ /fetch-docs     │  │ Deploy:      │  │     ...              │     │
│  │ /update-tracker │  │  SF/AWS/     │  │                      │     │
│  │ /error-analyze  │  │  Vercel/K8s  │  │                      │     │
│  │ /add-reference  │  │              │  │                      │     │
│  │ /deploy         │  │ Notify:      │  │                      │     │
│  │ /team           │  │  Slack/Teams │  │                      │     │
│  │ /improve        │  │              │  │                      │     │
│  │ /ai-update      │  │              │  │                      │     │
│  │ /scaffold-ds    │  │              │  │                      │     │
│  └─────────────────┘  └──────────────┘  └──────────────────────┘     │
│                                                                      │
│  ┌──────────────┐  ┌──────────────┐  ┌─────────────────────────┐     │
│  │ Agents (12)  │  │ Commands     │  │ Rules & Hooks           │     │
│  │              │  │              │  │                         │     │
│  │ architect    │  │ /quick-test  │  │ Rules:                  │     │
│  │ code-reviewer│  │ /lint-fix    │  │  api-routes             │     │
│  │ security-    │  │ /check-types │  │  components             │     │
│  │   auditor    │  │ /branch-     │  │  tests                  │     │
│  │ refactor-    │  │   status     │  │  database               │     │
│  │   advisor    │  │ /changelog   │  │  error-handling         │     │
│  │ devops-eng   │  │ /dep-check   │  │  config-files           │     │
│  │ ui-ux-review │  │              │  │  auth-security          │     │
│  │ perf-optim   │  │ Teams:       │  │  data-protection        │     │
│  │ api-designer │  │  /team review│  │  design-system          │     │
│  │ db-architect │  │  /team arch  │  │                         │     │
│  │ test-writer  │  │  /team rel   │  │ Hooks:                  │     │
│  │ doc-writer   │  │  /team full  │  │  guardrails             │     │
│  │ fw-improver  │  │  /team custom│  │  post-edit-sync         │     │
│  │              │  │              │  │  session-start          │     │
│  │              │  │              │  │  session-stop           │     │
│  │              │  │              │  │  post-coding-review     │     │
│  │              │  │              │  │  pre-commit             │     │
│  │              │  │              │  │ Self-Improvement:       │     │
│  │              │  │              │  │  /improve               │     │
│  └──────────────┘  └──────────────┘  └─────────────────────────┘     │
│                                                                      │
│  ┌────────────────────────────────────────────────────────────────┐  │
│  │  MCP Servers — .mcp.json                                       │  │
│  │  Context7: live library docs. Used proactively by skills       │  │
│  │  (/develop, /draft-story, /mock-endpoint, /refine-story)       │  │
│  │  and agents (architect, api-designer, test-writer, etc.)       │  │
│  └────────────────────────────────────────────────────────────────┘  │
│                                                                      │
│  ┌────────────────────────────────────────────────────────────────┐  │
│  │  Memory System — ~/.claude/projects/{path}/memory/             │  │
│  │  Persists: user preferences, feedback, project context,        │  │
│  │  external references. Loaded via MEMORY.md index.              │  │
│  └────────────────────────────────────────────────────────────────┘  │
│                                                                      │
│  ┌────────────────────────────────────────────────────────────────┐  │
│  │  CI/CD Workflows — .github/workflows/ (or .gitlab-ci)          │  │
│  │  factory-validate → factory-auto-merge → factory-deploy        │  │
│  └────────────────────────────────────────────────────────────────┘  │
│                                                                      │
└──────────────────────────────────────────────────────────────────────┘
```

## How Skills Work

### Skill File Format

Every skill is a directory under `.claude/skills/` containing:

```
skill-name/
├── SKILL.md              # Skill definition (YAML frontmatter + markdown instructions)
├── references/           # Domain knowledge, inventories, specs
│   ├── objects.md
│   └── api-specs.md
└── examples/             # Example outputs for few-shot learning
    └── example-output.md
```

**SKILL.md format:**
```markdown
---
name: skill-name
description: One-line purpose. Used by Claude to decide when to invoke.
---

# Skill Title

{Detailed instructions for Claude when this skill is invoked}

## Usage
{How to invoke: `/skill-name TICKET-123`}

## Process
{Step-by-step phases}

## Edge Cases
{Table of scenarios and behaviors}

## Related Skills
{Links to skills this one chains with}
```

### Skill Chaining

Skills reference each other by name. The factory skill orchestrates:

```
/factory → /check-readiness → /develop → /validate → commit → PR → CI
```

Each skill is self-contained but aware of the pipeline context via flags:

| Flag | Meaning | Effect |
|------|---------|--------|
| `--factory` | Invoked from factory pipeline | All interactive gates auto-default |
| `--ci` | Running in CI/unattended mode | No user prompts, auto-create tickets |

### Skill Categories

| Category | Skills | Characteristics |
|----------|--------|----------------|
| **Lifecycle** | develop, validate, factory | Multi-phase, long-running, chain other skills |
| **Planning** | draft-story, refine-story, check-readiness | Analyze content, produce structured reports |
| **Integration** | update-tracker, deploy, error-analyze, fetch-docs, mock-endpoint, scaffold-design-system | Call external APIs, modify external state, scaffold project assets |
| **Collaboration** | team, merge-resolve | Orchestrate agents or resolve conflicts |
| **Meta** | ai-update, add-reference, improve | Modify the AI system itself |

## Integration Adapter Pattern

Skills use placeholder tokens for external system operations:

```markdown
## Fetch Ticket

{{TRACKER_FETCH_COMMAND}}

Extract:
- {{TRACKER_TITLE_FIELD}}
- {{TRACKER_STATE_FIELD}}
- {{TRACKER_DESCRIPTION_FIELD}}
- {{TRACKER_ACCEPTANCE_CRITERIA_FIELD}}
```

`setup.sh` replaces these with concrete implementations:

**ADO adapter:**
```bash
PAT=$(grep AZURE_DEVOPS_EXT_PAT .env | cut -d= -f2)
curl -s "https://dev.azure.com/{org}/{project}/_apis/wit/workitems/{id}?api-version=7.1" -u ":${PAT}"
```

**Jira adapter:**
```bash
curl -s "https://{domain}.atlassian.net/rest/api/3/issue/{key}" \
  -H "Authorization: Basic $(echo -n {email}:{api_token} | base64)"
```

**GitHub Issues adapter:**
```bash
gh issue view {number} --json title,body,state,labels
```

## Memory System Design

### Why Memory?

Claude Code conversations are stateless — each new conversation starts fresh. Memory bridges conversations:

| Without Memory | With Memory |
|---------------|-------------|
| "What org do I deploy to?" every time | Knows your sandbox aliases |
| Makes same mistake twice | Learns from corrections |
| Generic responses | Tailored to your role and preferences |
| No project context | Knows ongoing work, deadlines, decisions |

### Memory Types

| Type | Purpose | Example |
|------|---------|---------|
| `user` | Role, preferences, expertise | "Senior backend dev, new to React" |
| `feedback` | Corrections and guidance | "Don't mock the database in integration tests" |
| `project` | Ongoing work context | "Merge freeze starts March 5 for mobile release" |
| `reference` | Pointers to external systems | "Pipeline bugs tracked in Linear project INGEST" |

### Memory Lifecycle

```
Conversation starts → MEMORY.md loaded → relevant memories read
    ↓
During conversation → new information learned → memory saved/updated
    ↓
Conversation ends → memories persist in files
    ↓
Next conversation → MEMORY.md loaded → accumulated knowledge available
```

## Factory Pipeline Design

### Pipeline Stages

```
1. READINESS GATE (/check-readiness)
   - Scan for TBDs, vague criteria, missing specs
   - Classify: auto (fully deployable) vs semi-auto (needs manual config)
   - FAIL → return to architect with gap report
   - PASS → continue

2. BRANCH & SCAFFOLD
   - Create feature branch (worktree if preferred)
   - Generate boilerplate from ticket spec
   - Deterministic, no LLM needed

3. IMPLEMENT (/develop Phase 4)
   - LLM generates code from spec
   - Follow project coding standards (from CLAUDE.md)
   - Verify against domain references

4. VALIDATE (/validate)
   - Run project-specific code checks
   - Formatting, conventions, test coverage
   - Max 3 fix attempts

5. COMMIT & PR
   - Stage specific files
   - Create PR with ticket link
   - Add pipeline label (triggers CI)

6. CI DEPLOY (GitHub Actions / GitLab CI)
   - Deploy to test environment
   - Run tests
   - Post environment link as PR comment

7. HUMAN REVIEW
   - Reviewer tests in deployed environment
   - Approve → auto-merge → deploy to staging

8. POST-MERGE DEPLOY
   - Deploy to staging/production
   - Notify team (Slack/Teams)
   - Update ticket state
```

### Pipeline Classification

| Type | Meaning | Deploy Behavior |
|------|---------|-----------------|
| **Auto** | All changes deployable via CI/CD | Full automation through staging |
| **Semi-auto** | Requires manual configuration | Pauses, notifies manual steps, human confirms |

### Halt Conditions

| Condition | Action |
|-----------|--------|
| Readiness gate fails | Return to architect, post gap report |
| Code standards fail after 3 attempts | Halt, notify team |
| Deployment failure | Post error as PR comment, developer fixes |
| Merge conflict | Attempt auto-resolve, halt if complex |

## File Organization

### Project-Level (in repo)

```
your-project/
├── CLAUDE.md                          # Project instructions (the "brain")
├── .mcp.json                          # MCP servers (Context7 docs)
├── .claude/
│   ├── settings.local.json            # Permissions & model config
│   ├── agents/                        # 37 AI teammate definitions
│   │   ├── architect.md               # System design, patterns
│   │   ├── code-reviewer.md           # Bugs, security in diffs (broad sweep)
│   │   ├── code-smell-reviewer.md     # Smells specialist — cites `code-smells`
│   │   ├── dry-reviewer.md            # Duplication specialist — cites `dry`
│   │   ├── purity-reviewer.md         # Pure-function specialist — cites `purity`
│   │   ├── complexity-reviewer.md     # Complexity specialist — cites `complexity`
│   │   ├── frontend-architecture-reviewer.md  # FE structure — cites `frontend-architecture`
│   │   ├── architecture-reviewer.md           # Layering — cites `architecture-layering`
│   │   ├── api-layering-reviewer.md           # API structure — cites `api-layering`
│   │   ├── crypto-reviewer.md                 # OWASP A02 — cites `crypto`
│   │   ├── solid-reviewer.md                  # OCP/LSP/ISP/DIP — cites `solid`
│   │   ├── concurrency-reviewer.md            # Races, async, locks — cites `concurrency`
│   │   ├── observability-reviewer.md          # OWASP A09 — cites `observability`
│   │   ├── supply-chain-reviewer.md           # OWASP A06+A08 — cites `supply-chain`
│   │   ├── security-auditor.md        # OWASP audit
│   │   ├── refactor-advisor.md        # Cross-cutting refactor (broader than dry-reviewer)
│   │   ├── devops-engineer.md         # CI/CD, infrastructure
│   │   ├── ui-ux-reviewer.md          # Accessibility, design
│   │   ├── performance-optimizer.md   # Bundle, queries, caching
│   │   ├── api-designer.md            # Endpoint design, schemas
│   │   ├── database-architect.md      # Schema, indexes, migrations
│   │   ├── test-writer.md             # Test generation (build phase 4)
│   │   ├── documentation-writer.md    # API docs, guides (build phase 5)
│   │   ├── requirements-clarifier.md          # Planning: ambiguity, open questions
│   │   ├── scope-decomposer.md                # Planning: atomic steps, sequencing
│   │   ├── risk-assessor.md                   # Planning: rollback, blast radius, migration risk
│   │   ├── test-strategy-planner.md           # Planning: test levels per step
│   │   ├── scaffold-implementer.md            # Build phase 1: skeleton
│   │   ├── happy-path-implementer.md          # Build phase 2: core logic
│   │   ├── edge-case-implementer.md           # Build phase 3: validation, errors, edges
│   │   ├── refactor-pass-implementer.md       # Build phase 6: apply quality rules
│   │   ├── framework-improver.md              # Meta: self-improvement
│   │   ├── planner-coordinator.md             # Meta: orchestrates planning specialists
│   │   ├── build-coordinator.md               # Meta: orchestrates build phases
│   │   ├── review-coordinator.md              # Meta: synthesizes reviewer findings, persists state
│   │   ├── project-setup-detector.md          # Meta: first-time onboarding read-only (17-layer detection)
│   │   └── project-setup-applier.md           # Meta: first-time onboarding write (allowlist + backup + audit log)
│   ├── commands/                      # One-word automations
│   │   ├── quick-test.md
│   │   ├── lint-fix.md
│   │   ├── check-types.md
│   │   ├── branch-status.md
│   │   ├── changelog.md
│   │   └── dep-check.md
│   ├── rules/                         # File-pattern-scoped guardrails
│   │   ├── api-routes.md
│   │   ├── components.md
│   │   ├── tests.md
│   │   ├── database.md
│   │   ├── config-files.md
│   │   ├── error-handling.md
│   │   ├── auth-security.md
│   │   ├── data-protection.md
│   │   ├── design-system.md
│   │   ├── code-smells.md             # Cited by code-smell-reviewer
│   │   ├── dry.md                     # Cited by dry-reviewer
│   │   ├── purity.md                  # Cited by purity-reviewer
│   │   ├── complexity.md              # Cited by complexity-reviewer
│   │   ├── frontend-architecture.md   # Cited by frontend-architecture-reviewer
│   │   ├── architecture-layering.md   # Cited by architecture-reviewer
│   │   ├── api-layering.md            # Cited by api-layering-reviewer
│   │   ├── crypto.md                  # Cited by crypto-reviewer (OWASP A02)
│   │   ├── solid.md                   # Cited by solid-reviewer
│   │   ├── concurrency.md             # Cited by concurrency-reviewer
│   │   ├── observability.md           # Cited by observability-reviewer (OWASP A09)
│   │   ├── supply-chain.md            # Cited by supply-chain-reviewer (OWASP A06+A08)
│   │   └── secrets-management.md      # Cited by security-auditor
│   ├── hooks/                         # Lifecycle scripts
│   │   ├── guardrails.sh              # PreToolUse: block dangerous ops
│   │   ├── post-edit-sync.sh          # PostToolUse: flag docs needing sync
│   │   ├── session-start.sh           # SessionStart: branch + env health
│   │   ├── session-stop.sh            # SessionEnd: audio notification
│   │   ├── post-coding-review.sh      # SessionEnd: nudge /team review
│   │   └── pre-commit.sh              # Git pre-commit: secret scan + size guard
│   ├── skills/                        # Multi-phase workflows
│   │   ├── develop/SKILL.md
│   │   ├── validate/SKILL.md
│   │   ├── factory/SKILL.md
│   │   ├── team/SKILL.md              # Agent team spawning
│   │   ├── setup/SKILL.md             # First-time onboarding (15-layer detection)
│   │   ├── improve/SKILL.md           # Framework self-improvement
│   │   ├── your-domain/
│   │   │   ├── SKILL.md
│   │   │   └── references/
│   │   └── ...
│   └── statusline/                    # Status bar config
├── .github/workflows/                 # CI/CD
│   ├── factory-validate.yml
│   └── ...
└── docs/stories/                      # Story documentation
    └── TICKET-xxx/
        ├── story.md
        ├── solutions-components.md
        ├── how-to-test.md
        └── manual-steps.md
```

See [agents-commands-rules.md](agents-commands-rules.md) for details on when to use each type.

### User-Level (outside repo)

```
~/.claude/
├── settings.json                      # Global settings (hooks, voice, effort)
├── hooks/                             # Session hooks
├── statusline-command.sh              # Status bar command
└── projects/{project-path}/
    └── memory/
        ├── MEMORY.md                  # Memory index
        └── *.md                       # Individual memory files
```

## Model Configuration Hierarchy

The framework uses a deliberate model hierarchy to balance cost and capability:

| Level | File | Model | Purpose |
|-------|------|-------|---------|
| **User-level** | `~/.claude/settings.json` | `opus` | Global default for all projects |
| **Project-level** | `.claude/settings.local.json` | `sonnet` | Overrides user-level for the main conversation |
| **Agent definitions** | `.claude/agents/*.md` | `opus` | Each agent specifies its own model in YAML frontmatter |

This is intentional:

- **Main conversation** uses the faster, cheaper model (`sonnet`) for routine tasks like running commands, reading files, and answering questions. The project-level setting overrides the user-level default.
- **Specialized agents** always run as `opus` regardless of the project-level default. Agents perform complex analysis (security audits, architecture reviews, code generation) where the most capable model produces meaningfully better results.
- **User-level** sets `opus` as the global fallback so that projects without a `settings.local.json` still get the best model.

To change this behavior, edit `settings.local.json` to set a different project-level model, or edit individual agent `.md` files to change their model.
