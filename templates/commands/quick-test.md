---
name: quick-test
description: Run the project test suite on changed files only
allowed-tools: Bash, Read
---

Run tests scoped to files changed since the base branch.

## Steps

1. Get changed files:
```bash
git diff {{BASE_BRANCH}}...HEAD --name-only --diff-filter=ACMR
```

2. Run tests on changed files:
```bash
{{TEST_COMMAND}}
```

3. Report pass/fail summary. Do not attempt to fix failures — just report what passed and what failed with error details.
