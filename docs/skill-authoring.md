# Skill Authoring Guide

How to create new skills for the Claude Code framework.

## Quick Start

```bash
# Copy the template
cp -r .claude/skills/_template .claude/skills/my-skill

# Edit the skill file
# .claude/skills/my-skill/SKILL.md
```

## Skill Structure

```
my-skill/
├── SKILL.md              # Required — skill definition
├── references/           # Optional — domain knowledge, specs
│   ├── objects.md
│   └── api-specs.md
└── examples/             # Optional — example outputs (few-shot)
    └── example-output.md
```

## SKILL.md Format

```markdown
---
name: my-skill
description: One-line description. Claude uses this to decide relevance.
---

# Skill Title

Brief purpose description.

## Usage

\`\`\`
/my-skill argument
/my-skill --flag value
\`\`\`

## Process

### Phase 1: {Name}
{Detailed instructions}

### Phase 2: {Name}
{Detailed instructions}

## Edge Cases

| Scenario | Behavior |
|----------|----------|
| {case} | {action} |

## Related Skills

- `/other-skill` — relationship description
```

## Writing Effective Skills

### Be Specific

Claude follows instructions literally. Vague instructions produce inconsistent results.

**Bad:** "Check the code for issues"
**Good:** "Grep for `console.log` in non-test `.ts` files. Each occurrence is an ERROR."

### Include Commands

Don't describe what to do — show the exact command:

**Bad:** "Query the work item tracker"
**Good:**
```bash
PAT=$(grep AZURE_DEVOPS_EXT_PAT .env | cut -d= -f2)
curl -s "https://dev.azure.com/org/project/_apis/wit/workitems/{id}" -u ":${PAT}"
```

### Use Tables for Decision Logic

Tables are unambiguous:

| Condition | Action |
|-----------|--------|
| Score >= 20, no FAIL checks | PASS |
| Score < 20 OR any FAIL check | FAIL |

### Include Edge Cases

Claude handles edge cases well when you document them. The edge cases table is one of the most impactful sections.

### Reference Other Skills by Name

Skills chain naturally when they reference each other:
- "Invoke `/validate {TICKET_ID}` as a parallel sub-agent"
- "If gaps found, recommend running `/refine-story` first"

## Skill Categories

### Lifecycle Skills
Multi-phase workflows that drive the development process.
- Many phases (5-8)
- Chain other skills
- Support `--factory` flag for automation
- Examples: `/develop`, `/factory`

### Planning Skills
Analyze content and produce structured reports.
- Focus on analysis and gap detection
- Produce markdown reports
- Interactive question resolution
- Examples: `/draft-story`, `/check-readiness`

### Integration Skills
Connect to external systems.
- Call REST APIs
- Handle authentication
- Manage state transitions
- Examples: `/update-tracker`, `/error-analyze`

### Meta Skills
Modify the AI system itself.
- Change skills, references, CLAUDE.md
- Self-improving system
- Examples: `/ai-update`, `/add-reference`

### Domain Skills
Project-specific knowledge and patterns.
- No process logic — pure reference
- Rich `references/` directory
- Examples: payments, inventory, notifications (project-specific domains)

## Adding References

References give skills domain context. Two types:

### Codebase Inventories
Scan the codebase and document what exists:

```markdown
# My Domain Objects Reference

## User

**Purpose:** Application user entity

| Field | Type | Notes |
|-------|------|-------|
| `email` | String | Unique, required |
| `role` | Enum | admin/editor/viewer |
| `team_id` | FK | References Team |
```

### Domain Knowledge
External knowledge not in the codebase:

```markdown
# Tax Deduction Rules

## ROT (Home Renovation)

| Work Type | Max Deduction | Rate |
|-----------|--------------|------|
| Plumbing | 50,000 SEK | 30% |
| Electrical | 50,000 SEK | 30% |

## Source
Skatteverket: https://www.skatteverket.se/rotavdrag
```

## Registering Skills

Skills are auto-discovered by Claude Code from `.claude/skills/*/SKILL.md`. To make them visible in the help system, add them to CLAUDE.md:

```markdown
## Skills Available

| Skill | Purpose |
|-------|---------|
| `/my-skill` | What it does |
```

## Testing Skills

1. Invoke the skill: `/my-skill test-input`
2. Check that each phase executes correctly
3. Verify edge cases are handled
4. Check that output matches expected format
5. If it chains other skills, verify the chain works

## Common Patterns

### Factory Flag
```markdown
**Factory mode:** Skip this phase — readiness gate already passed.

**Interactive mode:** Ask the user...
```

### Parallel Sub-Agents
```markdown
Launch **two sub-agents in parallel**:
- Sub-agent A: deployment validation
- Sub-agent B: code standards check

Wait for both. If either fails → Phase 6.
```

### Retry with Max Attempts
```markdown
**Max 3 attempts.** For each failure:
1. Parse error
2. Apply fix
3. Retry

After 3 failures → halt and notify.
```

### Tracker Placeholders
Use `{{TRACKER_*}}` placeholders for operations that vary by tracker:
- `{{TRACKER_FETCH_TICKET}}` — fetch ticket details
- `{{TRACKER_SET_IN_PROGRESS}}` — transition to in-progress
- `{{TRACKER_CREATE_TICKET}}` — create new ticket
- `{{TRACKER_TICKET_URL}}` — link to ticket
