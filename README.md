# Claude Code Framework

Claude Code is Anthropic's CLI tool for AI-assisted software development. This framework extends it with a production-grade development pipeline -- reusable skills, workflow orchestration, integration adapters, and persistent memory -- that reduces human touchpoints to just two per feature: story approval and code review.

**Prerequisites:** [Claude Code](https://docs.anthropic.com/en/docs/claude-code) installed. GitHub CLI (`gh`) required for CI/CD features.

## Architecture

Three separable layers:

| Layer | What | Examples | Portable? |
|-------|------|----------|-----------|
| **Workflow skills** | Development lifecycle patterns | `/develop`, `/validate`, `/factory`, `/check-readiness` | Yes -- core of this framework |
| **Integration adapters** | Connect to external systems | ADO/Jira/Linear, Slack/Teams, GitHub Actions/GitLab CI | Swappable -- configure per project |
| **Domain knowledge** | Project-specific references | Object inventories, API specs, business rules | Project-specific -- you build these |

### Pipeline

```
SA/PM drafts story -> AI readiness gate -> AI implements -> AI validates -> PR -> CI deploys -> human reviews -> merge -> deploy
```

### Skill Chaining (Factory Pipeline)

```
/draft-story (architect resolves questions)
    -> Ticket "Ready for Sprint"
    |
/factory TICKET-xxx
    |
+----------------------+
|  READINESS GATE      | -> FAIL: return to architect with gap report
|  /check-readiness    | -> PASS: continue
+----------+-----------+
           |
+----------------------+
|  IMPLEMENT           | /develop (phases 1-5)
|  + VALIDATE          | /validate (code standards)
+----------+-----------+
           |
+----------------------+
|  COMMIT & PR         | Push + create PR (triggers CI)
+----------+-----------+
           | (CI/CD)
+----------------------+
|  DEPLOY TO TEST ENV  | CI workflow deploys, posts link
+----------+-----------+
           |
+----------------------+
|  HUMAN REVIEW        | Reviewer tests in deployed env
+----------+-----------+
           |
+----------------------+
|  MERGE & DEPLOY      | Auto-merge -> deploy to staging/prod
+----------------------+
```

## Quick Start

There are two setup phases: scaffolding (script) and onboarding (conversational).

### Phase 1: Framework Setup

Run the setup wizard from your project root:

```bash
# Linux / macOS / Git Bash
cd your-project/
bash ~/Developer/claude-code-framework/setup.sh

# Windows PowerShell
cd your-project/
& ~/Developer/claude-code-framework/setup.ps1
```

The wizard asks about your project type, work item tracker, CI/CD platform, base branch, and notification system. It then:

1. **Renames your default branch** to match your chosen base branch (e.g., `master` → `main`) and updates the GitHub default
2. **Copies and configures skills** -- replaces adapter placeholders with your specific tools
3. **Generates project files:**
   - `.claude/skills/` -- 14 workflow skills adapted to your stack
   - `.claude/settings.local.json` -- auto-permissions so Claude doesn't prompt for common commands
   - `CLAUDE.md` -- project instructions with documentation knowledge base rules and placeholder sections
   - `.github/workflows/` -- CI/CD templates (if GitHub Actions)
   - `.claude/skills/fetch-docs/references/INDEX.md` -- empty knowledge base index, ready to accumulate docs

This gives you the file structure. The project-specific context comes next.

### Phase 2: First Conversation Onboarding

After `setup.sh` scaffolds the project, the generated `CLAUDE.md` includes an onboarding section. The first time you open Claude Code in that project, Claude detects that project context is incomplete and walks you through a guided setup conversation:

- **Tech stack** -- languages, frameworks, key libraries, runtime versions
- **Development workflow** -- branching strategy, PR process, code review conventions
- **CI/CD pipeline** -- GitHub Actions, GitLab CI, or other; how builds and checks run
- **Environments** -- dev, staging, production; names, aliases, URLs
- **Deployment process** -- manual, auto-on-merge, approval gates, rollback procedure
- **External integrations** -- work item tracker credentials, notification channels, monitoring systems

Claude saves the answers to memory files (`~/.claude/projects/{path}/memory/`) so every future conversation starts fully context-aware. You only answer these questions once. If your setup changes, update the memory files or re-answer when prompted.

After the guided questions, Claude offers to scan your codebase and build the initial knowledge base (data model, API surface, patterns, conventions). This feeds into Phase 3.

### Phase 3: Build Your Knowledge Base

The framework's power scales with how much it knows about your project. After onboarding captures your workflow and environment, you build a local knowledge base -- structured reference documents that Claude reads when implementing features, resolving conflicts, or validating code.

**What goes in the knowledge base:**

| Category | What to Document | How Claude Uses It |
|----------|-----------------|-------------------|
| **Data model** | Entities, fields, relationships, constraints | Knows your schema when implementing features |
| **API surface** | Routes, methods, parameters, auth requirements | Generates correct API calls and handlers |
| **Patterns & conventions** | Error handling, logging, naming, file structure | Follows your patterns instead of inventing its own |
| **Business rules** | Domain logic, validation rules, edge cases | Implements correct behavior without guessing |
| **Architecture decisions** | ADRs, why things are built a certain way | Respects existing design choices |
| **External integrations** | Third-party APIs, webhooks, data flows | Knows boundaries and contracts |

**How to build it:**

```bash
# Create a domain skill for your project's core domain
mkdir -p .claude/skills/my-domain/references/

# Use /add-reference to scan your codebase and generate structured docs
/add-reference my-domain entities        # Scan data models, schemas, types
/add-reference my-domain api-endpoints   # Document routes, controllers, handlers
/add-reference my-domain patterns        # Extract error handling, logging, auth patterns
/add-reference my-domain config          # Document config keys, env vars, feature flags

# Add domain knowledge that isn't in the code
# (business rules, external API docs, compliance requirements)
# Write these manually into .claude/skills/my-domain/references/
```

The knowledge base lives in `.claude/skills/{domain}/references/*.md` and is read by skills like `/develop`, `/validate`, and `/merge-resolve` to make context-aware decisions. It grows over time -- run `/add-reference` again after major changes to keep it current.

### Documentation Knowledge Base (automatic)

In addition to the domain knowledge you build manually, the framework automatically persists any documentation that enters a conversation -- context7 lookups, web searches, user-pasted docs, shared URLs, or API specs. These are saved to `.claude/skills/fetch-docs/references/` with an index file (`INDEX.md`) that acts as a lookup table.

This means:
- **First conversation** fetches Next.js App Router docs → saved to knowledge base
- **Every future conversation** reads from cache instead of re-fetching
- **User-provided docs** (internal APIs, unreachable sources) are tagged so future updates ask the user rather than trying to fetch
- **Staleness** is tracked — docs older than 30 days are re-fetched when the topic comes up

The knowledge base compounds over time. The more conversations happen, the richer the local docs become.

### Auto-Permissions

The generated `.claude/settings.local.json` pre-allows common commands (`npm`, `git`, `gh`, `python`, `curl`, `kill`, etc.) and all Claude Code tools (`Read`, `Edit`, `Write`, `Agent`, `Skill`, etc.). This means Claude won't prompt you for permission on routine operations — it just runs them. You can tighten or loosen the list per project.

### 4. Start Using

| You are a... | Start with | Purpose |
|--------------|------------|---------|
| Architect/PM | `/draft-story` | Requirements -> implementation-ready stories |
| Developer | `/develop TICKET-123` | Full dev cycle: implement, validate, PR |
| Developer | `/validate` | Validate code against project standards |
| Any | `/factory TICKET-123` | End-to-end: readiness -> develop -> validate -> PR -> deploy |

## How It Works with Claude Code

The framework builds on Claude Code's native extension points:

- **Skills** live in `.claude/skills/`. Each skill is a directory containing a `SKILL.md` file with instructions Claude follows when the skill is invoked. Claude Code loads them automatically -- no plugin system, no compilation.
- **`CLAUDE.md`** at the project root gives Claude persistent project-level instructions. It is read at the start of every conversation. This is where project conventions, commands, and workflow rules live.
- **Memory files** in `~/.claude/projects/{project-path}/memory/` persist across conversations. Skills read and write these files to accumulate context -- build fix patterns, environment aliases, user preferences, worktree conventions.
- **Skill chaining** -- skills can invoke other skills (e.g., `/factory` calls `/check-readiness`, then `/develop`, then `/validate`), spawn sub-agents for parallel work, and read/write memory to coordinate across steps.

The result: Claude starts every conversation knowing your project's stack, conventions, environments, and history. Skills encode the development lifecycle so a single command like `/factory TICKET-123` runs the full pipeline from readiness check through deployment.

## Skills Included

### Core Workflow Skills (portable)

| Skill | Purpose |
|-------|---------|
| `/develop` | Full development cycle: fetch ticket, analyze, implement, validate, PR. Memory-aware (worktree prefs, env aliases, build fixes) |
| `/validate` | Code standards + project conventions checking |
| `/factory` | End-to-end pipeline: readiness -> develop -> validate -> PR -> CI deploy. Produces execution logs |
| `/check-readiness` | Validates a ticket is implementation-ready before `/develop` |
| `/draft-story` | Create stories from requirements or design docs |
| `/refine-story` | Improve existing stories with gap analysis |
| `/merge-resolve` | AI-powered merge conflict resolution -- reads both features' story docs to understand intent, resolves per file type |
| `/error-analyze` | Triage errors from monitoring, create tickets |
| `/ai-update` | Branch + PR for AI process file changes |
| `/add-reference` | Add/update domain knowledge references |
| `/update-tracker` | Push story docs back to work item tracker |
| `/deploy` | Orchestrate deployments to environments |
| `/fetch-docs` | Fetch & persist library/API documentation to an indexed knowledge base. Auto-triggered when any docs enter the conversation |
| `/mock-endpoint` | Create contracts, mock fixtures, service wrappers, and tests for external API integrations. Prevents AI from hitting real services during development |

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
| Vercel | `adapters/vercel.env` | `vercel deploy`, preview URLs |
| AWS (CDK/SAM) | `adapters/aws.env` | `cdk deploy`, `sam deploy` |
| Docker/K8s | `adapters/docker.env` | `docker build`, `kubectl apply` |
| Generic | `adapters/generic.env` | Custom deploy script path |

## Memory System

The framework sets up Claude Code's persistent memory:

```
~/.claude/projects/{project-path}/memory/
+-- MEMORY.md          # Index (auto-loaded each conversation)
+-- user_role.md       # Who you are, preferences
+-- feedback_*.md      # Corrections and guidance
+-- project_*.md       # Ongoing work context
+-- reference_*.md     # External system pointers
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
| `docs/architecture.md` | System design -- layers, skill format, adapter pattern, memory lifecycle |
| `docs/skill-authoring.md` | How to write new skills -- format, patterns, categories, testing |
| `docs/sub-agent-orchestration.md` | How skills spawn parallel agents, pass context, run background tasks |
| `docs/memory-patterns.md` | How skills read/write memory for smarter behavior across conversations |
| `docs/examples/` | Example configs for various project types (Next.js, Python API, etc.) |

## Files Reference

```
claude-code-framework/
+-- README.md                    # This file
+-- setup.sh                     # Interactive setup wizard (Linux/macOS/Git Bash)
+-- setup.ps1                    # Interactive setup wizard (Windows PowerShell)
+-- .gitignore
+-- templates/
|   +-- CLAUDE.md.template       # Project instructions template
|   +-- settings.local.json      # Default Claude Code permissions
|   +-- statusline/              # Custom status bar
|   +-- hooks/                   # Session hooks (sound on complete)
+-- skills/
|   +-- _template/               # Blueprint for new skills
|   +-- develop/                 # Development cycle (memory-aware)
|   +-- validate/                # Code validation
|   +-- draft-story/             # Story creation
|   +-- refine-story/            # Story refinement + templates
|   +-- check-readiness/         # Readiness gate (auto/semi-auto classification)
|   +-- factory/                 # End-to-end pipeline (execution logging)
|   +-- merge-resolve/           # AI merge conflict resolution
|   +-- error-analyze/           # Error triage (interactive + CI mode)
|   +-- ai-update/               # AI process updates
|   +-- add-reference/           # Knowledge management
|   +-- fetch-docs/              # Documentation persistence (indexed knowledge base)
|   +-- mock-endpoint/           # External API contracts, mocks, and service wrappers
|   +-- update-tracker/          # Work item sync
|   +-- deploy/                  # Deployment orchestration
+-- workflows/                   # CI/CD templates
|   +-- factory-validate.yml     # Deploy PR to test env
|   +-- factory-auto-merge.yml   # Auto-merge after approval
|   +-- factory-deploy.yml       # Deploy to staging (auto/semi-auto classification)
|   +-- factory-cleanup.yml      # Tear down ephemeral environments
+-- memory/                      # Memory system templates
+-- docs/
    +-- architecture.md          # System design
    +-- skill-authoring.md       # How to write skills
    +-- sub-agent-orchestration.md  # Parallel agents, chaining, background tasks
    +-- memory-patterns.md       # Memory-aware skill patterns
    +-- examples/                # Example configs per project type
```
