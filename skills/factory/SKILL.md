---
name: factory
description: AI Software Factory — end-to-end pipeline from approved ticket to deployed test environment. Chains readiness gate → develop (factory mode) → PR → CI deploy. Reduces human touchpoints from 5+ to 2.
---

# Factory

End-to-end AI Software Factory: readiness → develop → PR → CI deploy to test environment.

## Usage

```
/factory TICKET-1234
/factory 1234
```

## Overview

The factory pipeline automates the full path from an approved ticket to code deployed in a test environment for review. It chains existing skills with factory-mode defaults that eliminate manual decision points.

### Human Touchpoints (reduced from 5+ to 2)

1. **Architect/PM drafts ticket** — `/draft-story` resolves all open questions → ticket is "Ready for Sprint"
2. **Code review** — reviewer approves PR. Code is already deployed in test environment (by CI).
3. **Smoke test** — users validate in staging after auto-deploy

Everything else is automated.

### Architecture

```
Developer Terminal (Claude Code)     │     CI/CD (automatic)
─────────────────────────────────────┼──────────────────────────────────
                                     │
/factory TICKET-xxx                  │
  ├─ /check-readiness                │
  ├─ Create worktree + branch        │
  ├─ Scaffold + implement            │
  ├─ /validate (code standards only) │
  ├─ Fix code standards issues       │
  ├─ Commit + push                   │
  └─ Create PR (factory label)  ─────┼──► CI validate workflow
                                     │      ├─ Deploy to test environment
                                     │      ├─ Run tests
                                     │      └─ Post PR comment with env link
                                     │
                              Review ─┼──► Reviewer tests in environment
                                     │
                        PR Approved ──┼──► CI auto-merge workflow
                                     │
                          PR Merged ──┼──► CI deploy workflow
                                     │      ├─ Deploy to staging
                                     │      ├─ Notify team
                                     │      └─ Update ticket state
```

### Pipeline Classification

The readiness gate classifies tickets into two paths:

| Type | Meaning | Deploy behavior |
|------|---------|-----------------|
| **Auto** | All changes deployable via CI/CD | Full automation through staging |
| **Semi-auto** | Requires manual configuration | Pipeline pauses → notifies manual steps → human confirms → deploy |

## Execution

### Step 1: Parse Input

Extract ticket ID from input. Accept `TICKET-1234` or just `1234`.

### Step 2: Readiness Gate

Invoke `/check-readiness TICKET-{id} --factory`.

The `--factory` flag means:
- On **FAIL**: automatically post gap report to tracker, transition to "needs info" state, and **stop**
- On **PASS**: continue to Step 3. Save the classification (auto/semi-auto) for the PR label.

If readiness fails:
> **Factory halted — TICKET-{id} not ready.** Gap report posted to tracker. Ticket returned to architect.

### Step 3: Develop (Factory Mode)

Invoke `/develop TICKET-{id} --factory`.

Factory mode defaults (no user prompts):
- **Worktree**: always (no prompt)
- **Validation**: code standards only — no deployment (CI handles it)
- **Tracker update**: automatic
- **PR label**: `factory` added automatically (+ `factory-semi-auto` if classified)

### Step 4: Pre-Push Validation (Optional)

> **BLOCKING GATE:** Do NOT push or create a PR until this step passes.

Before creating the PR, optionally validate the full deployment locally. This catches deployment errors before human review.

The implementation depends on your deployment target:
- **Salesforce:** Create scratch org, deploy, run tests
- **Node.js/Python:** Run full test suite, build, lint
- **Docker:** Build image, run container tests
- **Generic:** Run project's validation script

{{FACTORY_LOCAL_VALIDATION}}

If validation fails (max 3 attempts):
1. Parse the error
2. Fix the source
3. Retry

After 3 failures → halt and notify.

### Step 5: Push & Create PR

Only after validation passes:

```bash
git push -u origin {branch}
gh pr create --base {{BASE_BRANCH}} --assignee @me \
  --title "{TICKET_ID}: {Story Title}" \
  --label "factory" \
  --body "$(cat <<'EOF'
## Summary
- {short summary of changes}

[Ticket: {TICKET_ID}]({{TRACKER_TICKET_URL}})
EOF
)"
```

### Step 6: Wait for CI + Code Review

After PR is created, two things happen automatically:
1. **CI/CD** deploys to test environment and posts PR comment with link
2. **Reviewer** tests the code, then approves or requests changes

If CI deployment fails, errors are posted as PR comments. Developer fixes locally and pushes.

### Step 7: Deploy to Staging (Post-Merge)

#### Auto tickets
After merge, CI handles:
1. Deploy to staging
2. Notify team
3. Update ticket state

#### Semi-auto tickets
After merge:
1. Post notification listing manual config steps
2. Wait for human to complete manual config
3. Human confirms → deploy

### Step 8: Report Completion

> **Factory pipeline complete for TICKET-{id}.**
>
> | Phase | Status |
> |-------|--------|
> | Readiness | PASS ({auto/semi-auto}) |
> | Branch | {worktree_path} |
> | Implementation | Complete |
> | Code Standards | PASS |
> | Local Validation | PASS |
> | PR | {pr_url} |
> | CI Deploy | Pending (CI/CD) |
> | Staging Deploy | {Auto on merge / Pending manual steps} |

## Execution Logging

Each factory run produces structured logs in `docs/stories/{TICKET_ID}/`:

| File | Content |
|------|---------|
| `execution-log.md` | Phase-by-phase timestamps, outcomes, durations |
| `build-log.md` | Validation failures and fix attempts |

### execution-log.md Format

```markdown
# Factory Execution Log — TICKET-{id}

## Run: {timestamp}

| Phase | Started | Duration | Outcome |
|-------|---------|----------|---------|
| Readiness | {time} | {duration} | PASS (auto) |
| Branch | {time} | {duration} | Created worktree |
| Scaffold | {time} | {duration} | {n} files generated |
| Implement | {time} | {duration} | {n} components created |
| Validate (standards) | {time} | {duration} | PASS |
| Validate (deploy) | {time} | {duration} | PASS |
| PR | {time} | {duration} | #{pr_number} |

Total: {total_duration}

## Components Created
{list from solutions-components.md}
```

### Memory Integration

**Factory mode reads memory** for:
- Worktree preferences (always worktree in factory, but naming convention matters)
- Known build fixes (preventive application before validation)
- Environment aliases (for local validation target)

**Factory mode writes memory** when:
- A non-obvious build fix is discovered during fix attempts
- A new deployment pattern is established

## Halt Conditions

| Condition | Action |
|-----------|--------|
| Readiness gate fails | Return to architect, post gap report |
| Code standards fail after 3 attempts | Halt, notify team |
| Local validation fails after 3 attempts | Halt, notify team |
| PR merge conflict | Run `/merge-resolve TICKET-{id}` to auto-resolve |
| CI deployment failure | Error posted as PR comment |

### Merge Conflict Auto-Resolution

When a factory PR can't merge (another PR merged to base branch first):
1. `/merge-resolve` reads both features' story docs to understand intent
2. Applies per-file-type resolution rules (source code: merge methods; permissions: union; config: deduplicate)
3. Pushes resolved result → CI re-validates
4. If resolution is uncertain → halts and notifies for human review

### Halt Notification

{{NOTIFY_HALT_FACTORY}}

## Edge Cases

| Scenario | Behavior |
|----------|----------|
| No ticket ID provided | Ask for it |
| Ticket already has open PR | Skip to review gate, warn user |
| Ticket already in staging/UAT | Skip, inform user |
| Worktree already exists | Reuse existing worktree |
| Factory label already on PR | Skip labeling |
| Auth not configured | Prompt user, halt |
| Notification webhook not set | Warn, skip notification, continue |
| PR has merge conflicts | Attempt auto-resolve, halt if complex |

## Related Skills

- `/check-readiness` — readiness gate (Step 2)
- `/develop` — implementation pipeline (Step 3)
- `/deploy` — manual deployment alternative
- `/validate` — code standards validation (called by `/develop`)
