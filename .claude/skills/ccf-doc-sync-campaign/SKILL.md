---
name: ccf-doc-sync-campaign
description: Load when a count or table in claude-code-framework docs looks stale, when adding/removing a skill/agent/command/rule/hook (which changes counts everywhere), when tests/check-consistency.sh or tests/check-agent-registry.sh fails, or when asked "which files state the agent count?" / "sync the docs" / "fix doc drift". Owns the doc-surface matrix (which count lives in which file, and which are test-guarded) and the executable campaign to fix the currently-known drift in AGENTS.md, docs/teams.md, docs/agent-patterns.md, and refactor-pass-implementer. Not for vocabulary (ccf-domain-reference) or general merge gating (ccf-change-control).
last_updated: 2026-07-11
tested_with: claude-fable-5
stability: experimental
scope: preset
---

# Doc-Sync Campaign — Kill Count/Table Drift

Doc/count drift is this repo's hardest live problem: the same counts (27 skills, 39 agents, 11 commands, 23 rules, 7 hooks) are stated in ~10 files, and only some are test-guarded. The iron rule: **NEVER hand-edit a count in isolation — counts change only together with the files they count, verified by tests.** A change is not done until EVERY doc surface reflects it.

## Usage

Load this skill when: you added/removed/renamed anything under `skills/` or `templates/agents|commands|rules|hooks/` (every such change moves a count on multiple surfaces); `tests/check-consistency.sh` or `tests/check-agent-registry.sh` fails; you spotted a stale number or table row in README.md, CLAUDE.md, AGENTS.md, or docs/; or you were asked to run the drift-fix campaign below.

Do NOT use it for: what the counted objects *are* (ccf-domain-reference); why the invariants exist (ccf-architecture-contract); commit/session-end gating (ccf-change-control); `.claude/` vs `templates/` intentional-difference mechanics (ccf-dogfood-and-drift); test internals (ccf-testing-and-qa).

## The Doc-Surface Matrix

One row per surface. "Guarded" = a deterministic test fails if it drifts. Verified 2026-07-11.

| Surface | What it states | Guarded by |
|---|---|---|
| README.md counts | 27 workflow skills, 39 AI agents, 11 quick commands, 23 file-pattern rules, 7 lifecycle hooks | `tests/check-consistency.sh` (regex on phrases like "N workflow skills") |
| README.md agent table | one row per agent | `check-consistency.sh` (row count) + `check-agent-registry.sh` (name presence) |
| setup.sh summary block (lines ~1300–1304) | all five counts | `check-consistency.sh` |
| setup.ps1 summary block (lines ~1124–1128) | all five counts | **UNGUARDED for counts** — `check-placeholders.sh` enforces only placeholder parity, not summary numbers |
| config/agents.json | canonical agent registry: name, category, model, blurb, description | `check-agent-registry.sh` — `description` must be **byte-identical** to the agent file's frontmatter description |
| templates/CLAUDE.md.template | agent names, team table | names guarded (`check-agent-registry.sh`); team-size numbers (e.g. "All 16") UNGUARDED |
| docs/teams.md | roster table + prose counts | names guarded; **prose counts UNGUARDED** |
| docs/agents-commands-rules.md | agent/command/rule tables + prose | names guarded; **prose counts UNGUARDED** |
| docs/agent-patterns.md | prose agent count | **UNGUARDED** |
| AGENTS.md (Codex mirror of CLAUDE.md) | full file-tree counts + tables | **UNGUARDED** — no test references AGENTS.md at all |
| CLAUDE.md (top-level, dogfood) | counts + agent/team tables | **UNGUARDED** |

Mechanical count definitions used by `check-consistency.sh`: skills = dirs in `skills/` minus `_template`; agents/commands/rules = `.md` files in the respective `templates/` dir; hooks = `.sh` files in `templates/hooks/` excluding `_`-prefixed libraries (`_lib.sh`), so 8 files count as 7.

## Known Drift Register (as of 2026-07-11 — re-verify before fixing)

| # | Location | Says | Should say | Note |
|---|---|---|---|---|
| 1 | AGENTS.md:45 | 10 quick command definitions | 11 | Commit 1a57034 reconciled counts to 27/11 everywhere but never touched AGENTS.md (see ccf-failure-archaeology) |
| 2 | AGENTS.md:50, :91 | 26 workflow skills | 27 | Same root cause |
| 3 | docs/teams.md:7, :9 | "12 pre-configured agents" / "Agent Roster (12 agents)" | 39 | The roster table below the heading already has 39 rows |
| 4 | docs/agent-patterns.md:3 | 38 agents | 39 | A fix already exists on unmerged branch `origin/claude/codebase-assessment-7p9rq7` (commit 7f82b84) |
| 5 | templates/agents/refactor-pass-implementer.md:3 AND config/agents.json:218 | "Build phase 5 specialist" | phase 6 | `skills/build/SKILL.md:59` is canonical: phase 6 = refactor. Every other surface (CLAUDE.md:169, AGENTS.md:174, README.md:232, docs/teams.md:52, docs/agents-commands-rules.md:187, agents.json:217 blurb) says "phase 6 (final)". **Fix frontmatter and agents.json description together** — they must stay byte-identical or `check-agent-registry.sh` fails |
| 6 | skills/team/SKILL.md:21,:63 + templates/CLAUDE.md.template:94 say "/team full = 16"; .claude/skills/team/SKILL.md:51 + CLAUDE.md:133 + AGENTS.md:138 say "12" | mixed | see note | **Partly intentional**: the repo dogfoods a reduced 12-agent roster (`.claude/agents/` has exactly 12 files; drift allowlisted at config/dogfood-drift-allowlist.txt:27) — do NOT blind-sync 12→16. And "16" itself is unverified: the template team skill's own roster table lists 14 non-meta agents plus `frontend-architecture-reviewer` referenced only by the `design` team. Count the roster first, then fix template-side surfaces to that number |

## Process

### Phase 0 — Baseline

```bash
bash tests/run-all.sh
```

Expected (as of 2026-07-11): 8/8 pass — the ccf-* knowledge-skill library (including this file) is allowlisted in config/dogfood-drift-allowlist.txt.
- `check-consistency` or `check-agent-registry` failing instead → a **guarded** surface drifted; fix that first (the failure message names the file), then restart Phase 0.
- `check-dogfood-drift` reporting non-`ccf-*` entries → real dogfood drift; switch to ccf-dogfood-and-drift.

### Phase 1 — Enumerate current drift (never trust this register blindly)

```bash
grep -n "26 workflow\|10 quick command" AGENTS.md
grep -n "12 agents\|12 pre-configured\|38 agents" docs/teams.md docs/agent-patterns.md
grep -n "phase 5\|Phase 5" config/agents.json templates/agents/refactor-pass-implementer.md
grep -rn "All 16\|all 16\|All 12\|all 12" CLAUDE.md AGENTS.md templates/CLAUDE.md.template skills/team/SKILL.md .claude/skills/team/SKILL.md
bash tests/check-consistency.sh | sed -n '5,12p'   # prints actual on-disk counts
```

Each hit is a campaign target. Zero hits on the first three greps → drift items 1–5 are already fixed; skip to Phase 4.

### Phase 2 — Pick a strategy (ranked)

| Rank | Option | Obligation |
|---|---|---|
| A | Merge/cherry-pick `origin/claude/codebase-assessment-7p9rq7` first — it fixes drift #4 AND repairs the test harness (`tests/check-setup-smoke.*`, `tests/run-all.sh`, hooks); branch status and inventory: ccf-failure-archaeology Entry 8 | Re-run the FULL suite after merge; it touches the harness itself, so a green run pre-merge proves nothing |
| B | Hand-fix each drift instance TOGETHER with extending a guard | Every hand-fixed surface must gain a deterministic check in the same change — a bare hand-fix violates the iron rule |
| C | Extend `tests/check-consistency.sh` to also scan AGENTS.md and docs/*.md prose counts | Mirror the scanned-file list in the test's header comment; keep the existing `grep -o … head -1` extraction pattern |
| D | Make setup scripts read the `claude_md_only` group from config/placeholders.json instead of hardcoding — kills the dead-config trap (see below) | Change setup.sh AND setup.ps1 (parity — see ccf-parity-playbook) and confirm `check-placeholders.sh` still passes |

A + C together is the strongest play. B is acceptable for one-off fixes. D is independent hygiene, candidate/open — not required for the count campaign.

### Phase 3 — Execute

Per-target rules:
1. AGENTS.md counts (drift 1–2): edit lines 45/50/91 to the numbers printed by `check-consistency.sh` in Phase 1 — never to numbers from memory.
2. docs/teams.md (drift 3): update both the prose at line 7 and the heading at line 9; sanity-check with `grep -cE '^\| \x60[a-z-]+\x60 \|' docs/teams.md` (expect 39).
3. refactor-pass phase (drift 5): edit `templates/agents/refactor-pass-implementer.md` frontmatter `description:` and `config/agents.json` `description` to identical bytes, then immediately `bash tests/check-agent-registry.sh`.
4. /team full (drift 6): fix only template-side surfaces (`skills/team/SKILL.md`, `templates/CLAUDE.md.template`); leave dogfood "12" alone but add a one-line caveat near it noting the reduced roster is intentional.

### Phase 4 — Validate (measured, never eyeballed)

```bash
bash tests/run-all.sh
grep -rn "26 workflow\|10 quick command\|38 agents\|12 agents\|phase 5" \
  AGENTS.md docs/teams.md docs/agent-patterns.md config/agents.json \
  templates/agents/refactor-pass-implementer.md
```

Success = suite green AND the grep returns zero drift hits. If the grep is clean but the suite is red, you broke a guarded surface while fixing an unguarded one — read the failing test's output; do not revert blindly.

### Phase 5 — Prevent recurrence

If you chose B in Phase 2, option C's test extension is now due — the campaign is not complete until the surfaces you touched are guarded. Then follow the session-end workflow (`/improve` + framework-qa) per ccf-change-control.

## Traps and Fenced Wrong Paths

- **Hand-editing a count without extending a guard** — violates the iron rule; the drift returns.
- **"Fixing" dogfood /team full 12→16** — 12 is the intentional reduced roster; blind sync creates NEW drift and may trip `check-dogfood-drift.sh`.
- **Editing config/agents.json descriptions alone** — `check-agent-registry.sh` requires byte-identity with agent frontmatter; change both, re-run that test.
- **Dead-config trap**: config/placeholders.json's `claude_md_only` group (TRACKER_CONFIG, PROJECT_DESCRIPTION, TECH_STACK_TABLE) is NOT consumed by either setup script — setup.sh hardcodes the same values inline (~lines 1050–1051), setup.ps1 at ~line 899. Editing the JSON changes nothing at install time, and `check-placeholders.sh` still counts the group as "defined", so no test catches it. That is option D's target.
- **Regex shadowing in check-consistency.sh**: extraction is `grep -o '<pattern>' | head -1` — the FIRST matching phrase wins, so a new sentence like "5 workflow skills for X" above the real count silently changes what the test compares.
- **Trusting a green suite as "docs in sync"**: on 2026-07-11 the suite passed `check-consistency` and `check-agent-registry` while drift items 1–6 all existed. Green means guarded surfaces match — nothing more.

## Edge Cases

| Situation | What to do |
|---|---|
| `check-dogfood-drift` fails on `Only in .claude/skills: ccf-…` | Expected until the knowledge-skill library is allowlisted in config/dogfood-drift-allowlist.txt (see ccf-dogfood-and-drift); not a doc-count problem |
| Branch `origin/claude/codebase-assessment-7p9rq7` gone | Merged or deleted; check `git log --oneline -5 -- docs/agent-patterns.md` and re-grep drift #4 before acting |
| Counts changed since 2026-07-11 (e.g. a 28th skill) | Matrix rows still hold; register values don't — Phase 1 output is the only truth |
| A count phrase appears in docs/architecture.md | None found on 2026-07-11; re-grep: `grep -n "[0-9]\+ \(workflow skills\|AI agent\|quick command\)" docs/architecture.md` |
| Changing setup.sh's summary numbers | Mirror in setup.ps1 in the same edit — setup.ps1's numbers are unguarded; only discipline keeps them honest |
| AGENTS.md and CLAUDE.md disagree on something not listed here | AGENTS.md is a Codex-format mirror of CLAUDE.md; CLAUDE.md wins — sync AGENTS.md to it |

## Related Skills

- **ccf-domain-reference** — what the counted objects are; vocabulary, not procedure.
- **ccf-change-control** — the tests-must-pass gate, session-end `/improve` + framework-qa; this campaign ends by handing off to it.
- **ccf-dogfood-and-drift** — allowlist mechanics behind the intentional 12-agent dogfood roster (drift #6's caveat).
- **ccf-parity-playbook** — bash↔PowerShell mirroring required by options C/D and any setup summary edit.
- **ccf-testing-and-qa** — anatomy of the check scripts you'll extend in Phase 5.
- **ccf-failure-archaeology** — commit history behind each drift item (e.g. 1a57034, 77fb946).

## Provenance and maintenance

Re-verification one-liners for every fact that can drift:

- Counts 27/39/11/23/7: `find skills -mindepth 1 -maxdepth 1 -type d ! -name _template | wc -l`; `ls templates/agents/*.md | wc -l`; `ls templates/commands/*.md | wc -l`; `ls templates/rules/*.md | wc -l`; `find templates/hooks -maxdepth 1 -name "*.sh" ! -name "_*" | wc -l`
- Drift items 1–5: the Phase 1 grep block
- Drift item 6: `grep -rn "ll 16\|ll 12" CLAUDE.md templates/CLAUDE.md.template skills/team/SKILL.md .claude/skills/team/SKILL.md`
- Guard scope of check-consistency.sh: `grep -n 'SETUP_SH\|README=' tests/check-consistency.sh` (only setup.sh + README.md)
- Guard scope of check-agent-registry.sh: `sed -n '86,95p' tests/check-agent-registry.sh` (the four downstream docs)
- AGENTS.md unguarded: `grep -rln AGENTS.md tests/` (expect no output)
- Dead-config trap: `grep -n claude_md_only setup.sh setup.ps1` (expect no output) vs `grep -n claude_md_only tests/check-placeholders.sh`
- Dogfood roster of 12: `ls .claude/agents/*.md | wc -l`; team-skill drift allowlisted: `grep -n team config/dogfood-drift-allowlist.txt`
- Stranded fix branch: `git log --oneline main..origin/claude/codebase-assessment-7p9rq7`
- Suite baseline: `bash tests/run-all.sh` (2026-07-11: 8/8 passing)

**Re-verify this skill whenever**: any commit touches `skills/`, `templates/agents|commands|rules|hooks/`, `tests/check-consistency.sh`, `tests/check-agent-registry.sh`, or AGENTS.md — and immediately after the drift register above is fixed (then rewrite the register to "no known drift as of <date>" rather than deleting the matrix).
