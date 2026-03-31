---
name: improve
description: Self-improvement — analyze the project and update CLAUDE.md, rules, settings, and agents to improve AI effectiveness
---

# Improve — Framework Self-Improvement

Analyze the current project state and improve the .claude/ configuration for better AI assistance.

## Usage

```
/improve                  — Full improvement pass (all areas)
/improve claude-md        — Update CLAUDE.md only (fill placeholders, add patterns)
/improve rules            — Update rule file patterns to match actual project
/improve settings         — Update permissions and model config
/improve agents           — Tune agent tools and models for project needs
/improve scan             — Report only, no changes (dry run)
```

## Process

### Phase 1: Project Discovery

Scan the project to build a comprehensive profile:

1. **Tech stack detection:**
```bash
# Package managers and dependency files
ls package.json requirements.txt Pipfile go.mod Cargo.toml build.gradle pom.xml Gemfile composer.json sfdx-project.json 2>/dev/null
```

2. **File type census:**
```bash
find . -type f -not -path "*/.git/*" -not -path "*/node_modules/*" -not -path "*/__pycache__/*" -not -path "*/vendor/*" -not -path "*/.next/*" -not -path "*/dist/*" -not -path "*/build/*" | sed 's/.*\.//' | sort | uniq -c | sort -rn | head -20
```

3. **Framework detection:** Read config files (next.config.*, vite.config.*, angular.json, etc.)

4. **Directory structure:** Map the top-level architecture

5. **Existing tooling:** Find linter configs, test configs, CI configs

### Phase 2: CLAUDE.md Improvement

Read current CLAUDE.md and check:

1. **Unfilled placeholders:** Find any remaining `{{...}}` and fill from discovered data:
   - `{{PROJECT_DESCRIPTION}}` — from README.md, package.json description, etc.
   - `{{TECH_STACK_TABLE}}` — build from dependency files
   - `{{CODE_STRUCTURE}}` — generate directory tree
   - `{{CODING_STANDARDS}}` — infer from linter configs (.eslintrc, .prettierrc, pyproject.toml, etc.)
   - `{{ERROR_HANDLING_PATTERN}}` — find common error patterns in code
   - `{{TESTING_STRATEGY}}` — infer from test config and existing tests
   - `{{INTEGRATIONS}}` — list discovered external services

2. **Missing information:** Add sections for:
   - Discovered environment variables and their purposes
   - Common commands found in package.json scripts or Makefile
   - Team conventions visible in git log patterns

3. **Outdated information:** Check if documented commands, paths, or patterns still exist

If `--scope claude-md` or full pass: apply changes. Otherwise skip.

### Phase 3: Rules Improvement

For each rule file in `.claude/rules/`:

1. **Verify patterns match reality:**
   - Extract the glob patterns from the YAML frontmatter
   - Check if files matching those patterns actually exist
   - If patterns are still `{{PLACEHOLDER}}`, replace with discovered file patterns

2. **Add missing rules:**
   - If the project has file types not covered by any rule, consider adding rules
   - Common gaps: middleware files, config schemas, migration files, test utilities

3. **Remove irrelevant rules:**
   - If a rule's file patterns match zero files, warn (don't delete — user may add files later)

If `--scope rules` or full pass: apply changes. Otherwise skip.

### Phase 4: Settings Improvement

Read `.claude/settings.local.json` and check:

1. **Permissions:** Are all tools the project workflow needs allowed?
   - If project uses git heavily, ensure Bash(git*) patterns
   - If project needs web access for docs, ensure WebFetch/WebSearch

2. **Model:** Is the default model appropriate?
   - Complex architecture projects may benefit from opus
   - High-volume code generation may benefit from sonnet for speed

If `--scope settings` or full pass: apply changes. Otherwise skip.

### Phase 5: Agent Improvement

For each agent in `.claude/agents/`:

1. **Tool appropriateness:** Do the allowed tools match what the agent needs?
2. **Model selection:** Is the model appropriate for the task complexity?
3. **Placeholder check:** Are any `{{PLACEHOLDER}}` values unfilled?

If `--scope agents` or full pass: apply changes. Otherwise skip.

### Phase 6: Report

```
## Framework Improvement Report

### Project Profile
- **Type:** {detected project type}
- **Stack:** {tech stack summary}
- **Size:** {file count, LOC estimate}

### Changes Made
| File | Change | Reason |
|------|--------|--------|
| {path} | {description} | {why} |

### CLAUDE.md Status
- Placeholders filled: {n}
- Placeholders remaining: {n} (need human input)
- Sections added: {list}
- Sections updated: {list}

### Rules Status
- Rules with matching files: {n}/{total}
- Patterns updated: {list}
- New rules created: {list}

### Recommendations (need human decision)
- {items that require human judgment}

### Next Steps
1. Review changes in CLAUDE.md and fill remaining placeholders
2. Run `/improve scan` again after making manual updates
3. Consider `/team review` to validate the improved configuration
```

## Edge Cases

| Scenario | Behavior |
|----------|----------|
| CLAUDE.md doesn't exist | Create from template, fill what's discoverable |
| No .claude/ directory | Run setup.sh first (print instructions) |
| `--scope scan` | Report only, make no changes |
| Mixed project (frontend + backend) | Detect both, configure rules for both |
| Monorepo with multiple apps | Detect workspace structure, note in CLAUDE.md |

## Related Skills

- `/ai-update` — Create branch + PR for AI config changes (use after /improve for tracked changes)
- `/add-reference` — Add domain knowledge references
- `/team full` — Run all agents to validate improved configuration
