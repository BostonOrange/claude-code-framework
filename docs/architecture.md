# Framework Architecture

## System Design

```
┌─────────────────────────────────────────────────────────────────┐
│                     Claude Code Framework                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │  CLAUDE.md — Project Instructions                         │   │
│  │  Loaded every conversation. Defines coding standards,     │   │
│  │  branching strategy, deployment patterns, skill catalog.  │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                  │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────┐  │
│  │ Workflow      │  │ Integration  │  │ Domain Knowledge     │  │
│  │ Skills        │  │ Adapters     │  │ Skills               │  │
│  │               │  │              │  │                      │  │
│  │ /develop      │  │ Tracker:     │  │ /your-domain         │  │
│  │ /validate     │  │  ADO/Jira/   │  │   references/        │  │
│  │ /factory      │  │  Linear/GH   │  │     objects.md       │  │
│  │ /check-ready  │  │              │  │     api-specs.md     │  │
│  │ /draft-story  │  │ CI/CD:       │  │     patterns.md      │  │
│  │ /refine-story │  │  GH Actions/ │  │                      │  │
│  │ /error-analyze│  │  GitLab CI   │  │ /another-domain      │  │
│  │ /ai-update    │  │              │  │   references/        │  │
│  │ /add-reference│  │ Deploy:      │  │     ...              │  │
│  │               │  │  AWS/Vercel/ │  │                      │  │
│  │               │  │  Docker/K8s  │  │                      │  │
│  │               │  │              │  │                      │  │
│  │               │  │ Notify:      │  │                      │  │
│  │               │  │  Slack/Teams │  │                      │  │
│  └──────────────┘  └──────────────┘  └──────────────────────┘  │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │  Memory System — ~/.claude/projects/{path}/memory/        │   │
│  │  Persists: user preferences, feedback, project context,   │   │
│  │  external references. Loaded via MEMORY.md index.         │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │  CI/CD Workflows — .github/workflows/ (or .gitlab-ci)     │   │
│  │  factory-validate → factory-auto-merge → factory-deploy   │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
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
| **Integration** | update-tracker, deploy, error-analyze | Call external APIs, modify external state |
| **Meta** | ai-update, add-reference | Modify the AI system itself |

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
| "What environment do I deploy to?" every time | Knows your environment aliases |
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
├── CLAUDE.md                          # Project instructions
├── .claude/
│   ├── settings.local.json            # Permissions
│   ├── statusline/                    # Status bar config
│   └── skills/                        # All skills
│       ├── develop/SKILL.md
│       ├── validate/SKILL.md
│       ├── factory/SKILL.md
│       ├── your-domain/
│       │   ├── SKILL.md
│       │   └── references/
│       └── ...
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
