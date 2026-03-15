---
name: check-readiness
description: Automated readiness gate for tickets before implementation. Scans for TBDs, vague acceptance criteria, missing specs, unresolved questions, and integration gaps. Use before /develop to catch incomplete tickets early.
---

# Check Readiness

Automated readiness gate — validates a ticket is implementation-ready before entering `/develop`.

## Usage

```
/check-readiness TICKET-1234
/check-readiness 1234
```

## Purpose

20-30% of tickets arrive in `/develop` needing major refinement, causing the dev cycle to halt. This skill runs automated checks to catch gaps early and return structured feedback before development starts.

## Phase 1: Fetch Ticket Content

Parse ticket ID from input.

{{TRACKER_FETCH_TICKET}}

Extract:
- Title
- Description (story body, tech spec, field mappings)
- Acceptance Criteria
- Test instructions
- Deployment notes / tech spec

Also check local docs if they exist: `docs/stories/TICKET-{id}/story.md`

## Phase 2: Run Readiness Checks

### Check 1: No Placeholder Text (FAIL)

Scan all content for:
- `TBD`, `TBC`, `TBA` (case-insensitive)
- `TODO` outside of code blocks
- `[placeholder]` or `{placeholder}` patterns
- `???` or `...` used as placeholders

### Check 2: Data Model Completeness (FAIL)

For each data/field reference in the ticket:
1. Identify the entity and field
2. Look up existing definitions in the codebase
3. Verify the referenced values are valid (enum values, types, relationships)

### Check 3: Testable Acceptance Criteria (WARN)

Scan each AC for vague language:
- "should update" without specifying from/to values
- "appropriate" without defining what qualifies
- "relevant" without listing which items
- "as needed" without conditions
- "properly" or "correctly" without measurable criteria

### Check 4: No Unresolved Open Questions (FAIL)

Scan for:
- "Open Questions" section with unresolved items
- Items marked with `?`, `OPEN`, or no answer
- Comments with unanswered questions

### Check 5: Explicit Technical Specs (FAIL)

Scan for:
- Vague references: "the field on the account", "the status field"
- Missing API names / identifiers
- Incomplete mappings: source specified but no target

### Check 6: Integration Contracts (WARN)

If the ticket involves integrations, check for:
- Payload structure defined
- Endpoint specified
- Authentication documented
- Error handling specified
- Retry strategy documented

### Check 7: Dependencies Documented (WARN)

Check for:
- Pre-deploy dependencies not listed
- Manual steps not documented
- Cross-ticket dependencies
- External system dependencies

### Check 8: Auto vs Semi-Auto Classification (INFO)

Classify for factory pipeline routing:

**Auto** — all changes deployable via CI/CD:
- Code, configuration, scripts
- Pre/post-deploy steps that are CLI commands

**Semi-auto** — requires manual configuration:
- UI-only configuration
- External service setup
- Manual data migrations

## Phase 3: Score & Route

### Scoring

| Result | Score Impact |
|--------|-------------|
| Each FAIL check | -10 points |
| Each WARN check | -3 points |
| Each PASS check | +5 points |

- **PASS** (score >= 20): All FAIL checks pass → ready for implementation
- **FAIL** (score < 20 OR any FAIL check): Significant gaps → return to architect

### Output: Readiness Report

```markdown
## Readiness Report — TICKET-{id}: {title}

### Result: {PASS | FAIL}
Score: {score}/40

### Pipeline Classification: {AUTO | SEMI-AUTO}

### Check Results

| # | Check | Result | Details |
|---|-------|--------|---------|
| 1 | No Placeholder Text | PASS/FAIL | {count} placeholders found |
| 2 | Data Model Complete | PASS/FAIL | {count} incomplete specs |
| 3 | Testable ACs | PASS/WARN | {count} vague criteria |
| 4 | No Open Questions | PASS/FAIL | {count} unresolved |
| 5 | Explicit Tech Specs | PASS/FAIL | {count} vague references |
| 6 | Integration Contracts | PASS/WARN | {count} missing elements |
| 7 | Dependencies Documented | PASS/WARN | {count} undocumented |
| 8 | Classification | AUTO/SEMI | {reasoning} |

### Gap Details
{For each non-PASS check, list specific findings with suggestions}

### Recommended Actions
{Numbered list of actions to resolve gaps}
```

## Phase 4: Route Based on Result

### If PASS
> **TICKET-{id} is ready for implementation.** Proceed with `/develop` or `/factory`.

### If FAIL

**Interactive mode:** Show report, ask how to proceed:
1. Return to architect — post gap report, transition to "needs info" state
2. Override — proceed despite gaps
3. Fix inline — address gaps now and re-check

**Factory mode (`--factory`):** Automatically return to architect:
1. Post gap report to tracker
2. Transition to "needs info" state
3. Halt

## Related Skills

- `/develop` — calls `/check-readiness` in factory mode
- `/refine-story` — deeper refinement for failed readiness checks
- `/factory` — invokes this skill as first gate
