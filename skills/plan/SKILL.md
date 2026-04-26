---
name: plan
description: Invoke the planner-coordinator on a story or task — spawns planning specialists in parallel (requirements-clarifier, scope-decomposer, risk-assessor, test-strategy-planner, plus architect/api-designer/database-architect when relevant) and produces .claude/state/plan-<branch>.md
---

# Plan — Multi-Agent Planning

A specialist-driven plan for the current branch's work. The `planner-coordinator` agent classifies scope, spawns the right planning specialists in parallel, and synthesizes their outputs into a single plan document.

## Usage

```
/plan                       — plan the current task using conversation context
/plan TICKET-123            — plan a tracked ticket; reads docs/stories/TICKET-123/story.md
/plan --refresh             — re-run planning even if a plan exists for this branch
/plan --scope=large         — override the auto-classified scope (forces all specialists)
```

## Process

### Phase 1: Read the Story

Source of the story:
- If a TICKET-id is passed, read `docs/stories/<TICKET-id>/story.md` (and any linked design docs)
- Otherwise, use the user's stated task from conversation context
- If neither is available, ask the user

### Phase 2: Spawn the Planner Coordinator

Spawn `planner-coordinator` as a sub-agent:

```
Invoke planner-coordinator on the following story: <story>.
Use scope classifier to pick specialists.
Write the plan to .claude/state/plan-<branch>.md.
Surface blocking questions and the next action.
```

The coordinator handles:
- Scope classification (`tiny` / `small` / `medium` / `large`)
- Specialist selection
- Parallel spawning of Wave 1 (`requirements-clarifier`, `scope-decomposer`, `architect`, `api-designer`, `database-architect`)
- Sequential spawning of Wave 2 (`risk-assessor`, `test-strategy-planner` — they consume Wave 1 outputs)
- Merging into a single plan
- Persisting to `.claude/state/plan-<branch>.md`

### Phase 3: Surface to User

Show the user:
- Scope and specialist selection (so they know what was checked)
- Blocking questions (most important — work cannot start until resolved)
- The work-breakdown table (collapsed sub-steps unless asked)
- Top 3 risks
- Next action (resolve questions → re-plan, OR proceed to `/build`)

### Phase 4: Save and Exit

The plan file is the state. No additional persistence needed.

## State Files

| File | Owner | Purpose |
|------|-------|---------|
| `.claude/state/plan-<branch>.md` | Planner coordinator | The plan; consumed by `/build` |
| `.claude/state/plan-context-<branch>.md` | Planner coordinator | Wave 1 outputs concatenated; consumed by Wave 2 specialists |

Branch names with `/` are sanitized to `-` for filenames.

## When NOT to Use /plan

- **Trivial fixes** (1–2 lines, well-understood pattern) — just `/develop` or edit directly
- **Pure refactors** with no behavior change — usually no plan needed
- **Docs-only changes** — usually no plan needed
- **Production hotfixes** — speed > planning; document after

The coordinator's `tiny` scope classifier will tell you to skip `/plan` for these.

## Edge Cases

| Scenario | Behavior |
|----------|----------|
| No story / task identified | Ask the user |
| Plan exists, no `--refresh` | Tell user, ask whether to use existing or refresh |
| Blocking questions returned | Surface them prominently; tell user the plan is incomplete |
| `--scope=large` forced on a tiny task | Honor it but warn ("you forced large scope; expect ~10x specialist runs") |
| Coordinator fails | Show partial output; user can retry or fall back to manual planning |

## Related

- `planner-coordinator` agent — the agent this skill spawns
- `/build` — consumes the plan and orchestrates implementation
- `/iterative-review` — runs after `/build` to review the implementation
- `/develop` — single-agent implementation path; use for trivial work where `/plan` and `/build` would be overkill
- `/factory` — end-to-end pipeline that may chain `/plan` → `/build` → `/iterative-review` → PR
- `docs/finding-schema.md` — JSONL output schema all coordinator agents use
