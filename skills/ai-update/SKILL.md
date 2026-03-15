---
name: ai-update
description: Create a branch and PR for AI process updates (CLAUDE.md, skills, references, templates). Use after making changes to AI enablement files.
---

# AI Update

Create a feature branch and open a PR for AI process/tooling changes.

## Usage

```
/ai-update                           # Auto-detect changed AI files
/ai-update "add validate skill"      # With a description
```

## Scope

AI process files:

| Path | Content |
|------|---------|
| `CLAUDE.md` | Project-level instructions |
| `.claude/skills/*/SKILL.md` | Skill definitions |
| `.claude/skills/*/references/*.md` | Skill references |
| `.claude/skills/*/examples/*.md` | Skill examples |
| `.claude/settings.json` | Claude Code settings |

## Process

### 1. Identify Changes

```bash
git status --short
```

Filter to AI-scoped paths. If no AI files changed, stop.

### 2. Create Branch

Branch naming: `ai/{short-description}`

```bash
git fetch origin {{BASE_BRANCH}}
git checkout -b ai/{slug} origin/{{BASE_BRANCH}}
```

### 3. Stage AI Files

Stage only AI-scoped files:

```bash
git add CLAUDE.md
git add .claude/skills/
```

### 4. Commit

```
chore(ai): {short description}

{bullet list of changes}
```

### 5. Push & Create PR

```bash
git push -u origin ai/{slug}
gh pr create --base {{BASE_BRANCH}} --assignee @me \
  --title "chore(ai): {description}" \
  --body "$(cat <<'EOF'
## Summary
- {changes}

## Files Changed
- {list}
EOF
)"
```

## Edge Cases

| Scenario | Behavior |
|----------|----------|
| No AI files changed | Stop, inform user |
| Mixed AI + code changes | Stage only AI files, warn about unstaged code |
| Already on `ai/*` branch | Reuse it |

## Related Skills

- `/add-reference` — add knowledge docs (often shipped via this skill)
- `/validate` — code validation (often shipped via this skill)
