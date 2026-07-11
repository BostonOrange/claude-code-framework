---
name: ccf-architecture-contract
description: Load when you need to know WHY claude-code-framework is shaped the way it is before changing its structure — questions like "where does this new file belong (templates/ vs .claude/ vs global-skills/)?", "can I hand-edit this count / rename this rule id / add logic to setup.sh directly?", "what invariants will my change break?", or "what are the repo's known-weak points?". Also load when a test in tests/ fails and you need the design intent behind the invariant it enforces. NOT a vocabulary reference (see ccf-domain-reference) and NOT the doc-count fix campaign (see ccf-doc-sync-campaign).
last_updated: 2026-07-11
tested_with: claude-fable-5
stability: experimental
scope: preset
---

# CCF Architecture Contract

The load-bearing design decisions of claude-code-framework, the invariants every change must preserve, and the currently open weak points. This is the "why" layer; sibling playbooks own the "how".

## Usage

**Load this skill when:**
- Deciding where a new file belongs (distributable payload vs dogfooded config vs account-level skill).
- About to change setup.sh/setup.ps1 structure, config/*.json shape, or any documented count.
- A `tests/check-*.sh` failure makes no sense until you know what invariant it protects.
- Asked "is this a known issue?" — check the weak-points list below first.

**Do NOT use this skill for:** term definitions or the config/*.json field catalog (→ **ccf-domain-reference**); which count lives in which doc, or fixing drift (→ **ccf-doc-sync-campaign**); bash↔PowerShell mirroring mechanics (→ **ccf-parity-playbook**); drift-allowlist editing procedure (→ **ccf-dogfood-and-drift**).

## The three-tier content model

This repo is the framework, **not** a target project — never run setup.sh here (see CLAUDE.md). Every file lives in exactly one tier:

| Tier | Paths | Installed by | Reaches target repos? |
|------|-------|--------------|----------------------|
| Distributable payload | `templates/`, `skills/`, `workflows/`, `memory/` | `setup.sh` / `setup.ps1` copy into the target's `.claude/` etc. | Yes |
| Dogfood config | `.claude/` | Hand-curated; lives only here | No |
| Account-level skills | `global-skills/` | `install-global-skill.sh` / `.ps1` → `~/.claude/skills/` | No (installed per user account, not per repo) |

**Why three tiers:** the repo needs Claude Code tooling to work *on itself*, but running the installer here would overwrite the curated `.claude/` with generic rendered output. So `.claude/` is a deliberately reduced, hand-maintained subset, and every difference between it and `templates/`+`skills/` must be listed in `config/dogfood-drift-allowlist.txt` or `tests/check-dogfood-drift.sh` fails (mechanics → ccf-dogfood-and-drift). `global-skills/` exists because `/install-framework` must be available *before* any repo has the framework — it bootstraps installation, so it cannot itself be a per-repo template (see CLAUDE.md "Global Skills").

## Dependency direction

```
config/*.json  ──consumed by──▶  setup.sh / setup.ps1  ──render──▶  installed files in target repo
     ▲                                                                  
     └── docs/README/CLAUDE.md mirror config; tests/ reconcile all three
```

`config/` (as of 2026-07-11): `agents.json`, `placeholders.json`, `project-types.json`, `trackers.json`, `notifications.json`, `design-systems.json`, `precommit.json`, `dogfood-drift-allowlist.txt`. Field catalog → ccf-domain-reference.

The direction is one-way and load-bearing:
- **Templates never read config.** They contain only `{{PLACEHOLDER}}` slots.
- **Setup scripts hold no mapping data** (project-type commands, tracker calls, design rules live in JSON; commit `7afba13`, 2026-04-09, extracted them). Exceptions that survive are listed under weak points.
- **Docs are downstream mirrors** of config and disk. The maintainer's hardest live problem is drift among README.md, CLAUDE.md, AGENTS.md, docs/, `config/agents.json`, and both setup-script summaries — which is why the discipline rule exists: **never hand-edit a count in isolation; counts change only together with the files they count, verified by tests.** A change is not done until every doc surface reflects it (campaign → ccf-doc-sync-campaign).

## The invariants

| # | Invariant | Enforced by | Rationale |
|---|-----------|-------------|-----------|
| 1 | setup.sh and setup.ps1 have feature parity | `tests/check-placeholders.sh`, `tests/check-setup-smoke.sh` + `.ps1`; `.claude/rules/setup-scripts.md` | Windows and macOS/Linux users must get identical installs |
| 2 | Every `{{PLACEHOLDER}}` in `templates/` and `skills/` has a replacement in BOTH scripts (or is defined in `config/placeholders.json`, which both consume) | `tests/check-placeholders.sh` | An orphaned placeholder ships literal `{{X}}` into a target repo |
| 3 | Documented counts == disk counts | `tests/check-consistency.sh`, `tests/check-agent-registry.sh` | Wrong counts poison every future AI session that trusts the docs |
| 4 | Rule `id` frontmatter is stable forever — never rename, never reuse | `.claude/rules/templates.md` (convention; no automated check found) | Reviewer agents cite rule ids in findings; renaming breaks the citation contract retroactively |
| 5 | `.claude/` ↔ `templates/`+`skills/` drift is explicitly allowlisted | `tests/check-dogfood-drift.sh` vs `config/dogfood-drift-allowlist.txt` | Silent divergence turns dogfooding into a lie |
| 6 | Tests green before merge | `.github/workflows/framework-tests.yml` runs `bash -n` on all scripts, `tests/run-all.sh`, and the PowerShell smoke test | Deterministic hard gate; agents (`/improve`, `framework-qa`) are advisory, tests are not |

`tests/run-all.sh` auto-discovers every `tests/check-*.sh`, so a new invariant becomes CI-enforced just by adding a script there (anatomy → ccf-testing-and-qa).

## Key decisions and why (mined from git)

**Self-improvement is an explicit contributor workflow, not a hidden hook.** The initial commit `7e5a192` (2026-03-15 14:38) shipped husky/lint-staged pre-commit setup; it was removed the *same day* by `0ee06f5` (17:02) — rationale in the commit message: "pre-commit hooks add friction without additional value in this workflow." Today's `config/precommit.json` layer is a later, opt-in feature for *target* projects that explicitly coexists with husky (comment in setup.sh near the pre-commit section). CLAUDE.md codifies the result: `/improve` and `framework-qa` run at session end by instruction, "not launched by a hidden mutating hook," with deterministic tests as the hard gate. Do not reintroduce mutating hooks.

**Detector/applier split — read scans never mutate.** `e002a1b` (2026-04-26) split `project-setup` into `project-setup-detector` + `project-setup-applier`; `d95c784` (same day) did the same for `framework-improver`. The detector is read-only *by tool removal* (no Edit/Write in its tools list), not by prose instruction — codified in `.claude/rules/templates.md`: "Read-only agents must NOT have Edit or Write in their tools list." When adding any scan-then-change agent, keep this split.

**Mappings live in JSON, not scripts.** `7afba13` (2026-04-09, part of the same-day hardening wave as `4c688cf`) extracted hardcoded project-type/tracker/notification/design mappings into `config/*.json` so both setup scripts consume one source of truth and parity stops depending on humans mirroring data twice.

## Open known-weak points (as of 2026-07-11)

All verified against the working tree on 2026-07-11. Status **open** = real, unfixed; **latent** = wrong but not yet biting.

1. **[latent] Rendered rule `patterns` frontmatter is invalid YAML for multi-pattern project types.** Rule templates use a single list item (`- {{API_ROUTE_PATTERNS}}`), but setup.sh joins pattern arrays as `", "`-separated quoted strings (`joined = ', '.join(f'"{p}"' ...)` in the PROJTYPE eval block), so react/nodejs installs render `- "app/api/**/*.ts", "**/routes/**/*.ts", ...` — a quoted scalar with trailing garbage. 20 of the 23 rule templates use these pattern placeholders. Nothing currently parses the rendered frontmatter as YAML, which is why it hasn't bitten; it will the day anything does.
2. **[open] `config/placeholders.json` `claude_md_only` group is dead config.** Neither setup script reads that group — both hardcode those replacements inline (e.g. `{{TECH_STACK_TABLE}}` in setup.sh's CLAUDE_MD block and setup.ps1's `.Replace` call). Worse, `tests/check-placeholders.sh` treats any JSON-listed name as "present in both scripts," so for this group the parity check is vacuous: you could delete the inline replacement from one script and the test would still pass.
3. **[open] `VERSION` file (contains `1.0.0`) is referenced by nothing** — no script, doc, or test reads it. Either wire it into release output or delete it.
4. **[open] `eval "$(python3 << EOF ... )"` sites in setup.sh are not protected by `set -e`.** The four config-loader sites (design-systems, trackers, project-types, notifications) escape `set -e`: a python3 failure yields an empty substitution, `eval ""` returns 0, and setup continues half-configured. Mechanics, affected line numbers, and the doctor command: ccf-debugging-playbook "Silent half-configuration".
5. **[open] Unmerged branch `origin/claude/codebase-assessment-7p9rq7` holds 4 real fix commits** (`199417f`, `7f82b84`, `e052200`, `0fe93ea`) that fix things `main` still has wrong (as of 2026-07-11); merge or cherry-pick deliberately. Inventory, status, and full story: ccf-failure-archaeology Entries 1 and 8.

Candidate fixes for 1–4 are open work items, not done — do not describe them as fixed until tests prove otherwise.

## Edge Cases

| Situation | What to do |
|-----------|-----------|
| A file seems needed in both `templates/` and `.claude/` | Put the canonical copy in `templates/`; if the in-repo copy must differ, add the exact drift line to `config/dogfood-drift-allowlist.txt` (procedure → ccf-dogfood-and-drift) |
| You want to rename a rule file / its `id` | Don't. Ids are permanent citation keys (invariant 4). Add a new rule and deprecate the old one in prose instead |
| A count in a doc looks wrong | Do not hand-fix the number alone — run `bash tests/run-all.sh`, find which surface disagrees with disk, fix files+docs together (→ ccf-doc-sync-campaign) |
| New prompt/placeholder needed in the installer | Add to `config/placeholders.json` (or the relevant config JSON), both scripts, both resolvers (`CCF_*`), then `bash tests/check-placeholders.sh` (→ ccf-parity-playbook) |
| Tempted to add a hook that edits files automatically | Prohibited by design history (`0ee06f5`, CLAUDE.md Self-Improvement section). Make it an explicit skill/agent workflow gated by tests |
| Weak point above appears fixed | Re-run its provenance command below; if fixed, update this skill's list and date stamp |

## Related Skills

- **ccf-domain-reference** — switch when you need vocabulary or the config/*.json object model, not rationale.
- **ccf-doc-sync-campaign** — switch when actually reconciling counts/tables across doc surfaces.
- **ccf-parity-playbook** — switch when editing setup.sh/setup.ps1 and mirroring changes.
- **ccf-testing-and-qa** — switch when extending or debugging `tests/check-*.sh`.
- **ccf-dogfood-and-drift** — switch when touching `.claude/` or the drift allowlist.
- **ccf-change-control** — switch for gating, commit conventions, and the session-end `/improve` + `framework-qa` workflow.
- **ccf-failure-archaeology** — switch for the full history of past investigations behind these decisions.

## Provenance and maintenance

Re-verify each fact before relying on it:

- Tier counts: `ls templates/agents/*.md | wc -l` (39), `ls templates/commands/*.md | wc -l` (11), `ls templates/rules/*.md | wc -l` (23), `ls -d skills/*/ | wc -l` (28 = 27 + `_template`) — all as of 2026-07-11.
- Config inventory: `ls config/`
- Placeholder invariant mechanics: `cat tests/check-placeholders.sh`
- CI gate: `cat .github/workflows/framework-tests.yml`
- Husky add/remove same day: `git show --no-patch --format='%h %ad %s' --date=format:'%Y-%m-%d %H:%M' 7e5a192 0ee06f5` and `git show --stat 0ee06f5`
- Detector/applier splits: `git show --no-patch --format='%h %ad %s' e002a1b d95c784`
- Config extraction: `git show --no-patch --format='%h %ad %s' 7afba13`
- Weak point 1 (YAML join): `grep -n "', '" setup.sh | grep -i join` and `head -5 templates/rules/api-routes.md`; affected files: `grep -rln '{{API_ROUTE_PATTERNS}}\|{{SOURCE_PATTERNS}}\|{{COMPONENT_PATTERNS}}\|{{DATABASE_PATTERNS}}\|{{TEST_PATTERNS}}' templates/rules/ | wc -l` (20)
- Weak point 2 (dead config): `grep -rn claude_md_only setup.sh setup.ps1 tests/ config/` (hits only in tests + config)
- Weak point 3 (VERSION): `grep -rnw --exclude-dir=.git VERSION .` (no consumers)
- Weak point 4 (eval sites): `grep -n 'eval "\$(python3' setup.sh` (the `$` must be escaped — the unescaped form silently matches nothing under macOS BSD grep)
- Weak point 5 (branch): `git log --oneline main..origin/claude/codebase-assessment-7p9rq7`

**Re-verify this skill whenever:** any weak point is fixed or the branch above is merged; a new tier, config file, or `tests/check-*.sh` is added; setup.sh's placeholder-loading blocks are restructured; or any documented count changes.
