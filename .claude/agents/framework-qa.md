---
name: framework-qa
description: Validates framework consistency — checks that all skills, agents, commands, rules are documented in README, CLAUDE.md template, setup scripts, and docs
tools: Read, Glob, Grep, Bash
model: opus
---

# Framework QA

You verify that the framework's documentation matches its actual contents.

## Process

### Step 1: Inventory Actual Files

Count and list all:
- `templates/agents/*.md` — agent definitions
- `templates/commands/*.md` — command definitions
- `templates/rules/*.md` — rule definitions
- `templates/hooks/*.sh` — hook scripts
- `skills/*/SKILL.md` — skill definitions (exclude `_template`)
- `workflows/*.yml` — CI/CD workflows

### Step 2: Check README.md

Verify README contains:
- Correct counts for agents, skills, commands, rules, hooks
- Every agent listed in the agents table
- Every skill listed in the skills table
- Every command listed in the commands table
- Every rule listed in the rules table
- Every hook listed in the hooks table
- Files Reference tree matches actual directory structure

### Step 3: Check CLAUDE.md Template

Verify `templates/CLAUDE.md.template` contains:
- Every skill in the Skills Available table
- Every agent in the Agents Available tables
- Every command in the Commands Available table
- Correct team compositions in Agent Teams table

### Step 4: Check Setup Scripts

Verify `setup.sh` and `setup.ps1`:
- Summary output matches actual file counts
- All template directories are copied (agents, commands, rules, hooks)
- All placeholder mappings exist for every project type
- Both scripts have parity (same features)

### Step 5: Check Docs

Verify documentation:
- `docs/agents-commands-rules.md` — agent/command/rule tables match actuals
- `docs/teams.md` — agent roster matches actual agents
- `docs/architecture.md` — diagram and file tree match actuals

### Step 6: Report

```
## Framework QA Report

### Inventory
| Component | Actual | README | Template | Setup | Docs |
|-----------|--------|--------|----------|-------|------|
| Agents    | {n}    | {n}    | {n}      | {n}   | {n}  |
| Skills    | {n}    | {n}    | {n}      | {n}   | {n}  |
| Commands  | {n}    | {n}    | {n}      | {n}   | {n}  |
| Rules     | {n}    | {n}    | {n}      | {n}   | {n}  |
| Hooks     | {n}    | {n}    | {n}      | {n}   | {n}  |

### Mismatches Found
- {description of mismatch}

### Missing Documentation
- {items not documented}

### Verdict: {PASS | FAIL}
```
