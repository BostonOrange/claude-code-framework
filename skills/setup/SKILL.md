---
name: setup
description: First-time onboarding — run after `setup.sh` (or anytime you want to refine framework config to actual project state). Spawns project-setup agent for inventory + 15-layer detection, presents a proposal with tradeoff explanations and recommended defaults, collects user decisions, then re-spawns the agent to apply. Distinct from /improve (ongoing evolution); /setup owns the first run
---

# Setup — First-Time Onboarding

`setup.sh` puts the framework files on disk. `/setup` makes them fit *your* project.

The bash installer can only ask the eight questions it was built around (project type, tracker, CI/CD, base branch, notification, design system, etc.). `/setup` walks 15 layers — language, framework, build, test, type-check, format/lint, persistence, API style, frontend, design system, infra, CI/CD, tracker, notification, branch — and uses what's actually in the repo to pre-fill answers.

For each layer it can't auto-answer, it shows you the options, the tradeoffs, and a recommended default. You pick "default" or pick differently — no research required.

**Lifecycle distinction from `/improve`:** `/setup` is for the first run (or a re-baseline). `/improve` is for ongoing evolution as the project grows. `/setup` decides shape; `/improve` keeps it in tune.

## Usage

```
/setup                    — full onboarding pass; inventory → propose → confirm → apply
/setup --refresh          — re-run all 15 layers with existing values as the baseline
/setup --layer=<name>     — re-run a single layer (e.g., /setup --layer=ci-cd)
/setup --dry-run          — propose only; do not apply even after confirmation
```

Layer names: `language`, `framework`, `build`, `test`, `type-check`, `format-lint`, `persistence`, `api-style`, `frontend`, `design-system`, `infra`, `ci-cd`, `tracker`, `notification`, `branch`.

## Process

### Phase 1: Detect (read-only)

Spawn `project-setup` agent:

```
Run Phases 1–4 of your process. Inventory the repo, classify greenfield vs brownfield,
walk the 15 layers, and write the proposal to .claude/state/setup-proposal.md.
Do not apply changes.
```

The agent uses only local files (no network). It compiles an inventory, classifies the repo, and produces a per-layer detection + recommendation.

### Phase 2: Present Proposal

Read `.claude/state/setup-proposal.md` and surface a condensed view to the user:

```markdown
## Setup Proposal

**Mode:** brownfield (Next.js 15 + Postgres detected)

### Confirmed by detection (no input needed)
- Language: TypeScript
- Framework: Next.js 15 App Router
- Build: pnpm
- Test: vitest
- Type check: tsc --noEmit
- Format/Lint: eslint + prettier
- Persistence: Drizzle ORM
- API style: REST (Next.js route handlers)
- Frontend: React 18
- Design system: Tailwind + shadcn/ui
- Infra: Vercel (vercel.json present)
- CI/CD: GitHub Actions
- Branch: main

### Conflicts (need your decision)
1. <layer> — detection says X, existing CLAUDE.md says Y

### Open questions (detection silent)
1. Tracker — Azure DevOps / Jira / Linear / GitHub Issues / None?
2. Notification — Slack / Teams / Discord / None?

Reply with either "use defaults + Slack + GitHub Issues" or layer-by-layer answers.
```

Greenfield mode looks similar but each layer presents 2–4 options with tradeoffs, and the proposal ends with bootstrap commands for the user to run themselves.

### Phase 3: Collect Decisions

Wait for user reply. Common shapes:

- **"use defaults"** — every layer takes its recommended value; open questions still need answers.
- **"defaults + <X> + <Y>"** — defaults plus answers to the open questions.
- **Layer-by-layer** — explicit choice per layer.

Update `.claude/state/setup-proposal.md` in place with the resolved values under a `## Confirmed` section. If the user wants a `--dry-run`, stop here.

### Phase 4: Apply

Re-spawn `project-setup`:

```
--apply mode. Read .claude/state/setup-proposal.md (now with confirmed values).
Execute Phase 5: substitute placeholders, run the smoke check, write .claude/state/setup-applied.md.
Do not modify any layer not listed in the proposal.
```

### Phase 5: Verify

After the apply pass returns:

1. Run the smoke check yourself (don't trust the agent's report alone):
   ```bash
   grep -r "{{" .claude/ CLAUDE.md 2>/dev/null | grep -v ".git" | head -20
   ```
2. Confirm `.claude/state/setup-applied.md` exists and lists the changed files.
3. Show the user:
   - Which files changed
   - Which placeholders were intentionally left unfilled (e.g., backend-only projects keep `{{DESIGN_*}}` empty — that's fine)
   - The next recommended action

### Phase 6: Hand-off

Tell the user the next step:

- **Brownfield:** "Run `/develop TICKET-123` to try the dev cycle, or `/team review` to validate the framework picked up your conventions."
- **Greenfield:** "Run the bootstrap command shown above. After your first commit, run `/improve` to capture conventions that emerged during scaffolding."

## State Files

| File | Owner | Lifecycle |
|------|-------|-----------|
| `.claude/state/setup-proposal.md` | `project-setup` agent | Written in Phase 1; updated in Phase 3 with confirmations |
| `.claude/state/setup-applied.md` | `project-setup` agent | Written in Phase 4 (apply); audit trail of what changed |

Both live under `.claude/state/` (gitignored).

## When to Use `/setup` vs `/improve`

| Situation | Use |
|-----------|-----|
| Just ran `setup.sh` for the first time | `/setup` |
| Re-onboarding after a major stack change (e.g., switched ORMs, migrated to a new framework) | `/setup --refresh` |
| One layer is wrong (e.g., switched from npm to pnpm) | `/setup --layer=build` |
| Convention drift after weeks of development | `/improve` |
| Filling specific `{{...}}` placeholders that ended up unset | `/improve claude-md` |
| Adding new rule patterns based on actual file structure | `/improve rules` |

`/setup` is shape-deciding. `/improve` is shape-tuning. They don't overlap.

## Edge Cases

| Scenario | Behavior |
|----------|----------|
| `.claude/state/setup-applied.md` already exists | Tell user setup was already run; offer `--refresh` |
| Repo has no manifests / is empty | Greenfield mode; agent walks language → framework selection conversationally and ends with bootstrap commands |
| Existing CLAUDE.md is hand-written, not from this framework | Treat its content as user truth; only add framework-specific sections, don't replace |
| User picks a value that disagrees with strong detection | Honor the user; record the override in `setup-applied.md` so future `/improve` doesn't undo it |
| Apply pass leaves unexpected `{{...}}` | Surface to user; do not auto-fill |
| User aborts during Phase 3 | Proposal stays on disk with `incomplete: true`; next `/setup` resumes from there |
| Monorepo (multiple manifests) | Agent surfaces all detected stacks; user picks the primary; suggest re-running `/setup --layer` per sub-path later |

## Related

- `project-setup` agent — the agent this skill orchestrates (`templates/agents/project-setup.md`)
- `/improve` — ongoing evolution (different lifecycle)
- `framework-improver` agent — the agent `/improve` spawns
- `setup.sh` / `setup.ps1` — bash/PowerShell installers that placed the framework files; `/setup` refines what they generated
