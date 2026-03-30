---
name: branch-status
description: Show current branch status — diff stats, PR status, CI checks
allowed-tools: Bash, Read
---

Show a consolidated view of the current branch state.

## Steps

1. Show diff stats against base branch:
```bash
git diff {{BASE_BRANCH}}...HEAD --stat
```

2. Show commit count:
```bash
git rev-list {{BASE_BRANCH}}..HEAD --count
```

3. Check for open PR:
```bash
gh pr view --json number,title,state,reviews,statusCheckRollup 2>/dev/null || echo "No PR found for this branch"
```

4. If PR exists, show CI check status:
```bash
gh pr checks 2>/dev/null || true
```

5. Summarize in a clean table:
   - Branch name and commits ahead
   - Files changed (added/modified/deleted counts)
   - PR status (draft/open/approved/changes requested)
   - CI status (passing/failing/pending)
