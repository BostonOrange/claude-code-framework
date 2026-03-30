---
name: lint-fix
description: Run linter and auto-fix all fixable issues in changed files
allowed-tools: Bash, Read, Glob
---

Auto-fix lint and formatting issues in files changed since the base branch.

## Steps

1. Get changed files:
```bash
git diff {{BASE_BRANCH}}...HEAD --name-only --diff-filter=ACMR
```

2. Run formatter/linter with auto-fix on changed files:
```bash
{{FORMAT_COMMAND}}
```

3. Verify all issues resolved:
```bash
{{FORMAT_VERIFY_COMMAND}}
```

4. Report what was fixed. If issues remain that cannot be auto-fixed, list them.
