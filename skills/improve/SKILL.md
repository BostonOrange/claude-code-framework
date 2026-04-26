---
name: improve
description: Self-improvement — orchestrates framework-improver-detector and framework-improver-applier across a skip-list-aware pipeline. Distinct from /setup (first-run shape decisions); /improve owns ongoing evolution and refuses to overwrite layers /setup decided
---

# Improve — Framework Self-Improvement

Analyze the current project state and improve the `.claude/` configuration. This is the *ongoing-evolution* lifecycle counterpart to `/setup` — it tunes around shape decisions `/setup` already made instead of overwriting them.

**Lifecycle vs `/setup`:** `/setup` decides shape (first run). `/improve` keeps shape in tune as the project grows. Boundary is enforced architecturally: the detector reads `setup-applied.md` to build a skip-list at proposal time, the applier re-validates the skip-list at apply time. Items `/setup` owns never become candidates.

## Usage

```
/improve                  full pass: detect → apply (no user gate; autonomous)
/improve scan             dry run — produce proposal only, don't apply
/improve claude-md        scope to CLAUDE.md placeholders
/improve rules            scope to .claude/rules/ patterns
/improve settings         scope to .claude/settings.local.json
/improve agents           scope to .claude/agents/ tuning
```

Scopes are passed through to the detector to limit the proposal.

## Process

### Phase 1: Detect (read-only)

Spawn `framework-improver-detector`:

```
Run your full process. Read setup-applied.md (if present) and build the
skip-list, scan the project per docs/project-detection.md, identify
improvements, filter against the skip-list, and write
.claude/state/improve-proposal.md. End with the surface summary.
```

The detector is read-only by tool restriction. It writes only `.claude/state/improve-proposal.md`.

### Phase 2: Verify proposal

Read the proposal:
- Confirm `## Improvements` is well-formed
- Confirm `## Filtered (owned by /setup)` lists items the detector dropped — surface to user as "respected /setup decisions"
- Confirm there are no path-allowlist violations (the applier will halt if there are, but flagging here is faster)

If `--scope scan`, stop here. Print the path to `improve-proposal.md` for inspection.

### Phase 3: Apply

Spawn `framework-improver-applier`:

```
Read .claude/state/improve-proposal.md. Run all 4 pre-apply gates
(proposal exists, re-derive skip-list, filter & halt if non-empty drop
count, allowlist validate). On success, snapshot to
.claude/state/improve-backup-<ts>/, apply substitutions, smoke-check,
write .claude/state/improve-applied.md. Auto-rollback on any error.
```

The applier has Edit/Write but refuses to apply any item in the `/setup`-owned skip-list.

### Phase 4: Verify and report

Read `.claude/state/improve-applied.md` and surface:

- Count of changes applied
- Count of refusals (skip-list enforcement — should be 0 if detector did its job)
- List of remaining `{{...}}` placeholders (intentionally vs unexpected)
- Backup directory path (rollback path)
- Path to `docs/ai-improvements.md` (append-only changelog)

## State Files

| File | Owner | Lifecycle |
|------|-------|-----------|
| `.claude/state/improve-proposal.md` | detector (Phase 1) | Overwritten each run |
| `.claude/state/improve-applied.md` | applier (Phase 3) | Append-only audit |
| `.claude/state/improve-backup-<ts>/` | applier (Phase 3) | Created every apply; rollback path |
| `docs/ai-improvements.md` | applier (Phase 3) | Append-only project-level changelog |

## When to Use `/improve` vs `/setup`

| Situation | Use |
|-----------|-----|
| First-time onboarding (just ran `setup.sh`) | `/setup` |
| Convention drift after weeks of development | `/improve` |
| Filling specific `{{...}}` placeholders | `/improve claude-md` |
| Adding new rule patterns based on actual file structure | `/improve rules` |
| Switched stacks (e.g., npm → pnpm) | `/setup --layer=build` |

`/setup` is shape-deciding. `/improve` is shape-tuning. They don't overlap — the skip-list mechanism enforces it.

## Edge Cases

| Scenario | Behavior |
|----------|----------|
| `setup-applied.md` doesn't exist (no `/setup` ever run) | Detector treats every layer as in-scope; user warned that `/setup` is recommended for first-time onboarding |
| Detector proposes empty improvements list | Skill skips Phase 3; reports "nothing to improve" |
| Applier gate 3 drops items (non-empty) | Halt; surface refusals; user reviews and decides |
| `CLAUDE.md` doesn't exist | Detector recommends running `/setup` first; does not fill placeholders into a missing file |
| Apply fails mid-flight | Auto-rollback from backup; apply log not written; proposal stays valid for re-run after fix |
| `--scope scan` | Stop after Phase 2; do not spawn applier |

## Related

- `framework-improver-detector` agent — runs Phase 1, produces proposal (read-only by tool removal)
- `framework-improver-applier` agent — runs Phase 3, applies with skip-list enforcement + backup + audit
- `/setup` — first-run shape decisions; writes the skip-list this skill respects
- `docs/project-detection.md` — shared detection bash
- `docs/setup-state-schema.md` — schema for setup-proposal.md and setup-applied.md (defines the layer→placeholder mapping the skip-list uses)
- `/ai-update` — Create branch + PR for AI config changes
- `/add-reference` — Add domain knowledge references
- `/team full` — Run all agents to validate improved configuration
