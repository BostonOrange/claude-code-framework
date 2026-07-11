---
name: ccf-change-control
description: Load before committing, merging, or ending any session that modified framework files in claude-code-framework. Answers "what must I run before this merges?", "which checks gate this kind of change?", "can I rename a rule id / placeholder / CCF_* var?", "when do I run /improve and framework-qa?", and "is editing the dogfood drift allowlist legitimate here?". Covers the tests/run-all.sh hard gate, change classification, the non-negotiable rules with their incident history, and commit/PR conventions.
last_updated: 2026-07-11
tested_with: claude-fable-5
stability: experimental
scope: preset
---

# CCF Change Control

How a change to this framework is classified, gated, reviewed, and landed. The core model: **deterministic tests are the hard gate; agents are advisory layers on top of it.** No agent opinion, review, or skill instruction may route around a failing `tests/run-all.sh`.

## Usage

Load this skill when you are about to change framework files and need to know what must happen before the change counts as done — or when you see a failing check and need to know whether to fix the change or the check.

Do NOT use this skill for:
- WHICH count/table lives in WHICH file — that matrix is owned by **ccf-doc-sync-campaign**
- HOW to mirror setup.sh into setup.ps1 — **ccf-parity-playbook**
- Internals of each `tests/check-*.sh` script — **ccf-testing-and-qa**
- Mechanics of `.claude/` vs `templates/` and the drift allowlist format — **ccf-dogfood-and-drift**

## Process

### 1. Classify the change

| Class | Examples | Minimum gate | Extra obligations |
|---|---|---|---|
| doc-only | README wording, docs/ guides | `bash tests/run-all.sh` (counts/tables are still parsed) | None if no counts touched |
| template-content | new/edited file in `templates/agents\|commands\|rules\|hooks/`, `skills/` | full suite; `check-templates.sh`, `check-placeholders.sh`, `check-consistency.sh`, `check-agent-registry.sh`, `check-dogfood-drift.sh` all bite | Update every doc surface + `config/agents.json` for agents (see ccf-doc-sync-campaign); sync or allowlist the `.claude/` twin |
| setup-script | `setup.sh` / `setup.ps1` | full suite incl. `check-setup-smoke.sh`; PowerShell smoke (see phase 3 warning) | Mirror in the other script in the SAME change (`.claude/rules/setup-scripts.md`) |
| test | `tests/check-*.sh`, `tests/check-setup-smoke.ps1` | full suite; new `check-*.sh` files are auto-discovered by `run-all.sh` (find pattern) | State what the test newly gates in the commit message |
| config-schema | `config/*.json` | full suite; `check-agent-registry.sh` locksteps `config/agents.json` with `templates/agents/*.md`, README.md, `templates/CLAUDE.md.template`, docs/teams.md, docs/agents-commands-rules.md | Treat keys as an interface consumed by setup scripts |

### 2. Make the change WITH everything it invalidates

A change is not done until every doc surface reflects it (maintainer's explicit definition of done). Edit the files and their counts/tables in the same commit — see the non-negotiables below.

### 3. Run the hard gate

```bash
bash tests/run-all.sh   # must exit 0; prints a PASS/FAIL table per check
```

CI (`.github/workflows/framework-tests.yml`) runs two jobs on every push and PR: `bash -n` syntax checks + `run-all.sh` on ubuntu, and `tests/check-setup-smoke.ps1` on windows. **`run-all.sh` only discovers `check-*.sh` — a local green run does NOT exercise the PowerShell smoke test.** For setup.ps1 changes, run it yourself if `pwsh` is installed:

```bash
pwsh ./tests/check-setup-smoke.ps1
```

(The harness's own startup crash — read-only `$Home`/`$args` automatic variables — was fixed by `e052200`, merged 2026-07-11, so this command and the windows CI job gate for real; history: ccf-failure-archaeology Entry 1.)

### 4. Advisory layer (session end)

Per CLAUDE.md (Self-Improvement): before ending any session that modified framework files, run `/improve` and the `framework-qa` agent. What they actually do:

- **`/improve`** (distributable version, `skills/improve/SKILL.md`) orchestrates `framework-improver-detector` (read-only scan; only write is the proposal file `.claude/state/improve-proposal.md`, filtered against the `/setup`-owned skip-list) then `framework-improver-applier` (re-validates the skip-list, applies, writes audit log `.claude/state/improve-applied.md`).
- **`framework-qa`** (`.claude/agents/framework-qa.md`, repo-local, not distributable) re-counts `templates/*` and `skills/*` and verifies every table and count in README, the CLAUDE.md template, setup summaries, and docs. It exists because the deterministic tests have known blind spots — see incident 7f82b84 below.

Known wrinkle (as of 2026-07-11): the copy installed at `.claude/skills/improve/SKILL.md` is an older generic variant paired with a single `.claude/agents/framework-improver.md`, not the detector/applier pair. This divergence is allowlisted drift (see ccf-dogfood-and-drift), not an error you should "fix" in passing.

### 5. Commit and open a PR

- Subjects are imperative: `Add`, `Fix`, `Update`, `Remove` (CLAUDE.md, Version Control; verify against `git log --oneline`).
- AI-assisted commits carry a `Co-Authored-By: Claude ... <noreply@anthropic.com>` trailer (observed throughout history, e.g. 9b7cd14).
- Integration branch is `main`; substantive work lands via PRs (recent history: `(#3)`–`(#6)` merge subjects). If you are on `main`, branch first.

## The non-negotiables

| Rule | Rationale | Incident |
|---|---|---|
| Never hand-edit counts in isolation. Counts change only together with the files they count, and tests verify the pairing. | A hand-edited count is a guess that rots instantly; doc/count drift across README, CLAUDE.md, AGENTS.md, docs/, `config/agents.json`, and both setup summaries is this repo's hardest live problem. | `b2da8ea` (2026-03-30) and `9b7cd14` (2026-04-01) both hand-fixed count drift — tests didn't exist yet (suite added in `4c688cf`, 2026-04-09). `7f82b84` (2026-06-11) fixed a stale agent count in docs/agent-patterns.md that the deterministic tests did NOT cover; framework-qa caught it. Lesson: tests shrink the drift surface, agents patrol the remainder, humans hand-edit nothing. |
| Every `setup.sh` change mirrors `setup.ps1` in the same change. | Only the bash path gets exercised in day-to-day macOS/Linux work; the PowerShell path breaks silently. | The PS smoke harness crashed before running any scenario, so the CI job gated nothing while real setup.ps1 bugs shipped (`e052200` + `0fe93ea`, 2026-06-11). Both fixes sat stranded on a side branch for a month before merging on 2026-07-11. A broken checker hides broken code. Full story: ccf-failure-archaeology Entry 1. |
| Rule `id`s are stable forever — never rename, never reuse. | The `id` is the citation key reviewer agents embed in findings in target repos; renaming orphans every past finding (`.claude/rules/templates.md`). | Codified preemptively; no known violation. Keep it that way. |
| Dogfood drift is allowlisted in `config/dogfood-drift-allowlist.txt`, never silent. | The repo intentionally runs a reduced roster of itself; the allowlist makes every intentional difference explicit so accidental drift fails `check-dogfood-drift.sh`. | The allowlist header states this policy directly. |
| Installed-surface names are backward-compatible: no renames of placeholders, `CCF_*` vars, or rule ids. | Rule ids: above. `CCF_*` vars: the global `/install-framework` skill is *copied* into `~/.claude/skills/` (`install-global-skill.sh` uses `cp -r`) — installed copies reference the old names forever and do not auto-update. Placeholder renames must land atomically in templates AND both setup scripts or `check-placeholders.sh` fails. | Maintainer policy; only the rule-id half is codified in `.claude/rules/templates.md`. Codifying the rest as a test is an open candidate, not done. |

## Editing the drift allowlist: legitimate vs papering over a bug

Legitimate — add an allowlist line when the difference is a *decision*:
- A repo-only tool (e.g. `framework-qa.md` exists only in `.claude/agents/`).
- The reduced in-repo roster (most template agents/skills intentionally not installed here).

Papering over — do NOT add a line when:
- You edited a template (or its `.claude/` twin) and the copies diverged by accident. Sync the two copies instead.
- A test failure appeared mid-change and allowlisting would make it green. That is routing around the gate.

Judgment test: can you write one sentence explaining WHY this repo needs a different version? If the sentence is "because I just edited one of them", sync instead. Every allowlist line is a liability the next session must reason about.

## Edge Cases

| Situation | What to do |
|---|---|
| `run-all.sh` fails on a check unrelated to your change | Fix it or file it — do not merge on top of a red suite; `e052200` shows how long a red CI job can silently sit on main |
| You must change a rule's meaning | Edit the body under the same `id`; if the concern genuinely splits, add a NEW id and leave the old file intact |
| framework-qa reports drift your change didn't cause | Fix it in a separate commit citing framework-qa (pattern: `7f82b84`), and note whether a deterministic test could cover it |
| Adding a prompt to the installers | Add its `CCF_*` var to BOTH non-interactive resolvers (CLAUDE.md, Non-Interactive Setup) |
| Change touches only `.claude/` in this repo | Check whether the twin in `templates/` or `skills/` should change too; if intentionally not, allowlist with rationale |
| No `pwsh` locally and you changed setup.ps1 | Say so in the PR and watch the windows CI job before merging (its harness has been sound since the 2026-07-11 merge — ccf-failure-archaeology Entry 1) |

## Related Skills

- **ccf-doc-sync-campaign** — the full matrix of which count/table lives in which file; go there when executing a doc-surface sweep
- **ccf-parity-playbook** — the bash↔PowerShell mirroring checklist when actually editing setup scripts
- **ccf-testing-and-qa** — anatomy of each `tests/check-*.sh`, what it gates and misses, how to extend
- **ccf-dogfood-and-drift** — allowlist file format and the `.claude/` vs `templates/` model
- **ccf-failure-archaeology** — longer narrative of past incidents beyond the hashes cited here

## Provenance and maintenance

Every claim above was verified against the repo on 2026-07-11. Re-verify with:

- Test roster: `ls tests/check-*.sh tests/*.ps1` (8 bash checks + 1 PowerShell smoke, as of 2026-07-11)
- Hard gate + auto-discovery: `grep -n 'check-\*.sh' tests/run-all.sh`
- CI jobs (bash suite + windows smoke): `cat .github/workflows/framework-tests.yml`
- Incident hashes: `git show --stat b2da8ea 9b7cd14 7f82b84 e052200 0fe93ea`
- Test-suite introduction date: `git log --oneline --diff-filter=A -- tests/run-all.sh` (→ `4c688cf`)
- Consistency-test blind spots (covers README + setup.sh summary only): `grep -n 'README\|SETUP_SH' tests/check-consistency.sh`
- Registry lockstep surfaces: `sed -n '1,8p' tests/check-agent-registry.sh`
- Rule-id stability rule: `grep -n 'stable forever' .claude/rules/templates.md`
- Global skill installed by copy: `grep -n 'cp -r' install-global-skill.sh`
- Allowlist policy header: `head -6 config/dogfood-drift-allowlist.txt`
- Commit conventions in practice: `git log -20 --format='%s | %(trailers:key=Co-Authored-By,valueonly)'`

Re-verify this skill whenever any of these changes: files under `tests/`, `.github/workflows/framework-tests.yml`, the CLAUDE.md Self-Improvement or Version Control sections, `config/dogfood-drift-allowlist.txt` policy header, or the `/improve` skill (either copy).
