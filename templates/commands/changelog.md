---
name: changelog
description: Generate a changelog entry from commits since the last tag
allowed-tools: Bash, Read, Grep
---

Generate a formatted changelog entry from recent commits.

## Steps

1. Find the last tag:
```bash
git describe --tags --abbrev=0 2>/dev/null || echo "no-tags"
```

2. Get commits since last tag (or all commits if no tags):
```bash
git log $(git describe --tags --abbrev=0 2>/dev/null || git rev-list --max-parents=0 HEAD)..HEAD --oneline --no-merges
```

3. Group commits by conventional commit type:
   - **Features** (`feat:`)
   - **Bug Fixes** (`fix:`)
   - **Performance** (`perf:`)
   - **Breaking Changes** (`BREAKING CHANGE:` or `!:`)
   - **Other** (everything else)

4. Output formatted changelog:

```
## [Unreleased]

### Features
- {commit message} ({short hash})

### Bug Fixes
- {commit message} ({short hash})

### Other Changes
- {commit message} ({short hash})
```

If no conventional commit prefixes are found, list all commits under "Changes".
