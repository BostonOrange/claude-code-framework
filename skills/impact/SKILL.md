---
name: impact
description: On-demand precise impact analysis for a symbol or file before changing it. Spawns impact-analyzer to grep callers, classify the cascade (direct/indirect/test-only), and produce a confidence-scored report. Different from `.claude/state/architecture.md` (broad map) — this is the focused per-symbol drill-down
---

# Impact — On-Demand Cascade Analysis

Before making a confident-but-wrong change to a function, class, or file, run `/impact` to see what would break.

`/impact` answers questions like "if I change the return type of `requireAuth`, what breaks?" — without you having to grep callers, read each one, and reason about cascades by hand. Output is a structured report at `.claude/state/impact-<hash>.md` plus a short summary.

This complements `.claude/state/architecture.md`:
- **architecture.md** is the broad map (module boundaries, dependency direction, top-10 hotspots) refreshed by `/improve` each session
- **`/impact <symbol>`** is the focused drill-down for a specific change you're about to make

## Usage

```
/impact <file>                          analyze every exported symbol in the file
/impact <file>:<symbol>                 analyze just that symbol
/impact <symbol>                        bare symbol; spawns analyzer to find definition first
/impact --refresh <target>              ignore cache; re-run analysis
```

Examples:
```
/impact lib/auth/middleware.ts
/impact lib/auth/middleware.ts:requireAuth
/impact requireAuth
/impact AccountTriggerHandler.cls:beforeInsert    # Apex
```

## Process

### Phase 1: Spawn impact-analyzer

```
Run impact analysis on <target>. Locate the definition, find direct callers,
classify references (direct/type/test), trace second-order public callers
(depth=2 max), score confidence, write the report to .claude/state/impact-<hash>.md.
End with the surface summary.
```

The agent is read-only by tool restriction (`Read, Glob, Grep, Bash` — no `Edit`/`Write`). Its only filesystem write is the report file.

### Phase 2: Surface to user

Read the agent's summary output. Show:
- Total references + breakdown (direct / type / test)
- Confidence level + top caveat
- Top 3 most-impacted files
- Recommendation one-liner
- Path to the full report

### Phase 3: Hand-off

If the user is iterating on a change:
- "Confidence is high — proceed; the test suite at `<paths>` should catch regressions"
- "Confidence is medium — review the second-order callers in `.claude/state/impact-<hash>.md` before merging"
- "Confidence is low — string-keyed lookups detected; grep can't see them all. Consider running tests in addition"

If the user is exploring (no specific change):
- "X is used in Y places, mostly in `<dir>` — likely a `<role>` (auth/data-access/etc.). Safe to refactor if Z."

## State Files

| File | Purpose | Lifecycle |
|------|---------|-----------|
| `.claude/state/impact-<hash>.md` | Full per-symbol report | Cached by hash; re-used until target file's SHA changes |

`<hash>` is the first 8 chars of `sha256(target)`. Two `/impact` calls on the same target return the cached report unless `--refresh` is passed or the target file has new commits.

## When to Use `/impact` vs `/architecture` vs Grep

| Situation | Tool |
|-----------|------|
| About to change a specific function/class | `/impact <target>` |
| Trying to understand the codebase shape | Read `.claude/state/architecture.md` (refresh via `/improve` if stale) |
| Looking for a specific string | `Grep` directly |
| Looking for code semantically ("where do we handle X?") | `/search` (Phase 2 vector index, opt-in for large codebases) |
| Need precise call counts at scale | `/search` + `/impact` together; for 1M+ LOC consider GitNexus as a separate tool |

## Edge Cases

| Scenario | Behavior |
|----------|----------|
| Target not found | Agent halts with "no definition for `<target>`"; suggest `/search` if user gave a vague name |
| Multiple definitions | Agent lists candidates; user picks; re-run with disambiguated target |
| Cache exists and target unchanged | Return cached report; show its timestamp |
| Cache exists but target file has new commits | Re-run automatically (cache invalidated by SHA mismatch) |
| Target has >500 direct callers | Report truncates; recommends `/search` for full picture |
| Test-only references | Report flags as "candidate for removal — only used by tests" |
| Salesforce / Apex targets | Agent also checks triggers, flows, `@AuraEnabled`/`@RemoteAction` annotations |
| Large codebase (>500k LOC) | Grep is still fast; `/impact` works. For semantic queries at this scale, run `/index` once then use `/search` |

## Related

- `impact-analyzer` agent — the agent this skill spawns
- `.claude/state/architecture.md` — broad map, refreshed by `/improve`
- `/improve` — refreshes `architecture.md` every session
- `/search` — semantic search across the indexed codebase (Phase 2)
- `/index` — builds the vector index (Phase 2; opt-in for large codebases)
