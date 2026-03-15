---
name: deploy
description: Orchestrate deployments to target environments. Handles merging PRs, deploying, posting notifications, and updating work items. Use when deploying to staging/UAT/production.
---

# Deploy

Orchestrate deployments to target environments.

## Usage

```
/deploy TICKET-1234               # Deploy a single ticket
/deploy TICKET-1234 TICKET-5678   # Deploy multiple tickets
/deploy --env staging             # Deploy to specific environment
```

## Process

### Step 1: Identify What to Deploy

For each ticket ID:
1. Find the associated PR
2. Verify PR is approved and checks pass
3. Collect ticket metadata (title, type, manual steps)

### Step 2: Pre-Deploy Checks

- [ ] All PRs approved
- [ ] All CI checks passing
- [ ] No merge conflicts
- [ ] Manual pre-deploy steps documented (if any)

### Step 3: Execute Pre-Deploy Steps

If `manual-steps.md` has Pre-Deployment section, execute those steps first.

### Step 4: Merge PRs

```bash
gh pr merge {pr_number} --merge
```

### Step 5: Deploy

{{DEPLOY_COMMAND}}

### Step 6: Post-Deploy Steps

If `manual-steps.md` has Post-Deployment section, execute or prompt for manual steps.

### Step 7: Notify

{{NOTIFY_DEPLOY_SUCCESS}}

### Step 8: Update Tracker

{{TRACKER_SET_DEPLOYED}}

## Edge Cases

| Scenario | Behavior |
|----------|----------|
| PR not approved | Warn, don't proceed |
| CI checks failing | Warn, don't proceed |
| Merge conflict | Attempt auto-resolve or halt |
| Deploy fails | Post error, rollback if possible |
| Manual steps required | Pause, list steps, wait for confirmation |

## Related Skills

- `/develop` — creates the PR that this skill deploys
- `/factory` — factory pipeline auto-deploys via CI
