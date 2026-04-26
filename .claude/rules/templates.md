---
patterns:
  - "templates/**/*.md"
  - "templates/**/*.json"
  - "templates/**/*.sh"
---

# Template File Rules

When editing template files, follow these rules:

## Placeholders
- Use `{{PLACEHOLDER_NAME}}` syntax for all project-specific values
- Placeholder names must be UPPER_SNAKE_CASE
- Every placeholder must have a corresponding replacement in both `setup.sh` AND `setup.ps1`
- Document new placeholders in CLAUDE.md's "Key Conventions" section

## Agent Templates
- YAML frontmatter must include: `name`, `description`, `tools`, `model`
- Model should be `opus` unless there's a specific reason for another
- Include a structured report format in the final step
- Read-only agents must NOT have `Edit` or `Write` in their tools list

## Command Templates
- YAML frontmatter must include: `name`, `description`, `allowed-tools`
- Commands should be single-purpose (one action, one output)
- Include the placeholder for project-specific commands (e.g., `{{TEST_COMMAND}}`)

## Rule Templates
- YAML frontmatter must include: `id` (kebab-case, matches filename without `.md`) and `patterns` array
- The `id` is the citation key reviewer agents use in findings — it MUST be stable forever (never rename, never reuse)
- Use `{{PATTERN_PLACEHOLDER}}` for project-specific file patterns
- Rules should be directives (imperative), not suggestions
- Keep rules actionable and verifiable

## Hook Scripts
- Must start with `#!/bin/bash` shebang
- Must handle missing arguments gracefully (`[ -z "$1" ] && exit 0`)
- Exit 0 for success, exit 1 for soft block (prompt user), exit 2 for hard block
- Must work on macOS, Linux, and Windows (Git Bash)

## Parity
- Changes to `setup.sh` MUST be mirrored in `setup.ps1`
- Changes to agent/command/rule/hook counts MUST update README.md, CLAUDE.md template, docs, and setup summaries
