---
name: build
description: Invoke the build-coordinator to execute a plan through sequential build phases — scaffold → happy-path → edge-case → tests → docs → refactor. Each phase is a specialist agent constrained by `.claude/rules/`. Resumes from the last completed phase if interrupted
---

# Build — Multi-Agent Implementation

A specialist-driven implementation of the current plan. The `build-coordinator` agent runs build phases in sequence, each handled by a focused specialist. Each specialist actively applies the project's `.claude/rules/` so the eventual review pass finds little to flag.

## Usage

```
/build                       — execute the current plan from the next un-completed phase
/build --from happy-path     — start (or restart) from a specific phase
/build --skip docs           — skip a phase (useful for non-doc-touching work)
/build --redo edge-case      — redo a previously-completed phase
/build --reset               — discard build-state and start fresh
```

## Process

### Phase 1: Verify Plan Exists

Read `.claude/state/plan-<branch>.md`. If absent, tell the user to run `/plan` first.

Verify no blocking questions remain in the plan. If they do, refuse to start.

### Phase 2: Spawn the Build Coordinator

Spawn `build-coordinator` as a sub-agent:

```
Invoke build-coordinator. Read .claude/state/plan-<branch>.md and
.claude/state/build-state-<branch>.json (if exists).
Resume from the next un-completed phase.
Run safety gates (type-check, tests) after each phase.
On phase failure, surface and stop; do not advance.
```

The coordinator handles:
- Reading the plan + build-state
- Determining next phase
- Spawning the right specialist for that phase
- Running gate checks (type-check, tests) after the phase
- Persisting phase results to `build-state.json`
- Advancing or stopping based on gate result

### Phase 3: Phase-by-Phase Execution

The coordinator runs phases sequentially:

| # | Phase | Specialist | Outputs |
|---|-------|------------|---------|
| 1 | scaffold | `scaffold-implementer` | File structure, types, signatures, stubs |
| 2 | happy-path | `happy-path-implementer` | Core successful flow logic |
| 3 | edge-case | `edge-case-implementer` | Validation, errors, edge data |
| 4 | test | `test-writer` (existing) | Tests per the plan's test strategy |
| 5 | docs | `documentation-writer` (existing) | Doc updates |
| 6 | refactor | `refactor-pass-implementer` | Apply code-quality rules actively |

Each specialist:
- Reads the plan and the prior phase's build-state
- Reads relevant `.claude/rules/` files actively (not just via passive injection)
- Writes/edits files
- Appends to `build-state.json`
- Returns a report

### Phase 4: Surface After Each Phase

The coordinator surfaces:
- What the phase did (files touched, key decisions)
- Gate result (PASS / FAIL on type-check / tests)
- Next phase + estimated work

The user can pause here and inspect, or continue (`/build` again).

### Phase 5: On Build Complete

After the refactor phase:
- Final type-check + tests
- Tell user to run `/iterative-review` for the review-coordinator pass
- The review pass should find few or no findings — if it finds many, the rules need tuning or the build agents need improvement

## State Files

| File | Owner | Purpose |
|------|-------|---------|
| `.claude/state/plan-<branch>.md` | `/plan` skill | Input — read by every phase |
| `.claude/state/build-state-<branch>.json` | Build coordinator | Append-only phase log; resumption point |

Branch names with `/` are sanitized to `-` for filenames.

## Specialists and Their Rules

Each build specialist actively reads and writes against specific rules:

| Specialist | Reads / writes against |
|------------|------------------------|
| `scaffold-implementer` | `architecture-layering`, `api-layering`, project conventions in CLAUDE.md |
| `happy-path-implementer` | `purity`, `complexity`, `code-smells`, layer-specific rules per file type |
| `edge-case-implementer` | `error-handling`, `auth-security`, `data-protection`, `api-routes`, `api-layering` |
| `test-writer` | `tests` |
| `documentation-writer` | (no rule binding; follows project doc conventions) |
| `refactor-pass-implementer` | `code-smells`, `dry`, `purity`, `complexity` (actively refactors to satisfy them) |

Goal: when `/iterative-review` runs after `/build` completes, the 4 code-quality reviewers (`code-smell-reviewer`, `dry-reviewer`, `purity-reviewer`, `complexity-reviewer`) should produce minimal findings on the new code. The rules are followed during writing, not just enforced after.

## Skipping Phases

Use `--skip` for trivial work:

| Story type | Recommended skips |
|------------|-------------------|
| Docs-only PR | `--skip scaffold,happy-path,edge-case,test,refactor` |
| Bug fix in existing function | `--skip scaffold,docs` |
| Refactor-only PR | `--skip scaffold,happy-path,edge-case,docs` |
| Test-coverage PR | `--skip scaffold,happy-path,edge-case,docs,refactor` |

For very small work where even sequencing is overkill, just use `/develop`.

## Edge Cases

| Scenario | Behavior |
|----------|----------|
| No plan exists | Refuse; tell user to run `/plan` |
| Plan has blocking questions | Refuse; surface them |
| Phase fails type-check | Surface; do not advance; user fixes or re-runs |
| Phase fails tests | Surface; user decides |
| Build-state corrupted | Offer to reset (`--reset`) |
| User edited files between phases | Subsequent phases pick up changes (state is on disk, not in-memory) |
| New plan version arrived | Confirm continue with new plan or stay |

## Related

- `build-coordinator` agent — the agent this skill spawns
- `/plan` — must run first to produce the plan this consumes
- `/iterative-review` — runs after build to validate; should find little
- `/develop` — single-agent path for trivial work
- `/factory` — end-to-end orchestration that may chain `/plan` → `/build` → `/iterative-review` → PR
- `docs/finding-schema.md` — JSONL output schema for any agent emissions
