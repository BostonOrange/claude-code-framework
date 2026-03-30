---
name: dep-check
description: Check for outdated or vulnerable dependencies
allowed-tools: Bash, Read
---

Check project dependencies for updates and known vulnerabilities.

## Steps

1. Run dependency check:
```bash
{{DEP_CHECK_COMMAND}}
```

2. Summarize results in a table:

| Package | Current | Latest | Type |
|---------|---------|--------|------|
| {name} | {version} | {version} | {major/minor/patch} |

3. Highlight any security vulnerabilities separately with severity level.

4. Recommend which updates are safe (patch/minor) vs which need careful review (major).
