---
name: iterative-review
description: Plan → code → review → re-code feedback loop with persistent state across iterations. Spawns the review-coordinator, tracks findings across pushes, dedupes against prior iterations, and respects user "won't fix" decisions
---

# Iterative Review — The Feedback Loop

A sustained plan/code/review/re-code cycle on the current branch. Each pass:

1. Plans (or replans) the change
2. Implements the plan
3. Spawns `review-coordinator` to synthesize parallel reviewer findings
4. Persists findings to `.claude/state/review-state-<branch>.json` (append-only)
5. On the next pass, the coordinator sees prior findings and tracks fixed/unfixed/won't-fix

This is the framework's primary inner loop for non-trivial work. Use `/team review` for one-shot reviews; use `/iterative-review` when you expect multiple iterations.

## Usage

```
/iterative-review                      — start or continue the loop on the current branch
/iterative-review --plan-only          — produce/refresh the plan; do not implement or review
/iterative-review --review-only        — skip planning + coding; just spawn coordinator
/iterative-review --reset              — discard state for this branch and start fresh
```

## State Files

All state lives in `.claude/state/` (gitignored). Per branch:

| File | Purpose | Lifecycle |
|------|---------|-----------|
| `plan-<branch>.md` | The current implementation plan | Rewritten on `--plan-only` |
| `review-context-<branch>.md` | Shared context every sub-reviewer reads | Rewritten by coordinator each iteration |
| `review-state-<branch>.json` | Append-only findings history | Coordinator appends, never rewrites |

Branch names with `/` are sanitized to `-` for filenames (e.g., `feature/auth` → `feature-auth`).

## Process

### Phase 1: Plan

If `.claude/state/plan-<branch>.md` doesn't exist, or `--plan-only` was passed:

1. Read the ticket / user intent from the conversation context
2. Spawn the `architect` agent with prompt: "Produce an implementation plan for the current task. Identify changed surfaces, risks, and the minimum coherent scope. Output in markdown with sections: Goal, Changes, Risks, Out-of-scope."
3. Write architect's output to `.claude/state/plan-<branch>.md`
4. Show the plan to the user. If `--plan-only`, exit here.

If the plan exists and `--plan-only` was not passed, read and reuse it. The plan stays stable across iterations unless the user explicitly refreshes.

### Phase 2: Implement

Make the changes per the plan. This phase runs as the main agent (you), not a sub-agent — the user sees code as it lands.

Apply project rules from `.claude/rules/` automatically. Run `{{TEST_COMMAND}}` and `{{FORMAT_COMMAND}}` as you go.

If `--review-only`, skip this phase.

### Phase 3: Review (Coordinator)

Spawn the `review-coordinator` agent:

```
Spawn review-coordinator on the current branch. It will:
  - classify the diff into trivial/lite/full
  - select sub-reviewers
  - spawn them in parallel
  - read prior state from .claude/state/review-state-<branch>.json
  - merge, dedup, filter their findings
  - append to state and render the consolidated report
```

The coordinator handles all sub-agent orchestration — do not spawn individual reviewers from this skill.

### Phase 4: Surface Verdict and Next Action

Read the coordinator's report. Show the user:

- **Tier and agents used** (so they know what was checked)
- **Findings grouped by severity** (collapsed for nits)
- **Verdict** (APPROVE / APPROVE_WITH_NOTES / REQUEST_CHANGES / NEEDS_DISCUSSION)
- **Suggested next action:**
  - `REQUEST_CHANGES` → "Run `/iterative-review` again after addressing critical findings"
  - `APPROVE_WITH_NOTES` → "Optional improvements remain; run `/iterative-review` again or proceed to commit"
  - `APPROVE` → "Ready to commit"
  - `NEEDS_DISCUSSION` → list the disputed findings with developer pushback

### Phase 5: Iterate

When the user runs `/iterative-review` again after making changes:

- Coordinator reads prior `review-state-<branch>.json`
- Findings that no longer reproduce → marked `fixed`, shown in "Resolved" section
- Findings still present → carried forward
- New issues introduced by the fixes → flagged as new

The state file is append-only, so iteration history is preserved (useful for PR retrospectives).

## Caching-Friendly Prompt Shape

Sub-reviewers and the coordinator are given prompts that follow this order to maximize prompt cache hit rate:

1. System rules (stable across all runs)
2. `CLAUDE.md` / `AGENTS.md` excerpts (stable across iterations on this repo)
3. `review-context-<branch>.md` (stable across all sub-agents within one iteration)
4. Prior findings state (stable per iteration)
5. Current diff or specific question (most volatile, last)

Volatile data (timestamps, current SHA, random IDs) is always at the end. Never embed `Date.now()` or similar in the static prefix.

## Marking a Finding "Won't Fix"

When the user disagrees with a finding, two ways to record it:

**Option A — In the state file** (recommended, machine-readable):

Edit `.claude/state/review-state-<branch>.json` and add to the top-level `user_decisions` map:

```json
"user_decisions": {
  "src/auth.ts:42:auth-security:fail-open": {
    "status": "wont_fix",
    "reason": "Behind feature flag, not yet enabled in any environment"
  }
}
```

**Option B — Tell the assistant in conversation**, and ask it to update the state file. The coordinator respects these on the next iteration and does not re-raise unless severity is `critical`.

## Edge Cases

| Scenario | Behavior |
|----------|----------|
| No diff against base branch | "Nothing to review" — exit without spawning agents |
| Coordinator fails | Show the partial output; user can retry |
| `.claude/state/` is in gitignore but doesn't exist | Create it; warn if `.gitignore` doesn't list `.claude/state/` |
| User switches branches mid-loop | New branch gets its own state file; old state stays put |
| Plan in `plan-<branch>.md` is stale (e.g., user pivoted) | User runs `--plan-only` to regenerate |
| State file grows large (many iterations) | Coordinator only loads the most recent iteration's findings + `user_decisions` for matching; full history is preserved but not parsed every time |

## Related

- `review-coordinator` agent — the synthesizer this skill orchestrates (`templates/agents/review-coordinator.md`)
- `docs/finding-schema.md` — finding schema every sub-reviewer emits
- `/team review` — one-shot multi-agent review without state
- `/develop` — the broader dev cycle (fetch ticket → implement → validate → PR); use `/iterative-review` *within* `/develop` for tight loops
- `/factory` — end-to-end pipeline; calls `/iterative-review` automatically when more than one review pass is expected
