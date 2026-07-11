---
name: ccf-testing-and-qa
description: Load this before claiming any claude-code-framework change is "done", before running or extending tests/run-all.sh, or when a check-*.sh test fails and you need to know what it actually gates. Trigger on "run the tests", "why did check-placeholders/check-dogfood-drift/check-consistency fail", "is this change covered by tests", "add a test for X", or "the suite is green — am I done?". Explains the anatomy of the 8-check suite, what each check gates AND misses, the python3 dependency reality, hermeticity rules for new checks, and the evidence bar the maintainer requires.
last_updated: 2026-07-11
tested_with: claude-fable-5
stability: experimental
scope: preset
---

# CCF Testing and QA

The deterministic suite in `tests/` is the hard gate for every framework change (CLAUDE.md "Self-Improvement" table). This skill covers what the suite proves, what it silently does not, how to extend it, and what evidence "done" requires. Maintainer's discipline rule: **never hand-edit a count in isolation — counts change only together with the files they count, verified by tests.**

## Usage

Load when: running or interpreting `tests/run-all.sh`; deciding whether a green suite is sufficient evidence for a change; adding a new `check-*.sh`; debugging a red check.

Do NOT load for: which doc surface holds which count (that matrix is owned by **ccf-doc-sync-campaign**); bash↔PowerShell mirroring mechanics (**ccf-parity-playbook**); the meaning of allowlisted `.claude/` drift (**ccf-dogfood-and-drift**); setup.sh internals when a smoke assert fails (**ccf-release-and-install**).

## Process: verifying a change is "done"

1. **Run the suite**: `bash tests/run-all.sh` from repo root. It auto-discovers `tests/check-*.sh` by glob (`find "$TESTS_DIR" -maxdepth 1 -name "check-*.sh"`, sorted). Consequence: `tests/check-setup-smoke.ps1` is **not** discovered — the PowerShell smoke runs only in CI (`.github/workflows/framework-tests.yml`, `powershell` job on `windows-latest`). CI's bash job also runs `bash -n setup.sh tests/*.sh templates/hooks/*.sh` before the suite; run that locally too if you touched any shell file.
2. **Read the real output, don't pattern-match the exit code.** Expected shape as of 2026-07-11: 8 checks, a summary table, final line `RESULT: ALL TESTS PASSED (8 of 8)`. Per-check Results lines today: agent-registry 234 passed, consistency 12, global-skill 6, guardrails 55, placeholders 47 (of 47 unique tokens), setup-smoke 80, templates 109; dogfood-drift prints `Actual drift entries: N` instead. A drop in these numbers under a green suite means coverage shrank — investigate.
3. **Run the change-class checks** (see "Evidence bar" below) — the suite does not cover everything.
4. **If nothing gates your change class, extend the suite** before merging (see "Adding a check").

## Per-check anatomy: what each gates and misses

All checks are standalone bash scripts; each exits 0/non-zero and prints `[PASS]/[FAIL]` lines.

| Check | Gates | Misses |
|---|---|---|
| `check-agent-registry.sh` | `config/agents.json` in lockstep with `templates/agents/*.md` (entry↔file existence both directions, frontmatter `description` exact-match vs registry) plus every agent **name** referenced in README.md, `templates/CLAUDE.md.template`, `docs/teams.md`, `docs/agents-commands-rules.md` | **Silently exits 0 with a SKIP message if python3 is absent** — zero registry coverage on that machine. Checks names only, not counts or table-row correctness, in the 4 docs. `AGENTS.md` is not among the 4 docs. |
| `check-consistency.sh` | Skill/agent/command/rule/hook/workflow counts stated in `setup.sh` summary and README.md vs actual file counts; README agent-table row count vs agent files | Counts in `AGENTS.md`, `docs/*`, and `templates/CLAUDE.md.template` are entirely unguarded. Greps are phrase-anchored (e.g. `N workflow skills`); the README workflows count SKIPs silently when the phrase isn't found. |
| `check-dogfood-drift.sh` | `diff -qr` of `.claude/{agents,hooks,skills}`, `.claude/settings.local.json`, `.claude/statusline` against `templates/`+`skills/`; every diff line must appear verbatim (normalized, repo-relative) in `config/dogfood-drift-allowlist.txt`; stale allowlist entries also fail | Only those five paths — `.claude/rules/`, `.claude/commands/`, `.mcp.json` are never compared. File-level only (`-q`): it flags *which* files differ, never whether the drift content is sane. |
| `check-global-skill.sh` | 6 greps on `global-skills/install-framework/SKILL.md`: exists, `name:`, `description:`, GitHub remote URL, `--non-interactive`, `-NonInteractive` | Grep-presence only; nothing about whether the skill's instructions work. |
| `check-guardrails.sh` | Pipes `{"tool_input":{"command":"..."}}` JSON into `templates/hooks/guardrails.sh` and asserts exit codes: 0 safe (15 cases), 1 soft block (20), 2 hard block (20) | Tests the **template** copy only. `.claude/hooks/guardrails.sh` differs (allowlisted drift) and is untested. The other 7 template hooks have no behavioral tests at all. |
| `check-placeholders.sh` | Every `{{UPPER_SNAKE}}` token in `templates/`+`skills/` (47 unique as of 2026-07-11) resolvable by **both** setup scripts: literal presence in each, or listed in `config/placeholders.json` (JSON counts for both, since both consume it) | 26 of the 47 tokens are JSON-only; without python3 they all FAIL loudly (not a skip). A malformed `placeholders.json` is masked by `2>/dev/null`, producing misleading "not found" failures. Never verifies replacement *values* make sense — smoke's job. |
| `check-setup-smoke.sh` | End-to-end `setup.sh` in `mktemp` dirs with per-case isolated `HOME` (80 assertions): nodejs/python/react/internal-app interactive cases, `--dry-run` branch-rename safety (no mutation, clean git status), non-interactive nodejs, missing `CCF_PROJECT_TYPE` error path | Every case selects tracker=none and notification=none — `config/trackers.json`/`notifications.json` substitution never exercised end-to-end. `--reset` never run. Non-interactive covers nodejs only; the 8 `invalid CCF_*` error branches (setup.sh lines 66–130) and internal-app `CCF_HOSTING_TARGET`/`CCF_STORAGE_PROVIDER`/`CCF_POSTGRES_PROVIDER` unexercised. The generic `.env` append block content is never asserted; internal-app `.env.example` gets only two substring greps ("Vercel", "Azure Container Apps"). |
| `check-templates.sh` | Grep-level frontmatter presence: agents (`name`,`description`,`tools`,`model`), skills (`name`,`description`), rules (`patterns`), commands (`name`,`description`,`allowed-tools`), hooks (`#!/bin/bash` shebang, CR-tolerant) | Does **not** YAML-parse — bad indentation, duplicate keys, malformed lists all pass. Does not check the rule `id` field even though `.claude/rules/templates.md` requires it. Does not enforce "read-only agents must lack Edit/Write". No hook arg-handling/exit-code checks. |

### The python3 reality (corrects common folklore)

The suite does not "silently skip two checks" without python3. Verified behavior (as of 2026-07-11): `check-agent-registry` is the only silent skip (exit 0). `check-placeholders` degrades **loudly** — the 26 JSON-only tokens fail. `check-setup-smoke` also fails loudly because `setup.sh` hard-requires python3 (`ERROR: python3 is required`, setup.sh line 21). So a python3-less machine yields a red suite except for the one dangerous case: agent-registry drift passes unseen. Check for the SKIP line before trusting green.

## Known coverage gaps (as of 2026-07-11 — candidates for new checks)

Condensed from the Misses column — the union of what NO check covers: tracker/notification substitution paths; `setup.sh --reset`; non-interactive mode beyond the nodejs happy path; `.env`/`.env.example` contents beyond two substring greps; behavior of the 7 non-guardrails hooks and the dogfooded `.claude/hooks/guardrails.sh`; counts in `AGENTS.md` and `docs/` prose; YAML validity and rule `id` presence/stability.

## Adding a check

1. Create `tests/check-<name>.sh` starting with `#!/bin/bash`. No registration needed — run-all discovers it at runtime; it is invoked via `bash "$script"`, so `chmod +x` is optional (but conventional).
2. Exit 0 on pass, non-zero on fail. Match house style: `[PASS]`/`[FAIL]` lines plus a `Results: N passed, M failed` footer.
3. **Hermeticity rules** — copy the proven patterns: `TMP_DIR=$(mktemp -d "${TMPDIR:-/tmp}/ccf-<name>.XXXXXX")` + `trap 'rm -rf "$TMP_DIR"' EXIT` (`tests/check-dogfood-drift.sh` lines 10–11), and per-case `HOME="$isolated_home"` for anything that could touch `~/.claude` (`tests/check-setup-smoke.sh` lines 8–15 and 122). Never write inside the repo.
4. Prefer loud failure over silent skip when a dependency (python3) is missing — agent-registry's silent skip is the cautionary example.
5. Naming trap: run-all's summary table marks failures by **substring** match on the name (`tests/run-all.sh` line 70). Don't name a check so its basename is a substring of another's, or table rows misreport.
6. PowerShell tests (`.ps1`) are invisible to run-all — wire them into `.github/workflows/framework-tests.yml` manually.

## Evidence bar for "done"

A change is not done until every doc surface reflects it, and the suite proves only part of that. Required evidence, by change class:

- **Always**: `bash tests/run-all.sh` green locally, final line read (not assumed), 8 of 8.
- **Templates/skills/setup scripts touched**: read the smoke section of the output — per-assert `[PASS]` lines, not just the table. Then `grep -r "{{" .claude/ CLAUDE.md | grep -v ".git"` in a scratch install (CLAUDE.md "Testing Changes"). `bash -n setup.sh` if you edited it. If pwsh is available, `pwsh -File tests/check-setup-smoke.ps1`; otherwise expect the Windows CI job to be your first PowerShell signal.
- **Counts or docs touched**: green suite is **insufficient** — `AGENTS.md`, `docs/`, and `templates/CLAUDE.md.template` counts are unguarded. Run the doc-surface pass from **ccf-doc-sync-campaign**.
- **Guardrails/hook behavior touched**: add cases to `check-guardrails.sh` in the same commit; an untested block pattern does not exist.

## Edge Cases

| Situation | What to do |
|---|---|
| Suite green locally, CI fails on Windows | PowerShell smoke only runs in CI. Reproduce with `pwsh -File tests/check-setup-smoke.ps1` or read the failing assert label in the Actions log. Caveat (as of 2026-07-11): on main the harness itself crashes at startup (`$Home`/`$args` bug); the fix (`e052200`) is stranded off-main — see ccf-failure-archaeology Entry 1. |
| `check-dogfood-drift` fails after an intentional `.claude/` edit | Copy the exact normalized line from the failure output into `config/dogfood-drift-allowlist.txt` (or sync the files). Stale allowlist entries fail too — remove lines for drift that no longer exists. |
| `check-agent-registry` prints `SKIP: python3 not available` | Registry coverage is zero. Install python3 before trusting a green run. |
| New `{{TOKEN}}` fails `check-placeholders` | Add it to `config/placeholders.json` (counts for both scripts) or literally to **both** `setup.sh` and `setup.ps1` — see **ccf-parity-playbook**. Document it in CLAUDE.md per `.claude/rules/templates.md`. |
| Smoke fails with a wall of output | The runner dumps the first ~120 lines of the failing case's captured `$name.out`. Re-run just that case by replaying its `printf` input string against `setup.sh` in a mktemp dir with `HOME` overridden. |
| Need coverage for trackers/notifications/`--reset` | None exists (open/candidate). Add a smoke case per "Adding a check" — do not claim coverage that isn't there. |
| Tempted to "just fix the doc count" | Stop. Counts change only with the files they count; verify with `check-consistency` either way. |

## Related Skills

- **ccf-doc-sync-campaign** — which count/table lives in which doc surface; use when the suite is green but docs may still drift (AGENTS.md/docs/ are unguarded here).
- **ccf-parity-playbook** — bash↔PowerShell mirroring when `check-placeholders` or the PS smoke fails.
- **ccf-dogfood-and-drift** — the model behind `check-dogfood-drift` and allowlist judgment calls.
- **ccf-change-control** — when in the workflow the gate runs (session end, `/improve`, PR).
- **ccf-release-and-install** — setup.sh/ps1 anatomy when a smoke assert points inside the installer.
- **ccf-debugging-playbook** — symptom-first triage when a check is red and the cause isn't obvious.

## Provenance and maintenance

Re-verify each volatile fact before relying on it:

- Check count and discovery glob: `ls tests/check-*.sh | wc -l` (expect 8) and `grep -n 'name "check-\*.sh"' tests/run-all.sh`
- Pass line shape: `bash tests/run-all.sh | tail -1` → `RESULT: ALL TESTS PASSED (8 of 8)`
- Per-check assertion counts: `for t in agent-registry consistency global-skill guardrails placeholders templates; do bash tests/check-$t.sh | grep 'Results:'; done` (234/12/6/55/47/109 as of 2026-07-11); smoke: `bash tests/check-setup-smoke.sh | grep 'Results:'` (80)
- Unique placeholder total and JSON-only tokens: `bash tests/check-placeholders.sh | grep Found` (47); JSON-only list: `for p in $(grep -roh '{{[A-Z_]*}}' templates/ skills/ | sort -u | sed 's/[{}]//g'); do grep -q "{{${p}}}" setup.sh || echo "$p"; done | wc -l` (26)
- python3 silent skip: `grep -n "SKIP: python3" tests/check-agent-registry.sh`; setup.sh hard requirement: `grep -n "python3 is required" setup.sh`
- CI wiring (bash-n gate, run-all, PS smoke): `grep -n "run:" .github/workflows/framework-tests.yml`
- Invalid CCF_* branches count: `grep -c "invalid CCF_" setup.sh` (8)
- Smoke never exercises trackers/notifications/--reset: `grep -n "run_setup_case\|--reset" tests/check-setup-smoke.sh`

Re-verify this skill whenever a commit touches `tests/`, `setup.sh`, `setup.ps1`, `config/placeholders.json`, `config/agents.json`, `config/dogfood-drift-allowlist.txt`, or `.github/workflows/framework-tests.yml` — and immediately if `run-all.sh` reports a total other than 8.
