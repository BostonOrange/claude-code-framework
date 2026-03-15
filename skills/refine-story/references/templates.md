# Story Document Templates

Single source of truth for all ticket output file templates. Referenced by `/refine-story`, `/draft-story`, and CLAUDE.md.

## Story Template (`story.md`)

```markdown
# TICKET-{id}: {Title}

## User Story
As a {persona}
I want to {goal}
So that {benefit}

## Background & Context
{Business context, current state, scope limitations}
{Reference design doc if applicable}

## Business Rules
- {Rule 1 with specific conditions}
- {Rule 2 with specific conditions}

## Dependencies
- {what must exist before deployment}

## Out of Scope
- {exclusions}

## Acceptance Criteria

### AC 1: {Short Title}
{Trigger/method} does {outcome}:
- `field` = `source.field`
- `status` = `value`

### AC 2: {Short Title}
On {condition}:
- {result}
- {result}

## Technical Specification

### New/Modified Entities

**Entity_Name**

| Property | Type | Notes |
|----------|------|-------|
| `field` | String | |
| `status` | Enum | value1/value2/value3 |

### Code Changes

| Module/Class | Purpose |
|-------------|---------|
| `ClassName` | Short description |

### Configuration
- {Config changes needed}
```

## Manual Steps Template (`manual-steps.md`)

```markdown
# Manual Steps - TICKET-{id}

## Pre-Deployment
- [ ] **{Step title}**
  {command or details}

## Post-Deployment
- [ ] **{Step title}**
  {details}

  | Setting | Value |
  |---------|-------|
  | Field | `Value` |

## Verification
- [ ] {Check that X works}
```

## How-to-Test Template (`how-to-test.md`)

```markdown
# How to Test - TICKET-{id}

## Automated Tests
- [ ] Run: `{test command}`

## Manual Testing

- [ ] **AC 1: {Short Title}**
  {Steps}
  **Verify:** {expected result}

- [ ] **AC 2: {Short Title}**
  {Steps}
  **Verify:** {expected result}
```

## Writing Style

- Write for a **technical audience**
- Be direct, no filler
- Use identifiers, not display names
- Tables over paragraphs
- Specific mappings: `field` = `source.field`
- Explicit values verified from source of truth
- Clear relationships with entity names
- Trigger conditions for automation
- No verbose Given/When/Then
