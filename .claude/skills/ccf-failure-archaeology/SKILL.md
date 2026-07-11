---
name: ccf-failure-archaeology
description: Load before re-investigating anything in claude-code-framework that smells like a past battle — "why did the PowerShell CI job fail?", "didn't we already fix this count?", "should we add a husky pre-commit hook?", "do we need a broad refactor agent?", "what is on the unmerged assessment branch?". Contains the chronicle of settled investigations (symptom, root cause, evidence hash, status, lesson) so sessions do not re-fight them. Not the current drift fix list (ccf-doc-sync-campaign) and not live-failure triage (ccf-testing-and-qa / ccf-parity-playbook).
last_updated: 2026-07-11
tested_with: claude-fable-5
stability: experimental
scope: preset
---

# Failure Archaeology — the Chronicle of Settled Battles

The repo's incident history: significant investigations, dead ends, and re-fixes, written up so nobody rediscovers a root cause already in `git log`. Every hash was re-verified against this repo on 2026-07-11 with `git show <hash>` and `git branch -a --contains <hash>`.

**Status vocabulary:** `fixed-on-main` (merged, done), `stranded` (fix exists only on `origin/claude/codebase-assessment-7p9rq7`, NOT on main), `open` (known, unfixed), `settled-decision` (deliberately rejected — do not reintroduce).

## Usage

Load this when a symptom matches an entry (the Edge Cases table maps symptoms to entries), when about to propose something the repo already tried and removed (pre-commit git hooks, a broad refactor agent), or when assessing the stalled remote branch.

Do NOT load this for: the current doc-drift fix campaign (**ccf-doc-sync-campaign**), what each test gates today (**ccf-testing-and-qa**), bash/PowerShell mirroring procedure (**ccf-parity-playbook**), or merge gating (**ccf-change-control**). This skill is history and judgment; siblings own current state and procedure.

## Entry 1 — The PowerShell smoke chain (flagship)

The single most instructive incident in this repo's history. Three commits, three layers of failure, and the fixes are split across main and a stranded branch.

**Chapter 1: `42e6a98` (2026-05-28, fixed-on-main).**
- *Symptom:* `setup.ps1` threw parser errors under Windows PowerShell 5.1 (no `pwsh` installed).
- *Root cause:* without a UTF-8 BOM, WPS 5.1 read the file as ANSI and mis-decoded an em-dash in the pre-commit sentinel string as a smart quote, closing the string early. Fix: add the BOM (a 1-line change to `setup.ps1`).
- *Lesson:* `setup.ps1` must keep its UTF-8 BOM forever; the em-dash sentinel must byte-match `setup.sh` and the installed hook.

**Chapter 2: `e052200` (2026-06-11, stranded).**
- *Symptom:* the "PowerShell setup smoke" job in `.github/workflows/framework-tests.yml` had been failing on main — and never got far enough to test `setup.ps1` at all.
- *Root cause:* the harness itself, `tests/check-setup-smoke.ps1`, declared a `$Home` function parameter and assigned `$home` and `$args` locals. Those are read-only automatic variables in PowerShell, so the first `Invoke-SetupProcess` call threw `ScriptHalted` before any scenario ran. The commit message says it plainly: "This is why the 'PowerShell setup smoke' CI job has been failing on main." The gate was silently broken; real product failures were invisible.
- *Lesson (the big one):* **when a test never passes — or never fails — first suspect the test.** A permanently-red CI job is not flaky noise; it is a disabled gate.

**Chapter 3: `0fe93ea` (2026-06-11, stranded).**
- *Symptom:* once the harness ran, two real `setup.ps1` bugs surfaced immediately.
- *Root causes:* (a) npm `package-lock.json` keeps the root package under an empty-string `""` key; PowerShell's default `ConvertFrom-Json` rejects "property whose name is an empty string", aborting the internal-app flow — fixed with `-AsHashtable` on PowerShell 6+; (b) the branch-rename confirmation prompt was asked in a different order than `setup.sh`, so scripted/dry-run input reached the wrong prompt.
- *Lesson:* a repaired gate pays for itself within minutes. Both bugs shipped on main the whole time the harness was broken.

**Current status (as of 2026-07-11):** chapters 2 and 3 (`e052200`, `0fe93ea`) exist ONLY on `origin/claude/codebase-assessment-7p9rq7`. Main's `tests/check-setup-smoke.ps1` still contains the `$Home`/`$args` crash (verify: `grep -n '\$Home' tests/check-setup-smoke.ps1`), and main's `setup.ps1` still lacks `-AsHashtable` (verify: `grep -c AsHashtable setup.ps1` → 0). The PowerShell CI job should therefore still be failing on main. Merging that branch is the fix; do not re-diagnose from scratch.

## Entry 2 — Count drift, the recurring disease

- *Symptom:* stated counts (skills, agents) disagree with `ls | wc -l` reality, repeatedly, across README, CLAUDE.md, docs, and both setup-script summaries.
- *Recurrences with evidence:*
  - `b2da8ea` (2026-03-30): skill count 18 → 16 corrected in README.md, `setup.sh`, and `setup.ps1` simultaneously.
  - `9b7cd14` (2026-04-01): the `framework-qa` agent found 5 pre-existing QA issues in one pass — agent count 13 → 12 in two places in CLAUDE.md, an incomplete `docs/architecture.md` diagram (9 of 16 skills shown), and a missing Salesforce project type in `setup.ps1`.
  - `7f82b84` (2026-06-11, stranded): agent count 38 → 39 in `docs/agent-patterns.md`; the commit message explicitly notes the line "is not covered by the deterministic consistency tests, and predates this session's changes."
- *Root cause:* the same fact lives in many files with no single source of truth; humans and agents edit the files they touched and miss the rest.
- *What it led to:* deterministic guards — `tests/check-consistency.sh` (added in `4c688cf`, 2026-04-09) and `tests/check-agent-registry.sh` (added in `af62024`, 2026-04-24).
- *Status:* partially fixed; drift persists on surfaces the tests do not read (that is exactly what `7f82b84` proves). The current drift inventory and doc-surface matrix are owned by **ccf-doc-sync-campaign** — do not duplicate them here.
- *Lesson:* NEVER hand-edit a count in isolation; counts change only together with the files they count, verified by tests. An "unguarded doc surface" is a drift incident waiting for its hash.

## Entry 3 — Pre-commit git hooks: rejected twice (settled-decision)

- *Symptom:* someone proposes husky/lint-staged or pre-commit-framework wiring "for safety."
- *History:* the husky/lint-staged/pre-commit setup block shipped in the initial commit `7e5a192` (2026-03-15 14:38) and was removed the SAME DAY by `0ee06f5` (17:02): "Formatting is handled by /validate skill and CI — pre-commit hooks add friction without additional value in this workflow." It was then re-added inside `d7c53e2` (2026-03-30, the big "AI factory" expansion) and removed a second time in `af62024` (2026-04-24). Rejected twice.
- *Status:* settled-decision. The repo chose explicit test runs (`tests/run-all.sh`) plus PreToolUse `guardrails.sh` over git-hook enforcement. Today `setup.sh`/`setup.ps1` only *detect* an existing husky hook in target repos and warn (`grep -n husky setup.sh`).
- *Lesson:* do not reintroduce git-hook-based enforcement without reading both removal commits and making a new argument that answers them.

## Entry 4 — refactor-advisor: retired, do not recreate (settled-decision)

- *Symptom:* the agent roster "looks like it's missing" a general refactoring reviewer.
- *History:* `c3b59a6` (2026-04-28) retired `refactor-advisor` because its scope was fully covered by three narrow specialists: `dry-reviewer`, `complexity-reviewer`, `code-smell-reviewer`. The review-coordinator even carried a tiebreak rule ("dry-reviewer wins over refactor-advisor on extraction") that proved the overlap. `/team design` substituted `frontend-architecture-reviewer`. Counts went 40 → 39 agents across 15 files in one commit — a model example of Entry 2's discipline.
- *Status:* settled-decision. If a review gap appears, extend a specialist's rule file rather than resurrecting a broad agent.

## Entry 5 — The 4-round self-review grind on setup/improver (pattern)

- *What happened:* the `/setup` + `/improve` agent surface (detector/applier pairs, security-sensitive bash) took SIX hardening commits in one day (2026-04-26), all on main, in chronological order: `e002a1b` (round 1: split project-setup into detector + applier) → `9629535` (round 2: harden allowlist, enforce lifecycle, extract `docs/setup-state-schema.md`) → `d95c784` (deferred: framework-improver split, lockfile, TOCTOU, dirty-opt-out) → `6d9a13f` (round 3: runtime breakage repairs, applier parity, state-schema completion) → `23fc986` (round 3 deferred: atomic lockfile, honest detector framing, expanded forbidden list, `docs/applier-pattern.md`) → `0359dfd` (round 4: dedup snapshot bash, clarify improver state precondition).
- *Status:* fixed-on-main.
- *Lesson:* security-sensitive bash (anything that writes files from a computed plan) does not converge in one review pass here — budget for lockfile/TOCTOU/allowlist iteration; even round 3 had to repair runtime breakage introduced by rounds 1–2. Read `docs/applier-pattern.md` before touching detector/applier agents.

## Entry 6 — Smoke-test hermeticity: host config leaks (stranded)

- *Symptom:* `tests/check-setup-smoke.sh` behaved differently across machines.
- *Root cause:* the throwaway git repo inherited host global config — commit signing (`commit.gpgsign`), `init.defaultBranch`, and hooks path — and used `git init -b`, which requires git >= 2.28. Fixed in `199417f` (2026-06-11), which also fixed an unanchored-grep bug in `run-all.sh`'s failure summary and three template-hook robustness bugs (space-safe iteration in `pre-commit.sh`, Python 3.12 `pkg_resources` removal in `session-start.sh`, SQL single-quote escaping in `codebase-index.sh`).
- *Status:* stranded on `origin/claude/codebase-assessment-7p9rq7`.
- *Lesson:* any new test that shells out to git must isolate itself from host global config. **ccf-testing-and-qa** owns the current hermeticity rules.

## Entry 7 — `af62024` "chore: update files" (anti-pattern)

`af62024` (2026-04-24) is a 36-file, ~1,700-insertion commit — it added `tests/check-agent-registry.sh`, rewrote guardrails and hooks, and removed the husky block a second time — under the message "chore: update files". It is the hardest commit in this history to do archaeology on; every claim about it above required diffing. *Status:* history is immutable, the lesson is not. Commit messages follow `Add`/`Fix`/`Update`/`Remove` with substance (CLAUDE.md, Version Control). If a commit does five things, it is five commits.

## Entry 8 — Stalled branch inventory (as of 2026-07-11)

`origin/claude/codebase-assessment-7p9rq7` is 4 ahead / 0 behind main (verify: `git log --oneline main..origin/claude/codebase-assessment-7p9rq7` and the reverse). Its four commits, all from one 2026-06-11 session, are all pure fixes with high salvage value and zero conflict risk (0 behind):

| Hash | What it fixes | Why it matters |
|------|---------------|----------------|
| `199417f` | Smoke hermeticity + 3 hook bugs (Entry 6) | Test flakiness + target-repo hook bugs live on main |
| `7f82b84` | Agent count 38→39 in `docs/agent-patterns.md` (Entry 2) | Known unguarded drift, already diagnosed |
| `e052200` | PowerShell smoke harness crash (Entry 1) | The PS CI gate is disabled until this merges |
| `0fe93ea` | Real `setup.ps1` bugs behind the broken gate (Entry 1) | Windows installs of internal-app flow break on main |

*Status:* open — merging this branch is the highest-leverage single action available. Route the merge through **ccf-change-control**.

## Edge Cases

| Situation | What to do |
|-----------|------------|
| PowerShell CI job red on main | Entry 1: harness crash, fix is stranded on the assessment branch — merge it, do not re-debug |
| A CI job has "always been red" (or always green while bugs ship) | Entry 1 lesson: suspect the test harness before the product |
| A doc count disagrees with `ls \| wc -l` | Entry 2 for history and the never-hand-edit rule; ccf-doc-sync-campaign for the fix procedure |
| Tempted to add husky / lint-staged / pre-commit framework | Entry 3: rejected twice (`0ee06f5`, `af62024`); read both before proposing again |
| Proposing a broad "refactoring" reviewer agent | Entry 4: retired in `c3b59a6`; extend a specialist rule instead |
| Writing/modifying detector–applier agents or setup bash | Entry 5: expect multi-round hardening; read `docs/applier-pattern.md` first |
| New test shells out to git and passes locally, fails in CI (or vice versa) | Entry 6: host git config leak; isolate signing/defaultBranch/hooks |
| Hash cited here not found or branch missing | The branch was merged or deleted since 2026-07-11 — re-run the Provenance commands and update this file |
| About to write "chore: update files" | Entry 7. Split the commit and say what it does |

## Related Skills

- **ccf-doc-sync-campaign** — switch here for the current drift inventory, the doc-surface matrix, and the executable fix campaign (Entry 2 is the history behind it).
- **ccf-debugging-playbook** — switch here to triage a failure happening NOW; come back here if it matches a settled battle.
- **ccf-testing-and-qa** — switch here for what each `tests/check-*.sh` gates today and hermeticity rules for new checks.
- **ccf-parity-playbook** — switch here for the bash↔PowerShell mirroring procedure the Entry 1 bugs violated.
- **ccf-change-control** — switch here to actually merge the stranded branch or classify any change.
- **ccf-architecture-contract** — switch here for the design rationale behind the invariants these incidents produced.

## Provenance and maintenance

Every entry was verified on 2026-07-11 against this clone. Re-verification commands:

- Branch inventory / stranded status: `git branch -a` ; `git log --oneline main..origin/claude/codebase-assessment-7p9rq7` (expect `0fe93ea e052200 7f82b84 199417f`; empty means merged — update Entries 1, 2, 6, 8).
- Any hash claim: `git show --stat <hash>` and `git branch -a --contains <hash>`.
- Harness crash still on main: `grep -n '\$Home' tests/check-setup-smoke.ps1` (hits = still broken).
- Lockfile fix still absent on main: `grep -c AsHashtable setup.ps1` (0 = still absent).
- Husky removals: `git log --all --oneline -S husky -- setup.sh` (expect `af62024 d7c53e2 0ee06f5 7e5a192`).
- Test-guard origins: `git log --all --oneline --diff-filter=A -- tests/check-consistency.sh tests/check-agent-registry.sh`.
- CI job name: `grep -n 'PowerShell setup smoke' .github/workflows/framework-tests.yml`.

**Re-verify this skill when:** `origin/claude/codebase-assessment-7p9rq7` is merged or deleted (Entries 1, 2, 6, 8 change status), any new "the gate was silently broken" incident occurs (add it as a new entry with hashes), or a settled decision (Entries 3, 4) is deliberately revisited.
