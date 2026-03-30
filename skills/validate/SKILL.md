---
name: validate
description: Validate built code against project standards and conventions. Checks coding standards, test quality, naming, formatting, and configuration. Use after implementation to catch issues before committing.
---

# Validate

Validate code against project standards and conventions. Runs all checks and produces a report.

## Usage

```
/validate TICKET-1234          # Validate files for a specific ticket
/validate                      # Validate all uncommitted changes
```

## Process

1. **Identify changed files** — scope to ticket or all uncommitted changes
2. **Load domain references** — based on what's touched
3. **Run all checks** — see check matrix below
4. **Output report** — checklist with ERROR/WARN/PASSED counts

## Identifying Changed Files

**Ticket-scoped** (ID provided):
```bash
git diff --name-only origin/{{BASE_BRANCH}}...HEAD
```
Filter to files matching the ticket. Also check `docs/stories/{TICKET_ID}/`.

**All uncommitted** (no ID):
```bash
git diff --name-only HEAD
git diff --name-only --cached
```

## Check Matrix

> **IMPORTANT:** Customize this section for your project. The checks below are templates — replace with your actual coding standards.

### Code Standards (ERROR)

| Check | How to Detect | Severity |
|-------|---------------|----------|
| Error handling on catch blocks | Grep for catch blocks, verify each has proper error tracking | ERROR |
| No debug/console.log in production | Grep for debug statements in non-test files | ERROR |
| No commented-out code | Grep for patterns of commented code | WARN |
| No hardcoded secrets/IDs | Grep for patterns matching secrets, IDs, tokens | ERROR |
| Test classes/files follow conventions | Check test file naming and structure | ERROR |
| Type conventions | Check language-specific type usage | WARN |
| No queries/IO in loops | Check for performance anti-patterns | ERROR |
| Constants over magic values | Flag repeated string/number literals | WARN |

### Test Quality (ERROR)

| Check | How to Detect | Severity |
|-------|---------------|----------|
| No inline test data construction | Tests should use factories/fixtures | ERROR |
| No production data in tests | Check for `SeeAllData` or equivalent | ERROR |
| Uses test helpers/factories | Verify standard test patterns used | WARN |
| Adequate assertions | Check test methods have assertions | WARN |

### Naming Conventions (WARN)

| Check | How to Detect | Severity |
|-------|---------------|----------|
| Files follow naming pattern | Check against project conventions | WARN |
| Variables follow style guide | Check casing conventions | WARN |

### Formatting (ERROR)

```bash
{{FORMAT_VERIFY_COMMAND}}
```

If this fails, list which files need formatting. Do NOT auto-fix — report only.

### Configuration / Manifest (ERROR)

| Check | How to Detect | Severity |
|-------|---------------|----------|
| Ticket manifest exists | Check for ticket-specific config/manifest | ERROR |
| Main manifest updated | Verify new components in main config | ERROR |
| Version/API consistency | Check version numbers match project standard | ERROR |

## Domain Reference Loading

Based on changed files, load relevant domain skill references:

| Files Touched | Load References |
|---------------|-----------------|
| {domain-specific patterns} | `.claude/skills/{domain}/references/` |

Cross-check built components against reference inventories.

## Output Report

```
## Validation Report — {TICKET_ID}

### Summary
- ERRORS: {count}
- WARNINGS: {count}
- PASSED: {count}

### Code Standards
- [x] PASSED — Error handling on all catch blocks
- [ ] ERROR — Debug statement found in ClassName:42
- [x] PASSED — No hardcoded secrets

### Test Quality
- [x] PASSED — Uses test factories
- [ ] ERROR — Inline data construction found in TestFile:15

### Naming
- [x] PASSED — All conventions followed

### Formatting
- [x] PASSED — formatter check clean

### Configuration
- [x] PASSED — Manifests correct
```

## Integration with /develop

This skill is called by `/develop` Phase 5 as a parallel task alongside deployment validation.

## Related Skills

- `/develop` - Full dev cycle (calls `/validate` in Phase 5)
- Domain skills - Project-specific references
