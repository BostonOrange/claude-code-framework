---
name: refine-story
description: Ticket refinement and gap analysis - analyzes existing tickets, identifies gaps, scans codebase, and generates refined documentation. Use when improving existing tickets or doing a quick gap check.
---

# Story Refinement

Refine existing tickets for the development team. Write for a technical audience — direct, concise, specific identifiers.

**When to use this vs `/draft-story`:**
- `/refine-story` — Existing ticket that needs improvement
- `/draft-story` — New requirements or design document → create new tickets

## Process

1. User provides ticket content or ID
2. Run gap analysis (quick scan + gap report)
3. If gaps found, present gap report and collaborate to fill
4. Generate docs in `docs/stories/TICKET-{id}/`

## Step 1: Gap Analysis

### Gap Report Template

#### Technical Gaps

| Gap Type | Status | Details |
|----------|--------|---------|
| Field/property specifications | OK / Missing | {missing} |
| Entity relationships | OK / Missing | {missing} |
| Type definitions | OK / Missing | {missing} |
| Enum/picklist values | OK / Missing | {missing} |

#### Business Logic Gaps

| Gap Type | Status | Details |
|----------|--------|---------|
| Trigger conditions | OK / Missing | {missing} |
| Calculation formulas | OK / Missing | {missing} |
| Workflow steps | OK / Missing | {missing} |
| Validation rules | OK / Missing | {missing} |

#### Integration Gaps

| System | Status | Details |
|--------|--------|---------|
| {External System 1} | OK / Missing / N/A | {missing} |
| {External System 2} | OK / Missing / N/A | {missing} |

#### Security Gaps

| Gap Type | Status | Details |
|----------|--------|---------|
| Access control | OK / Missing | {missing} |
| Field-level security | OK / Missing | {missing} |
| Sharing/visibility rules | OK / Missing | {missing} |

#### Testing Gaps

| Gap Type | Status | Details |
|----------|--------|---------|
| Acceptance criteria testable | OK / Missing | {missing} |
| Edge cases defined | OK / Missing | {missing} |
| Error scenarios | OK / Missing | {missing} |

### Readiness Summary

**Refinement Status:** Ready / Needs Minor Refinement / Needs Major Refinement

**Priority Questions:**
1. {Most critical}
2. {Second}
3. {etc.}

## Step 2: Codebase Scan

Search for affected components in the codebase to ground the analysis.

## Step 3: Collaborate & Fill Gaps

Present gap report. Work through priority questions before drafting.

## Step 4: Output Files

Create in `docs/stories/TICKET-{id}/`:

| File | Purpose |
|------|---------|
| `story.md` | Ticket with ACs, technical spec |
| `solutions-components.md` | Components changed/created |
| `how-to-test.md` | Test instructions |
| `manual-steps.md` | Manual pre/post deployment steps |

## Step 5: Tracker Sync

After updating local docs, sync to tracker. Follow write-to-tracker rule:
1. Check if ticket exists → create if not, update if yes
2. If tracker was updated since last local commit, compare and merge
3. Push updated content

## Quality Checklist

- [ ] Specific mappings with identifiers (not display names)
- [ ] Explicit values verified from source of truth
- [ ] Clear relationships with entity names
- [ ] Trigger conditions defined
- [ ] No verbose Given/When/Then

## Related Skills

- `/draft-story` - New tickets from requirements
- `/check-readiness` - Automated readiness validation
- Domain skills - Project-specific context
