---
name: update-tracker
description: Update work item tracker with story documentation (solution components, how-to-test, manual steps). Use after developing or refining a ticket to push docs back to the tracker.
---

# Update Tracker

Push local story documentation back to the work item tracker.

## Usage

```
/update-tracker TICKET-1234
/update-tracker 1234
```

## Field Mapping

| Tracker Field | Source |
|---------------|--------|
| Description | `story.md` (User Story, Background, Business Rules, Dependencies) |
| Acceptance Criteria | `story.md` `## Acceptance Criteria` section |
| Test Instructions | `how-to-test.md` |
| Deployment Notes | `story.md` `## Technical Specification` + `manual-steps.md` |

## Process

### Step 1: Parse Input & Locate Docs

Verify local docs exist at `docs/stories/TICKET-{id}/`:
- `story.md` (required)
- `how-to-test.md` (optional)
- `manual-steps.md` (optional)

### Step 2: Check Ticket Exists

{{TRACKER_FETCH_TICKET}}

If doesn't exist → create it first, then continue.
If exists → extract current field values and last modified timestamp.

### Step 3: Sync Check

Before overwriting, compare tracker content with local docs:
1. Compare last modified timestamps
2. If tracker is newer, **diff both versions field by field**
3. Propose merged version incorporating both sides
4. Get user approval before pushing

### Step 4: Parse story.md into Sections

Split `story.md` into parts based on section headers:
1. **Description** — everything through Dependencies and Out of Scope
2. **Acceptance Criteria** — the ACs section
3. **Technical Specification** — the tech spec section

### Step 5: Build & Push Update

{{TRACKER_UPDATE_FIELDS}}

### Step 6: Confirm

After successful update:
1. Confirm success with revision info
2. Provide direct link to ticket
3. Clean up temp files

## Edge Cases

| Scenario | Behavior |
|----------|----------|
| `story.md` missing | Stop — required |
| `how-to-test.md` missing | Skip test field update |
| `manual-steps.md` missing | Deployment notes = tech spec only |
| Tracker updated after local docs | Warn, show diff, offer merge |
| Auth not configured | Prompt user |

## Related Skills

- `/develop` — calls this skill in Phase 8
- `/refine-story` — story refinement
- `/draft-story` — draft new stories
