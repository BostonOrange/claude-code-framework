---
name: check-types
description: Run the project type checker
allowed-tools: Bash
---

Run the type checker and report results.

## Steps

1. Run type check:
```bash
{{TYPE_CHECK_COMMAND}}
```

2. Report results:
   - If clean: "Type check passed — no errors."
   - If errors: list each error with file path and line number.
