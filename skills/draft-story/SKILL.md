---
name: draft-story
description: Create new tickets from business requirements or design documents. Analyzes requirements, scans codebase, identifies gaps and open questions, and drafts complete refined tickets.
---

# Draft Story

Create complete, refined tickets from business requirements or design documents. Write for a technical audience — direct, concise, specific identifiers over display names.

**When to use this vs `/refine-story`:**
- `/draft-story` — New requirements or design document → create new tickets
- `/refine-story` — Existing ticket that needs improvement or gap analysis

## Input Sources

### 1. Business Requirements (ad-hoc)
User describes a business need or feature request verbally. Follow the full interview process.

### 2. Design Documents (pasted or fetched)
User provides a structured design document. These typically include:
- Objective / Overview
- Open Questions
- Technical Design (data flows, endpoint specs, field mappings)
- Data Model Changes
- Business Logic
- Integration Details

Design docs may cover **multiple tickets** — propose how to split.

## Process

### From business requirements:
1. User describes business need
2. Ask clarifying questions (Who, What, Why, When, Where)
3. Explore codebase for relevant patterns
4. Fetch documentation using the `/fetch-docs` skill pattern (resolve-library-id then get-library-docs) when the solution involves external dependencies — verify actual API capabilities before committing to a technical approach
5. Propose solution options if multiple approaches exist
5. Draft complete ticket
6. Present open questions for stakeholder follow-up
7. Save to `docs/stories/TICKET-{id}/` or `docs/stories/DRAFT-{name}/`

### From design documents:
1. User provides design document content
2. Parse all sections — identify scope, TBDs, and open questions
3. Clarify architecture early: sync vs async, data flow direction
4. Explore codebase to verify existing components
5. Identify gaps: what the doc leaves unresolved
6. If doc covers multiple tickets, propose split and ask which to draft
7. Draft complete ticket with design doc section references
8. **Surface open questions** — grouped by source (doc TBDs vs codebase gaps)
9. **Resolve open questions interactively** — work through each one
10. Save to `docs/stories/TICKET-{id}/` or `docs/stories/DRAFT-{name}/`

### Open Question Resolution Loop (Step 9)

After surfacing open questions, **do not stop**:
1. Present questions grouped by priority (blocking → important → nice-to-have)
2. For each question: state recommendation, ask for decision, update ticket
3. After all addressed:
   - All resolved → ticket is **implementation-ready**. Mark as ready.
   - Some deferred → mark as needs refinement. List deferred items clearly.
4. An implementation-ready ticket can go straight to `/factory`

## Open Questions Output

Every draft must include an **Open Questions** section. Group by source:
1. **From the design doc** — TBDs, explicitly listed questions
2. **From codebase analysis** — naming conflicts, missing config, pattern mismatches
3. **From gap analysis** — ambiguous rules, missing specs, unclear contracts

Each question must include:
- **Reference** to the source section
- **Context** — what the source says and why it's a problem
- **Impact** — what's blocked if unresolved
- **Recommendation** — suggested resolution with trade-offs

## Story Documentation

Create `docs/stories/TICKET-{id}/` (or `DRAFT-{name}/`) with:

| File | Content |
|------|---------|
| `story.md` | Full ticket with ACs, technical spec |
| `solutions-components.md` | Components to change/create |
| `how-to-test.md` | Test instructions |
| `manual-steps.md` | Manual pre/post deployment steps (if needed) |

## Tracker Sync

After drafting locally, **sync to work item tracker**.

### Creating a new ticket
{{TRACKER_CREATE_TICKET}}

After creation:
1. Extract new ticket ID from response
2. Rename local folder: `DRAFT-{name}/` → `TICKET-{id}/`
3. Update `story.md` title
4. Confirm to user with link

### If user declines sync
Keep `DRAFT-{name}/` folder. Remind to create ticket later.

## Writing Style

- Specific field/property mappings with identifiers
- Explicit values (enum values verified from source, not display names)
- Clear relationships with entity names
- Trigger conditions for automation
- No verbose Given/When/Then — go direct
- When sourced from a design doc, add section references for traceability
- Tables over paragraphs

## Factory Pipeline Integration

When all open questions are resolved:
```
/draft-story (resolve everything)
    → Ticket marked "Ready for Sprint"
    → /factory TICKET-{id} (automated from here)
```

## Related Skills

- `/refine-story` - Refine existing tickets
- `/factory` - End-to-end pipeline (next step after drafting)
- `/check-readiness` - Automated readiness validation
- `/update-tracker` - Push ticket content to tracker
