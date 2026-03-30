---
patterns:
  - "skills/*/SKILL.md"
---

# Skill File Rules

When editing skill definition files, follow these rules:

## Format
- YAML frontmatter must include: `name` and `description`
- Description is used by Claude to decide when to invoke — make it clear and specific
- Use numbered phases for complex workflows
- Include an Edge Cases table
- Include a Related Skills section linking to dependent/related skills

## Placeholders
- Use `{{PLACEHOLDER}}` syntax for project-specific values
- Every placeholder must be replaced by both `setup.sh` and `setup.ps1`
- Common: `{{BASE_BRANCH}}`, `{{TEST_COMMAND}}`, `{{FORMAT_COMMAND}}`, `{{TRACKER_FETCH_TICKET}}`

## Consistency
- When adding a new skill, also update:
  - `templates/CLAUDE.md.template` Skills Available table
  - `README.md` skills table
  - `docs/architecture.md` file tree
  - `setup.sh` and `setup.ps1` summary output (skill count)
