---
name: error-analyze
description: Triage production errors from your monitoring system. Queries new errors, groups patterns, analyzes root cause with codebase context, and lets developer create tickets or dismiss. Supports unattended CI mode.
---

# Error Analyze

Triage errors from your monitoring/error tracking system. Analyze with codebase context, then create tickets or dismiss.

## Usage

### Interactive (developer-driven)

```
/error-analyze
/error-analyze --type integration
/error-analyze --since 24h
```

### CI / Unattended

```
/error-analyze --ci --env prod --since 24h
```

CI mode runs fully automated — tickets are auto-created. See CI section below.

## Phase 1: Query Errors

{{ERROR_QUERY_COMMAND}}

Parse the output to extract:
- Error ID
- Error message
- Error type/category
- Source component
- Stack trace
- Timestamp
- Affected user (if available)

## Phase 2: Group & Summarize

Group errors by source + type. Present triage summary:

```
## Error Triage Summary

Found {N} new errors across {M} sources.

| # | Source | Type | Count | Latest | Sample Error |
|---|--------|------|-------|--------|-------------|
| 1 | ComponentA | Runtime | 23 | 2026-03-05 14:30 | NullPointerException... |
| 2 | IntegrationB | HTTP | 5 | 2026-03-05 12:15 | Timeout... |
```

## Phase 3: Analyze Each Group

For each group:
1. **Find source component** in codebase
2. **Read the code** around the error location
3. **Analyze root cause**
4. **Suggest fix**

```
### Group 1: ComponentA (Runtime) — 23 errors

**Pattern:** All errors are NullPointerException on record access
**Root Cause:** Missing null check before accessing optional field
**Suggested Fix:** Add null guard before field access
**Severity:** High — blocking core workflow
```

## Phase 4: Triage Decisions

For each group:
- **Create ticket** → draft work item with analysis context
- **Dismiss** → mark as resolved with reason
- **Skip** → leave as new

### Action: Create Ticket

{{TRACKER_CREATE_BUG}}

Update error records:
{{ERROR_UPDATE_STATUS}}

### Action: Dismiss

{{ERROR_DISMISS}}

## Phase 5: Summary

```
## Triage Complete

| Group | Action | Result |
|-------|--------|--------|
| ComponentA | Ticket created | TICKET-1600 |
| IntegrationB | Dismissed | Transient timeout |

Remaining new errors: {count}
```

## CI / Unattended Mode

When `--ci` flag is present, runs fully automated:

| Aspect | Interactive | CI Mode |
|--------|------------|---------|
| Environment selection | Ask user | Required via `--env` flag |
| Triage decisions | Developer picks | Auto-create ticket for all groups |
| Work item type | Story | Bug |
| Confirmation prompts | Yes | None |
| Duplicate detection | N/A | Check tracker for existing open bugs |
| Error status update | Per choice | All → In Progress |

### Duplicate Detection

Before creating a ticket, query tracker for existing open bugs with same source.
- If found → add comment to existing ticket
- If not found → create new bug

### Severity Mapping

| Severity | Criteria |
|----------|----------|
| Critical | Integration failures blocking operations, data loss risk, >50 occurrences |
| High | Recurring (10+), user-facing failures, affects core workflows |
| Medium | Intermittent (<10), workaround exists, non-blocking |
| Low | Single occurrence, cosmetic, edge case |

## Related Skills

- `/develop` — develop a ticket created from error triage
- `/refine-story` — further refine an error-based ticket
