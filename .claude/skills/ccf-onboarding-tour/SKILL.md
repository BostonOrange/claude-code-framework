---
name: ccf-onboarding-tour
description: Load this at the start of any first session in the claude-code-framework repo — when you (human or model) have zero context and need the right mental model before doing anything. Triggers include "where do I start?", "give me a tour of this repo", "how does this framework fit together?", "what should I read first?", or being dropped into an unfamiliar task here without prior sessions. Pure orientation via a 10-stop guided reading order; it changes nothing and routes every action to a sibling ccf-* skill.
last_updated: 2026-07-11
tested_with: claude-fable-5
stability: experimental
scope: preset
---

# CCF Onboarding Tour

A guided reading order for the claude-code-framework repo: ten stops, in sequence, each with what to NOTICE (~45 minutes for a human, one pass for a model session). Read-only orientation — it never tells you how to change anything; actions route to siblings via the table at the end.

Context in one sentence: this repo IS the framework (skills/agents/commands/rules/hooks as markdown + bash), installed into *target* projects by `setup.sh` / `setup.ps1` with `{{PLACEHOLDER}}` substitution — it is never itself a target. The invariants behind each "notice" bullet are owned by **ccf-architecture-contract**; this tour only points at their footprints.

## Usage

**Load when:** it is your first session in this repo; you were handed a task ("fix X", "add a skill") with no prior context; or someone asks "how does this all fit together?".

**Do NOT load when:** you already know the repo and need vocabulary or counts (→ **ccf-domain-reference**), you're mid-change and need gating rules (→ **ccf-change-control**), or a test just failed (→ **ccf-testing-and-qa**). This tour will not tell you how to do anything — it exists so the other skills make sense faster.

## Process: the tour, in order

Read the stops in order — each builds on the previous. Commands are copy-pasteable from the repo root. Line counts and numbers are anchors **(as of 2026-07-11)**; if they've drifted, trust the repo, not the tour.

### Stop 1 — `CLAUDE.md` (repo root)

**Notice:**
- The first bold sentence: *"This repo is the framework itself, NOT a target project. Do not run setup.sh here."* Most confusion here traces back to forgetting this.
- The **Agents Available** table lists 39 template agents; the note beneath flags `framework-qa` as in-repo-only. Counts like "27 workflow skills", "39 agents", "23 rules" recur across *many* files — doc/count drift is the maintainer's hardest live problem, and the discipline is: **never hand-edit a count in isolation; counts change only together with the files they count, verified by tests** (owned by ccf-doc-sync-campaign).
- The **Self-Improvement** section: sessions that modify framework files end with `/improve` + `framework-qa`, with `tests/run-all.sh` as the deterministic hard gate (owned by ccf-change-control).

### Stop 2 — `README.md`

**Notice:**
- The three-layer architecture table near the top: workflow skills (portable) / integration adapters (swappable) / domain knowledge (project-specific). This is the mental model for what's generic vs configured.
- The Quick Start shows how *targets* consume this repo: `cd your-project/ && bash ~/claude-code-framework/setup.sh` — and repeats the "do not run setup.sh inside the framework repo" warning.
- README restates the same counts as CLAUDE.md ("AI Agents (39 specialized teammates)") — a second doc surface that must move in lockstep.

### Stop 3 — `setup.sh` (1332 lines, as of 2026-07-11)

The whole install lifecycle lives in one file. Skim by section headers (`grep -n "^# ──" setup.sh`):

**Notice:**
- Argument parsing at the top: `--dry-run`, `--reset`, `--non-interactive` (the CCF_* env-var interface; semantics owned by ccf-release-and-install).
- The prompt section (~lines 138–409): seven numbered prompts — project type (9 choices), tracker, CI/CD, base branch, notification, short name, design system.
- The copy sections (~lines 724–926), then a single python3 heredoc (`REPLACE_ALL_EOF`, ~line 945) that loads `config/placeholders.json` and replaces every `{{NAME}}` across skills/agents/commands/rules/hooks in one pass.
- The Summary block (~line 1278) prints hardcoded counts ("27 workflow skills", "39 AI agents", …) — yet another count surface.
- Everything here must be mirrored in `setup.ps1` (owned by ccf-parity-playbook).

### Stop 4 — `config/placeholders.json` + `config/project-types.json`

**Notice:**
- `placeholders.json`'s `_description` declares itself the *canonical* placeholder → env-var/default mapping, consumed by both installers and enforced by `tests/check-placeholders.sh`.
- The exception: the `claude_md_only` group is (as of 2026-07-11) consumed only by `tests/check-placeholders.sh`; `setup.sh` still hardcodes those same values inline in its CLAUDE.md-generation block (~line 1031). Verify with `grep -n "claude_md_only" setup.sh setup.ps1 tests/*.sh`.
- `project-types.json` maps each of the 9 project types (salesforce … generic) to concrete commands and glob patterns; `generic` uses `# Configure your X command` comments. This data is what makes one set of templates serve nine stacks.

### Stop 5 — `templates/rules/dry.md` (any rule works; this one is exemplary)

**Notice:**
- Frontmatter: `id: dry` plus a `patterns` array using `{{SOURCE_PATTERNS}}`. The `id` is a **stable citation key** — reviewer agents cite it in findings, so it can never be renamed or reused (see `.claude/rules/templates.md`).
- The body is a citable *standard*, not a suggestion: thresholds ("3+ sites: flag"), explicit anti-patterns, and a "What NOT to Flag" section. Rules teach reviewers what to suppress as much as what to catch.

### Stop 6 — `templates/agents/review-coordinator.md`

**Notice:**
- Frontmatter `tools:` includes `Agent` — coordinators spawn sub-agents; leaf reviewers are read-only.
- It classifies diffs into `trivial`/`lite`/`full` risk tiers and routes specialists by diff content, then dedupes findings by `file:line:rule_id` — this is where Stop 5's stable rule ids pay off ("Don't invent rule IDs").
- It operates against `docs/finding-schema.md` — agents share contracts through docs/, not through each other.

### Stop 7 — `skills/develop/SKILL.md`

The flagship workflow skill (the "/develop TICKET-1234" end-to-end cycle).

**Notice:**
- Nine numbered phases (fetch → analyze → branch → implement → validate → fix → PR → tracker → improvement), plus a Factory Mode table that swaps interactive gates for auto-defaults.
- Placeholders inline in the prose: `{{TRACKER_FETCH_TICKET}}`, `{{BASE_BRANCH}}`, `{{PROJECT_SHORT_NAME}}` — skills ship half-finished on purpose; setup finishes them per target.
- It ends with Edge Cases and Related Skills sections — the house style every skill (including this one) must follow (see `.claude/rules/skills.md`).

### Stop 8 — `tests/run-all.sh` + `tests/check-dogfood-drift.sh`

**Notice:**
- `run-all.sh` discovers tests by glob (`find … -name "check-*.sh"`): a new `check-*.sh` auto-registers. Corollary: `check-setup-smoke.ps1` is NOT run by it — bash-only glob (as of 2026-07-11).
- `check-dogfood-drift.sh` works in a `mktemp -d` dir with a cleanup `trap` — tests are hermetic, never writing into the repo.
- It `diff -qr`s five surfaces of `.claude/` against `templates/`+`skills/`, then `comm`-fails in *both* directions: unexpected drift AND stale allowlist entries. (What each check gates and misses: ccf-testing-and-qa.)

### Stop 9 — `config/dogfood-drift-allowlist.txt`

**Notice:**
- This file IS the contract for how this repo dogfoods itself: `.claude/` carries a curated *subset* of the templates (12 agents vs 39; `improve` + `team` skills adapted), and every difference must be listed here explicitly, in the exact normalized line the test emits.
- Lines like `Only in .claude/agents: framework-qa.md` and `Only in .claude/agents: framework-improver.md` show in-repo-only agents; the long `Only in templates/agents:` block shows what was deliberately *not* installed here. Mechanics and edit rules: ccf-dogfood-and-drift.

### Stop 10 — see the divergence with your own eyes

```bash
diff .claude/skills/team/SKILL.md skills/team/SKILL.md
```

**Notice:**
- The dogfooded `/team full` runs 12 agents; the template's `/team full` claims "All 16" review/implementation agents — a figure ccf-doc-sync-campaign drift item 6 flags as unverified (its roster enumerates 15; count before relying on it) — and the template adds `review-deep`, `quality-deep`, and `design` teams.
- The template references the `framework-improver-detector`/`-applier` pair; the in-repo copy still uses a single `framework-improver` agent. Same skill name, two deliberate versions — "curated subset" in practice, and why the allowlist exists.

## Where to go next

| Your task | Load |
|-----------|------|
| Fixing a bug / test failure triage | ccf-debugging-playbook, then ccf-testing-and-qa |
| Adding or changing a skill/agent/command/rule | ccf-change-control + ccf-dogfood-and-drift (and ccf-doc-sync-campaign — counts move everywhere) |
| Touching `setup.sh` / `setup.ps1` | ccf-parity-playbook + ccf-release-and-install |
| Understanding a term, count, or placeholder | ccf-domain-reference |
| Asking "why is it built this way?" / "will this break an invariant?" | ccf-architecture-contract |
| Setting up your machine to work here | ccf-build-and-env |
| Understanding a past incident or re-fix | ccf-failure-archaeology |
| Declaring anything "done" | ccf-testing-and-qa — and remember the bar: a change is not done until EVERY doc surface reflects it |

## Edge Cases

| Situation | What to do |
|-----------|------------|
| A tour stop's file is missing or moved | The tour is stale, not the repo. Trust the repo; run the Provenance commands below and flag this skill for update. |
| Line numbers in Stop 3 don't match | They're anchors as of 2026-07-11. Navigate by section header instead: `grep -n "^# ──" setup.sh`. |
| An `ls \| wc -l` count disagrees with a doc | You've found live doc drift — the repo's known hardest problem. Do not hand-fix the number; load ccf-doc-sync-campaign. |
| You spot a bug or improvement mid-tour | Note it; do not edit anything. All changes go through ccf-change-control (tests are the hard gate). |
| You're onboarding to a TARGET project that installed CCF | Wrong tour — the target's own CLAUDE.md is authority there; see README.md Quick Start steps 3–5 for the consumer view. |
| Severely limited context budget | Minimum viable tour: Stops 1, 3, and 9 (identity, lifecycle, dogfood contract). |

## Related Skills

- **ccf-architecture-contract** — the WHY behind every "notice" bullet; before structural changes.
- **ccf-domain-reference** — vocabulary and the config/*.json catalog; for lookups after the tour.
- **ccf-change-control** — the moment orientation ends and modification begins.
- **ccf-doc-sync-campaign** — when any count/table across doc surfaces looks stale.
- **ccf-parity-playbook** — before touching either installer.
- **ccf-testing-and-qa** — before running or extending `tests/`, or claiming done.
- **ccf-dogfood-and-drift** — for anything under `.claude/` or the drift allowlist.
- **ccf-release-and-install** — installer flags, CCF_* vars, rollback.
- **ccf-build-and-env** — fresh-machine setup.
- **ccf-debugging-playbook** / **ccf-failure-archaeology** — live triage / settled history.

## Provenance and maintenance

Every fact above was verified against the repo on 2026-07-11. Re-verify with:

| Fact | Command | Expected (as of 2026-07-11) |
|------|---------|------------------------------|
| 39 template agents | `ls templates/agents/*.md \| wc -l` | 39 |
| 27 skills + 1 template | `ls -d skills/*/ \| wc -l` | 28 |
| 11 commands / 23 rules / 8 hook scripts | `ls templates/commands/*.md \| wc -l; ls templates/rules/*.md \| wc -l; ls templates/hooks/*.sh \| wc -l` | 11 / 23 / 8 |
| setup.sh size + section map | `wc -l setup.sh; grep -n "^# ──" setup.sh` | 1332 lines |
| placeholders.json is canonical; claude_md_only test-only | `grep -n "placeholders.json\|claude_md_only" setup.sh setup.ps1 tests/check-placeholders.sh` | claude_md_only only in the test |
| 9 project types | `python3 -c "import json; print(len(json.load(open('config/project-types.json'))))"` | 9 |
| Rule ids stable, e.g. `dry` | `head -5 templates/rules/dry.md` | `id: dry` |
| run-all globs bash checks only | `grep -n 'check-\*' tests/run-all.sh; ls tests/check-*.sh \| wc -l` | find on `check-*.sh`; 8 checks |
| Dogfood roster is 12 agents | `ls .claude/agents/*.md \| wc -l` | 12 |
| team skill divergence is real | `diff .claude/skills/team/SKILL.md skills/team/SKILL.md \| head` | non-empty diff |

**Re-verify this skill when:** any of the ten stop files changes materially (new setup.sh sections, new/removed skills/agents/rules, allowlist edits), when `tests/check-consistency.sh` or the drift allowlist changes, or when a sibling ccf-* skill is added/renamed (the routing tables here must track them).
