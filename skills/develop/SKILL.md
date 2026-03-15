---
name: develop
description: Full development cycle - fetches ticket from work item tracker, analyzes, implements, validates, fixes build errors, and creates PR. Use when developing a ticket end-to-end.
---

# Develop

End-to-end development cycle: fetch ticket, analyze, implement, validate, fix, commit, PR.

## Usage

```
/develop TICKET-1234
/develop 1234
/develop TICKET-1234 --factory    # Factory mode (all auto-defaults)
```

If no ticket ID provided, ask for it. If user pastes story content directly, skip Phase 1 and ask for a ticket ID for naming.

## Factory Mode

When invoked with `--factory` (or from `/factory`), all interactive gates use auto-defaults:

| Decision Point | Interactive (default) | Factory Mode |
|---------------|----------------------|--------------|
| Phase 2: Gap analysis | Ask user if major gaps | Skip (readiness gate already passed) |
| Phase 3: Worktree vs main repo | Ask user | Always worktree |
| Phase 5: Validation | Deploy + code standards | Code standards only (CI handles deployment) |
| Phase 7: PR label | No label | Add `factory` label (triggers CI deploy) |
| Phase 7: Ticket state transition | Ask user | Auto-transition to review state |
| Phase 8: Push to tracker | Ask user | Auto-push |
| Phase 6: On standards failure | Present options to user | Halt + notify |

> **CRITICAL — when invoked from `/factory`:** `/develop --factory` handles Phases 1-5 (fetch, analyze, branch, implement, code standards). It does NOT push, create a PR, or update the tracker. Control returns to `/factory` which may run additional validation BEFORE pushing.

## Phase 1: Fetch Ticket from Tracker

Parse ticket ID from input. Accept `TICKET-1234` or just `1234`.

{{TRACKER_FETCH_TICKET}}

Extract from response:
- Title
- State/Status
- Type (story, bug, task)
- Assignee
- Description
- Acceptance Criteria

Display summary table, then show cleaned Description and Acceptance Criteria.

### Auto-transition to In Progress

After displaying the summary, check state. If not "In Progress" (or equivalent):

{{TRACKER_SET_IN_PROGRESS}}

Confirm to user: `"Set TICKET-{id} to In Progress (assigned to {display_name})"`

## Phase 2: Analyze & Refine

**Factory mode:** Skip this phase — `/check-readiness` already validated the ticket.

**Interactive mode:** Evaluate ticket against refinement criteria:

| Category | Check For |
|----------|-----------|
| Technical Details | Missing field specs, API names, relationships |
| Business Logic | Ambiguous rules, calculations, workflow steps |
| Integration Impact | Effects on external systems not specified |
| Permission/Security | Missing access control requirements |
| Testing Gaps | Insufficient acceptance criteria, missing edge cases |
| Scope | What's included/excluded |

Scan codebase for affected components. Reference domain skills when relevant.

**Decision:**
- **Major gaps** -> Recommend running `/refine-story` first. Stop here.
- **Minor gaps** -> Ask 3-5 targeted clarifying questions. Continue after answers.
- **Ready** -> Present implementation overview. Get user confirmation.

## Phase 3: Git Branch Setup

Check current branch:
- If already on `{TICKET_ID}` branch with existing work -> skip, continue
- If not on correct branch -> decide branching strategy

**Memory checkpoint — worktree preference:**
Check memory for user's worktree workflow before prompting:
- If memory says "always worktree" → create worktree without asking
- If memory says "main repo" → checkout branch without asking
- If no memory → ask user **"Create feature branch as worktree or in main repo?"**, then save their preference to memory

**Memory checkpoint — base branch naming:**
Check memory for dedicated base branch worktree. If user keeps a dedicated worktree for `{{BASE_BRANCH}}`, never checkout that branch in the main repo.

**Factory mode:** Always use worktree (no prompt):
```bash
git fetch origin {{BASE_BRANCH}}
git worktree add ../{{PROJECT_SHORT_NAME}}-{TICKET_ID} -b {TICKET_ID} origin/{{BASE_BRANCH}}
```

**Default (main repo):**
```bash
git fetch origin {{BASE_BRANCH}}
git checkout -b {TICKET_ID} origin/{{BASE_BRANCH}}
```

**Worktree:**
```bash
git fetch origin {{BASE_BRANCH}}
git worktree add ../{{PROJECT_SHORT_NAME}}-{TICKET_ID} -b {TICKET_ID} origin/{{BASE_BRANCH}}
```

## Phase 4: Implement

### Story Documentation

Create `docs/stories/{TICKET_ID}/` with:

| File | Content |
|------|---------|
| `story.md` | Full story with ACs, technical spec |
| `solutions-components.md` | Components changed/created (bullet form) |
| `how-to-test.md` | Testing instructions |
| `manual-steps.md` | Pre/post deployment steps (only if needed) |

### External API Check

Before implementing, check `.claude/skills/mock-endpoint/references/INDEX.md` for any external services this feature touches:

- **Contract exists** → use the wrapper, write tests with mock fixtures. Never call the real API
- **No contract** → ask user: "This feature calls {service}. Should I create a mock contract first?" If yes, invoke `/mock-endpoint {service}` before continuing

### Implementation

Create/modify components following CLAUDE.md coding standards. Key guardrails:

- Follow project error handling patterns
- Use test data factories (never construct test data inline)
- No debug statements in production code
- No commented-out code
- Constants over magic values
- Verify enum/picklist values from source of truth before using
- External API calls must go through service wrappers (never direct fetch/axios to external URLs)

### Format Changed Files

```bash
{{FORMAT_COMMAND}}
```

Never run project-wide formatting. Format only files you created or modified.

## Phase 5: Validate

**Factory mode:** Run code standards only. CI handles deployment.

**Memory checkpoint — environment aliases:**
Check memory for known environment aliases:
- Preferred validation environment (e.g., "UAT" vs "CI environment")
- Environments to skip (e.g., "CI environments have pre-existing failures")
- Production alias (add confirmation gate if accidentally selected)

**Memory checkpoint — recurring build fixes:**
Before validation, check memory for known build issues that apply to this story's components. Apply preventive fixes proactively (e.g., don't add required fields to permission sets).

**Interactive mode:** Ask user which environment to deploy to, then launch two parallel tasks:

**Task A — Deployment:**
```bash
{{DEPLOY_VALIDATE_COMMAND}}
```

**Task B — Code standards check:**
Run `/validate {TICKET_ID}`

Both are slow and independent — launch simultaneously. Wait for both to complete.

- If both pass -> Phase 7
- If either fails -> Phase 6

## Phase 6: Fix Build Failures (max 3 attempts)

For each failure, spawn a **sub-agent** to:
1. Receive the error output
2. Parse errors, identify root cause
3. Apply fixes
4. Report back what changed

After the sub-agent reports back:
1. Log attempt to `docs/stories/{TICKET_ID}/build-log.md`
2. Retry from Phase 5

After 3 failures:

**Memory checkpoint — save build fix:**
If a non-obvious fix was applied (something that wasn't clear from the error message alone), save it to memory so future conversations don't repeat the same mistake.

**Interactive mode:** Present errors with options: fix manually, skip validation, abort.

**Factory mode:** Halt and notify:
{{NOTIFY_HALT}}
Stop execution — do not proceed to PR.

### Build Log Format

```markdown
# Build Log - {TICKET_ID}

## Attempt 1 -- {timestamp}
**Target:** {environment or "code standards"}
**Result:** FAILED

### Errors
{error output}

### Root Cause
{brief description}

### Fix Applied
{what changed}

### Files Modified
- `path/to/file`
```

## Phase 7: Commit & Create PR

### Pre-commit checks

Run project test suite if relevant components were modified:
```bash
{{TEST_COMMAND}}
```

### Commit

Stage specific files (never `git add -A`):
```bash
git add path/to/file1 path/to/file2
```

### Push & PR

```bash
git push -u origin {TICKET_ID}
```

**Memory checkpoint — PR conventions:**
Check memory for team's PR conventions:
- Title format (e.g., `{TICKET-ID}: {exact story title}`)
- Body style (short summary? test plan? AI attribution?)
- Reviewers (CODEOWNERS? self-assign? specific team?)

Create PR:
```bash
gh pr create --base {{BASE_BRANCH}} --assignee @me \
  --title "{TICKET_ID}: {Story Title}" \
  --body "$(cat <<'EOF'
## Summary
- {short summary of changes}

[Ticket: {TICKET_ID}]({{TRACKER_TICKET_URL}})
EOF
)"
```

**Factory mode:**
```bash
gh pr edit {pr_number} --add-label "factory"
```

### Link PR to Tracker

{{TRACKER_LINK_PR}}

### Post-PR State Transition

{{TRACKER_SET_IN_REVIEW}}

Ask user before transitioning (skip prompt in factory mode).

## Phase 8: Update Tracker (Background Sub-Agent)

**Factory mode:** Auto-push without prompting.

**Interactive mode:** Ask the user:
> **Push story docs to work item tracker?** (acceptance tests, deployment notes)

If yes -> Spawn `/update-tracker {TICKET_ID}` as a background sub-agent.

## Edge Cases

| Scenario | Behavior |
|----------|----------|
| No ticket ID provided | Ask user for it |
| Story pasted directly (no tracker) | Skip Phase 1, ask for ticket ID for naming |
| Already on feature branch with work | Skip Phase 3, read existing docs for context |
| User says "skip validation" | Go from Phase 4 directly to Phase 7 |
| Story needs major refinement | Recommend `/refine-story` first, pause |
| Pre-deploy dependencies exist | Create predeploy manifest, document in `manual-steps.md` |
| `build-log.md` already exists | Append new attempts, never overwrite |
| Auth not configured | Prompt user to configure credentials |

## Related Skills

- `/update-tracker` - Push story docs to tracker (Phase 8)
- `/refine-story` - Full story refinement
- `/check-readiness` - Readiness gate (factory prerequisite)
- `/factory` - End-to-end factory pipeline (invokes `/develop --factory`)
- `/draft-story` - Create new stories
