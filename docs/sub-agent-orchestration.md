# Sub-Agent Orchestration Guide

How skills spawn, coordinate, and chain sub-agents for parallel and background work.

## Why Sub-Agents?

Long-running operations (deployment, validation, tracker updates) are:
1. **Slow** — waiting sequentially wastes time
2. **Verbose** — build errors and API responses pollute the main context window
3. **Independent** — many operations don't depend on each other

Sub-agents solve all three: they run in parallel, isolate verbose output, and return only the summary.

## Orchestration Patterns

### Pattern 1: Parallel Independent Tasks

When two operations don't depend on each other, run them simultaneously.

**Example:** `/develop` Phase 5 runs deployment and code standards in parallel:

```
Phase 5: Validate
├─ Sub-agent A (background): Deploy to test environment
│   → {{DEPLOY_VALIDATE_COMMAND}}
│   → Returns: PASS/FAIL + error summary
│
├─ Sub-agent B (background): Code standards check
│   → /validate TICKET-1234
│   → Returns: validation report with ERROR/WARN/PASS counts
│
└─ Wait for both → if either fails → Phase 6 (fix)
```

**How to implement in a skill:**

```markdown
Launch **two sub-agents in parallel** using the Agent tool:

**Sub-agent A — Deployment** (`subagent_type: "general-purpose"`):
Deploy to {alias} and report results.

**Sub-agent B — Code standards** (`subagent_type: "general-purpose"`):
Run /validate {TICKET_ID} and report results.

Both are slow and independent — launch them simultaneously with a single message
containing both Agent tool calls. Wait for both to complete, then:
- If both pass → Phase 7
- If either fails → Phase 6
```

### Pattern 2: Background Fire-and-Forget

When an operation should happen but you don't need to wait for it.

**Example:** `/develop` Phase 8 pushes docs to tracker in the background:

```
Phase 7: PR Created ✓
│
├─ Report PR URL to user (immediate)
│
└─ Sub-agent (background, fire-and-forget):
    → /update-tracker TICKET-1234
    → User doesn't wait for this
```

**How to implement:**

```markdown
Spawn `/update-tracker {TICKET_ID}` as a **background** sub-agent using the
Agent tool (`run_in_background: true`). Don't wait — the develop workflow is
done after PR creation.
```

### Pattern 3: Error Isolation

When a task produces verbose output that would pollute the main conversation.

**Example:** `/develop` Phase 6 spawns a debugger sub-agent:

```
Phase 5: Validation FAILED (500 lines of error output)
│
└─ Sub-agent (debugger):
    → Receives full error output (stays in sub-agent context)
    → Parses errors, identifies root cause
    → Applies fixes to code
    → Returns: "Fixed 3 errors in 2 files" (summary only)
```

**How to implement:**

```markdown
**Max 3 attempts.** For each failure, spawn a **sub-agent** using the Agent
tool (`subagent_type: "debugger"`) to:

1. Receive the error output from Phase 5
2. Parse errors, identify root cause
3. Apply fixes to code
4. Report back what changed

This keeps verbose build error context out of the main conversation window.
```

### Pattern 4: Skill Chaining (Sequential)

When skills must run in order, each depending on the previous result.

**Example:** `/factory` chains skills sequentially:

```
/factory TICKET-1234
│
├─ Step 2: /check-readiness TICKET-1234 --factory
│   → Returns: PASS (auto) or FAIL (gap report)
│   → If FAIL → halt
│
├─ Step 3: /develop TICKET-1234 --factory
│   → Returns: implementation complete, files staged
│   → Uses readiness classification from Step 2
│
├─ Step 4: Local validation
│   → Uses artifacts from Step 3
│
└─ Step 5: Push & PR
    → Uses branch from Step 3
    → Uses classification from Step 2 for labels
```

**How to implement:**

```markdown
### Step 2: Readiness Gate
Invoke `/check-readiness TICKET-{id} --factory`.
- On FAIL → halt
- On PASS → save classification (auto/semi-auto), continue

### Step 3: Develop
Invoke `/develop TICKET-{id} --factory`.
Factory mode ensures no interactive prompts.
```

### Pattern 5: Context Passing Between Skills

Skills share context through:

1. **File system** — story docs, build logs, execution logs
2. **Flags** — `--factory` mode changes behavior across all chained skills
3. **Memory** — persistent preferences (worktree style, environment aliases)
4. **Git state** — branch name, staged files, commit history

**Example:** `/factory` passes classification to `/develop` via label:

```
/check-readiness → outputs: classification = "semi-auto"
    ↓
/develop --factory → reads classification, adds `factory-semi-auto` label to PR
    ↓
CI workflow → reads label, routes to semi-auto deploy path
```

### Pattern 6: Memory-Aware Decisions

Skills read persistent memory to adapt behavior:

```markdown
**Worktree awareness:** Check memory for user's worktree preference.
If user keeps a dedicated worktree for the base branch, create a new
worktree for the feature branch instead of switching in the main repo.
```

**What memory provides:**
- Worktree workflow preferences
- Default environment aliases
- Team PR conventions
- Known build fixes (avoid repeating mistakes)
- Deploy manager identity

## Implementing in Skills

### Spawning a Sub-Agent

In your SKILL.md, describe the sub-agent clearly:

```markdown
Launch a sub-agent using the Agent tool:
- **Type:** `subagent_type: "debugger"` (or "general-purpose")
- **Task:** "Parse the following deployment errors and fix the source files: {errors}"
- **Background:** `run_in_background: true` (for fire-and-forget)
```

### Receiving Results

Sub-agents return a single summary message. Design your skill to:
1. Check if the sub-agent succeeded or failed
2. Extract key information (file paths changed, error counts, etc.)
3. Decide next step based on the summary

### Parallel Launch

To run multiple sub-agents in parallel, describe them together:

```markdown
Launch **two sub-agents in parallel** (single message with both Agent tool calls):

1. **Deployment validation** — deploy and run tests
2. **Code standards check** — run /validate

Wait for both to complete before proceeding.
```

## Factory Mode Behavior

The `--factory` flag cascades through the skill chain:

| Skill | Interactive Behavior | Factory Behavior |
|-------|---------------------|-----------------|
| `/check-readiness` | Show report, ask user | Auto-post to tracker on FAIL, continue on PASS |
| `/develop` | Ask about worktree, gaps, validation target | All auto-defaults, no prompts |
| `/validate` | Report issues, ask user | Report issues, auto-fix or halt |
| `/update-tracker` | Ask before pushing | Auto-push |

This means a single `/factory TICKET-1234` invocation runs the entire pipeline without human intervention until code review.

## Anti-Patterns

| Don't | Do Instead |
|-------|------------|
| Spawn sub-agent for a 5-second task | Run it inline |
| Pass huge context to sub-agent prompt | Write to a temp file, tell sub-agent to read it |
| Wait for a background sub-agent | Use `run_in_background: true` and continue |
| Chain 5+ sequential sub-agents | Combine into one sub-agent with multiple steps |
| Spawn sub-agent to read a single file | Use the Read tool directly |

## Execution Logging

The factory pipeline logs phase-by-phase execution:

```markdown
# Factory Execution Log — TICKET-{id}

## Run: {timestamp}

| Phase | Started | Duration | Outcome |
|-------|---------|----------|---------|
| Readiness | 14:00:01 | 12s | PASS (auto) |
| Branch | 14:00:13 | 3s | Created worktree |
| Scaffold | 14:00:16 | 8s | 12 files generated |
| Implement | 14:00:24 | 2m 15s | 8 components created |
| Validate (deploy) | 14:02:39 | 4m 30s | PASS |
| Validate (standards) | 14:02:39 | 45s | PASS |
| PR | 14:07:09 | 5s | #142 |

Total: 7m 14s
```

This goes in `docs/stories/{TICKET_ID}/execution-log.md`.
