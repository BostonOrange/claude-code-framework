---
name: ccf-domain-reference
description: Load this when a session needs the claude-code-framework vocabulary and object model — what a skill/agent/command/rule/hook/team/global-skill IS, current counts of each, the {{PLACEHOLDER}} system, what the CCF_* non-interactive env interface is (full variable table: ccf-release-and-install), the nine project types, the config/*.json catalog, or the internal-app pilot chain. Trigger on questions like "how many agents are there?", "what's the difference between a command and a skill?", "what does {{SOURCE_PATTERNS}} expand to?", or "what is the promote skill for?". Pure reference pack — for procedures, use the sibling ccf-* skills.
last_updated: 2026-07-11
tested_with: claude-fable-5
stability: experimental
scope: preset
---

# CCF Domain Reference — Vocabulary, Object Model, Counts

## Usage

Load this skill when you need to know **what a thing is or how many exist** in this repo: the seven content kinds, the placeholder registry, the CCF_* env interface, project types, or any `config/*.json` file. This is a lookup table, not a runbook.

Do NOT use this skill for:
- **How to change things safely** → `ccf-change-control`
- **Which doc surface owns which count** and fixing count drift → `ccf-doc-sync-campaign`
- **Mirroring setup.sh into setup.ps1** → `ccf-parity-playbook`
- **Running/installing the framework** → `ccf-release-and-install`
- **Why `.claude/` differs from `templates/`** → `ccf-dogfood-and-drift`

## The Seven Content Kinds

The framework ships seven kinds of content. Definitions apply to both the distributable copies (under `skills/` and `templates/`) and the dogfooded subset (under `.claude/`).

| Kind | Location (distributable) | Format | Invoked as |
|------|--------------------------|--------|------------|
| **Skill** | `skills/<name>/SKILL.md` | YAML frontmatter `name` + `description`, then markdown instructions (numbered phases for workflows) | `/name` slash command in a session |
| **Agent** | `templates/agents/<name>.md` | Frontmatter `name`, `description`, `tools`, `model` (opus by default) | Spawned as a subagent, directly or via `/team` |
| **Command** | `templates/commands/<name>.md` | Frontmatter `name`, `description`, `allowed-tools`; single-purpose (one action, one output) | `/name`, but simpler than a skill — no phases |
| **Rule** | `templates/rules/<name>.md` | Frontmatter `id` (kebab-case, stable forever — the citation key reviewer agents use) + `patterns` array of globs | Auto-applied guardrail when edited files match `patterns`; cited by id in review findings |
| **Hook** | `templates/hooks/<name>.sh` | Bash, `#!/bin/bash`; exit 0 = success, 1 = soft block (prompt user), 2 = hard block | Wired in `settings.local.json` lifecycle events (PreToolUse, PostToolUse, SessionStart, SessionEnd) or `.git/hooks/` |
| **Team** | Defined in the `team` skill | Pre-configured agent group (review, architecture, release, quality, documentation, design, full, custom) | `/team <name>` — compositions table lives in CLAUDE.md "Agent Teams" |
| **Global skill** | `global-skills/<name>/` | Same format as a skill | Installed account-wide into `~/.claude/skills/` by `install-global-skill.sh` / `.ps1`; NOT copied into target repos, NOT counted in the "27 workflow skills". Only one exists: `install-framework` |

## Counts (as of 2026-07-11)

**Discipline rule: NEVER hand-edit a count in isolation.** Counts change only together with the files they count; `tests/run-all.sh` is the gate. If a count below disagrees with the filesystem, the filesystem wins — then fix *every* doc surface together (matrix: `ccf-doc-sync-campaign`).

| What | Count | Verify with |
|------|-------|-------------|
| Workflow skills | 27 (+ `_template`) | `ls skills/ \| grep -v '^_template$' \| wc -l` |
| Agents | 39 | `ls templates/agents/*.md \| wc -l` |
| Commands | 11 | `ls templates/commands/*.md \| wc -l` |
| Rules | 23 | `ls templates/rules/*.md \| wc -l` |
| Hook files | 8 `.sh` files | `ls templates/hooks/*.sh \| wc -l` |
| Agent registry entries | 39 (must match agents) | `grep -c '"name"' config/agents.json` |

Hook file roles (docs phrase this as "7 lifecycle scripts + 1 utility"): `guardrails.sh` (PreToolUse), `post-edit-sync.sh` (PostToolUse), `session-start.sh` (SessionStart), `session-stop.sh` + `post-coding-review.sh` (SessionEnd — the schema rejects `SessionStop`, and `Stop` is a different event that fires per response; see ccf-debugging-playbook "Hook wired but never fires"), `pre-commit.sh` (git pre-commit, not a Claude lifecycle event), `codebase-index.sh` (utility), `_lib.sh` (sourced JSON-parsing library — never wire it as a hook).

**Dogfooded subset** — this repo installs a *reduced* roster into its own `.claude/` (mechanics and allowlist: `ccf-dogfood-and-drift`):

| Dogfooded | Count | Contents |
|-----------|-------|----------|
| Agents | 12 | 10 template mirrors + 2 repo-only: `framework-qa`, `framework-improver` |
| Skills | 2 | `improve`, `team` |
| Repo rules | 3 | `setup-scripts.md`, `skills.md`, `templates.md` (repo-authoring rules, not template rules) |
| Hooks | 5 | `_lib.sh`, `guardrails.sh`, `post-coding-review.sh`, `post-edit-sync.sh`, `session-stop.sh` |

## The Placeholder System

Templates carry `{{UPPER_SNAKE_CASE}}` tokens; `setup.sh`/`setup.ps1` substitute real values at install time. **Registry: `config/placeholders.json`** — every entry's `name` becomes `{{NAME}}`, with an optional `env` (shell var to source from) and a `default`. A separate `claude_md_only` section lists placeholders intended for the generated CLAUDE.md (e.g. `PROJECT_DESCRIPTION`, `TECH_STACK_TABLE`) — but as of 2026-07-11 it is dead config: neither installer reads it; both hardcode those replacements inline, and `check-placeholders.sh` still counts it as "defined" (see ccf-architecture-contract weak point 2 / ccf-doc-sync-campaign option D). Parity across both setup scripts is enforced by `tests/check-placeholders.sh`.

Main families:

| Family | Examples | Filled from |
|--------|----------|-------------|
| Branch/identity | `BASE_BRANCH`, `PROJECT_SHORT_NAME`, `DEFAULT_MODEL` | prompts / CCF_* vars |
| Project commands | `TEST_COMMAND`, `FORMAT_COMMAND`, `FORMAT_VERIFY_COMMAND`, `TYPE_CHECK_COMMAND`, `DEPLOY_VALIDATE_COMMAND`, `DEP_CHECK_COMMAND`, `SECURITY_AUDIT_COMMAND` | `config/project-types.json` per type |
| Tracker | `TRACKER_FETCH_TICKET`, `TRACKER_SET_IN_PROGRESS`, `TRACKER_SET_IN_REVIEW`, `TRACKER_TICKET_URL`, `TRACKER_LINK_PR`, `TRACKER_CREATE_TICKET`, `TRACKER_CREATE_BUG`, `TRACKER_UPDATE_FIELDS`, `TRACKER_SET_DEPLOYED` | `config/trackers.json` |
| Notification | `NOTIFY_HALT`, `NOTIFY_HALT_FACTORY`, `NOTIFY_DEPLOY_SUCCESS`, `NOTIFY_MERGE_RESOLVE` | `config/notifications.json` |
| File patterns (rule scoping) | `API_ROUTE_PATTERNS`, `COMPONENT_PATTERNS`, `TEST_PATTERNS`, `DATABASE_PATTERNS`, `SOURCE_PATTERNS` | `config/project-types.json` per type |
| Design system | `DESIGN_COLOR_RULES`, `DESIGN_COMPONENT_IMPORTS`, `DESIGN_ICON_USAGE`, `DESIGN_CARD_PATTERNS`, `DESIGN_DARK_MODE` | `config/design-systems.json` |

Adding a placeholder means touching `config/placeholders.json` + both setup scripts + CLAUDE.md Key Conventions (per `.claude/rules/templates.md`); see `ccf-parity-playbook`.

## CCF_* Non-Interactive Interface

`setup.sh --non-interactive` (and `setup.ps1 -NonInteractive`) read answers from `CCF_*` env vars instead of prompting. `CCF_PROJECT_TYPE` is the only **required** variable — the installer hard-errors if it is unset — and invalid values for any variable also hard-error. Non-interactive mode never renames git branches. Enumerate the variable names any time with `grep -o 'CCF_[A-Z_]*' setup.sh | sort -u` (see Provenance).

**The full variable table (valid values, defaults, per-project-type conditionals) has one home: `ccf-release-and-install`** — do not restate it here. That skill also covers full installer anatomy and `--dry-run`/`--reset` semantics.

## The Nine Project Types

Keys of `config/project-types.json`: **salesforce, nodejs, react, internal-nextjs-app, python, go, java, rails, generic**. Each carries the seven command placeholders plus `error_tracking` and the five pattern families — the *entire* per-type variation surface, apart from setup-script conditionals (backend types skip `components.md`/`design-system.md` rules; `generic` uses "Configure your X command" comment stubs).

Note: `.claude/rules/setup-scripts.md` lists 8 types (predates internal-nextjs-app); the JSON file is ground truth.

## config/*.json Catalog

| File | Role | Gated by |
|------|------|----------|
| `config/agents.json` | Canonical agent registry: `blurb` (README/CLAUDE.md tables) + `description` (mirrors frontmatter) per agent, 4 categories (analysis, planning, implementation, meta) | `tests/check-agent-registry.sh` |
| `config/placeholders.json` | Placeholder → env-var/default registry (see above) | `tests/check-placeholders.sh` |
| `config/project-types.json` | Per-type commands + glob patterns | setup smoke tests |
| `config/trackers.json` | Per-tracker API snippets, env var names, wizard prompts | — |
| `config/notifications.json` | Per-system webhook curl snippets (env var name, message field) | — |
| `config/design-systems.json` | Per-design-system conventions: untitled-ui, shadcn, custom, none, `_backend` | — |
| `config/precommit.json` | Per-type pre-commit tooling guidance printed after install | — |
| `config/dogfood-drift-allowlist.txt` | Exact expected `.claude/` vs `templates/` diff lines | `tests/check-dogfood-drift.sh` |

## Internal-App Pilot Chain

Three skills + one vendored template form a pipeline for internal Next.js business apps (project type `internal-nextjs-app`):

1. `/app-blueprint` — converts business intent into `docs/app-blueprint.json`.
2. `/generate-internal-app` — consumes the blueprint and adapts the vendored template into a working app; orchestration lives in the skill, core architecture stays in the template.
3. `/promote` — builds a Layer 1 → Layer 2 promotion *evidence package*; it must NOT set `LAYER.md` to 2 (IT does that after sign-off).

The vendored template is `templates/internal-nextjs-business-app/` (Next.js + Prisma + Docker + infra scripts, with `LAYER.md.template` and `RUN_ME_FIRST` bootstrappers). Thin command counterparts (`app-blueprint.md`, `generate-internal-app.md`, `promote.md`) exist in `templates/commands/` and count toward the 11 commands.

## Trackers and Notifications (one line each)

- **ado** — Azure DevOps REST API via `AZURE_DEVOPS_EXT_PAT`; needs org + project.
- **jira** — Jira REST API v3 via `JIRA_EMAIL` + `JIRA_API_TOKEN`; needs domain + project key.
- **linear** — Linear GraphQL API via `LINEAR_API_KEY`; needs team ID.
- **github** — GitHub Issues via `gh` CLI; no env vars.
- **none** — tickets managed manually; skills ask the user for details.
- **Notifications**: slack / teams / discord are webhook-curl variants (`SLACK_WEBHOOK_URL` / `TEAMS_WEBHOOK_URL` / `DISCORD_WEBHOOK_URL`; discord's message field is `content`, not `text`); **none** logs instead.

## Edge Cases

| Situation | What to do |
|-----------|------------|
| A count here disagrees with `ls \| wc -l` | Filesystem wins. Re-run the provenance commands, then update ALL doc surfaces together (`ccf-doc-sync-campaign`) — never patch one file |
| Need to know which doc file owns a count/table | `ccf-doc-sync-campaign` owns the surface matrix |
| Skill exists in `skills/` but not `.claude/skills/` | Expected — the repo dogfoods only `improve` and `team` (`ccf-dogfood-and-drift`) |
| `.claude/agents/framework-qa.md` has no template counterpart | Expected repo-only agent (also `framework-improver.md`); both are allowlisted |
| `config/agents.json` count ≠ `templates/agents/*.md` count | Real drift — run `bash tests/check-agent-registry.sh`, fix registry and files together |
| Adding a new placeholder | Register in `config/placeholders.json` AND both setup scripts AND CLAUDE.md (`ccf-parity-playbook`) |
| `CCF_DESIGN_SYSTEM` set for a python/go/java install | Silently ignored — only react/nodejs consult it; all types other than react/nodejs are forced `_backend` (internal-nextjs-app forced `none`). Full table: `ccf-release-and-install` |
| `setup-scripts.md` rule lists 8 project types, JSON has 9 | Known stale surface (as of 2026-07-11); trust `config/project-types.json` |

## Related Skills

- `ccf-architecture-contract` — why the repo is shaped this way; invariants and dependency direction.
- `ccf-change-control` — gates, review, session-end `/improve` + `framework-qa` workflow.
- `ccf-doc-sync-campaign` — the doc-surface matrix and the drift-fix campaign.
- `ccf-parity-playbook` — bash↔PowerShell mirroring when touching setup scripts.
- `ccf-testing-and-qa` — what each `tests/*.sh` gates.
- `ccf-release-and-install` — installer anatomy, CCF_* end-to-end, rollback.
- `ccf-dogfood-and-drift` — `.claude/` vs `templates/` model and the allowlist.
- `ccf-onboarding-tour` — guided reading order if you're brand new.

## Provenance and maintenance

Every fact above was verified against the repo on 2026-07-11. Re-verify with:

```bash
ls skills/ | grep -v '^_template$' | wc -l          # 27 workflow skills
ls templates/agents/*.md | wc -l                    # 39 agents
ls templates/commands/*.md | wc -l                  # 11 commands
ls templates/rules/*.md | wc -l                     # 23 rules
ls templates/hooks/*.sh | wc -l                     # 8 hook files
grep -c '"name"' config/agents.json                 # 39 registry entries
ls .claude/agents/*.md | wc -l                      # 12 dogfooded agents
ls .claude/skills/ | grep -cv '^ccf-'               # 2 dogfooded workflow skills (improve, team)
ls .claude/hooks/*.sh | wc -l                       # 5 dogfooded hook files
grep -o 'CCF_[A-Z_]*' setup.sh | sort -u            # CCF_* variable list
python3 -c "import json; print(list(json.load(open('config/project-types.json')).keys()))"  # 9 types
ls config/                                          # config catalog
```

**Re-verify this skill whenever** a PR touches `skills/`, `templates/agents|commands|rules|hooks/`, `config/*.json`, or the setup scripts — i.e., whenever `tests/run-all.sh` or the session-end `/improve` pass reports count or registry changes.
