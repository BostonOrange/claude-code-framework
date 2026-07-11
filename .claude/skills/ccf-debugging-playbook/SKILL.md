---
name: ccf-debugging-playbook
description: Load when something in claude-code-framework is FAILING and you need to find the root cause — a tests/check-*.sh test went red (dogfood-drift, consistency, agent-registry, placeholders, guardrails, setup-smoke), the suite is green locally but CI is red (or vice versa), an installed project has leftover {{PLACEHOLDER}} tokens or is silently half-configured, or a hook is misfiring or never firing. Provides a symptom-to-cause triage table and discriminating experiments that tell look-alike failures apart. NOT for fixing doc counts once diagnosed (ccf-doc-sync-campaign) or for learning what each test gates in general (ccf-testing-and-qa).
last_updated: 2026-07-11
tested_with: claude-fable-5
stability: experimental
scope: preset
---

# CCF Debugging Playbook

Symptom → root cause triage for this repo's real failure modes. Every command below was verified against the repo as of 2026-07-11. Line numbers drift — re-verify via Provenance before trusting them.

## Usage

Load this when something is broken and you don't yet know why: a red test in `tests/`, CI/local disagreement, a broken install in a target project, or a misbehaving hook. Once diagnosed, switch to the sibling that owns the fix (named per row below). NOT for "am I done?" gating (ccf-testing-and-qa), doc-count repair (ccf-doc-sync-campaign), or setup-script feature work (ccf-parity-playbook).

## Process

1. **Reproduce narrowly.** Run the single failing check: `bash tests/check-<name>.sh`. Every check prints per-item PASS/FAIL detail — read it.
2. **Classify via the triage table.** If two causes fit, run the discriminating experiment in the topic sections.
3. **Fix at the root, together.** Never hand-edit a count, allowlist line, or doc entry in isolation — change it together with the files it describes.
4. **Rerun the full gate**: `bash tests/run-all.sh` (8 bash checks; the PowerShell smoke is NOT in it — see "Local green, CI red").

## Triage Table

| Symptom | First check | Likely cause | Fix / owning skill |
|---|---|---|---|
| `check-dogfood-drift`: "Unexpected .claude/template drift" | Did you (or a parallel session) add/edit anything under `.claude/agents`, `hooks`, `skills`, `settings.local.json`, or `statusline`? | Real drift with no line in `config/dogfood-drift-allowlist.txt` (format = the exact `diff` output line, e.g. `Only in .claude/skills: <name>`) | Sync the file with `templates/`/`skills/`, or add the exact printed line with justification — ccf-dogfood-and-drift |
| `check-dogfood-drift`: "Stale allowlist entries" | Was a `.claude/` file removed or synced back to its template? | Allowlist line describes drift that no longer exists | Delete the stale line — ccf-dogfood-and-drift |
| `check-consistency` FAILED | The FAIL line names actual vs documented count and file (`setup.sh` or `README.md`) | Something was added/removed without updating the summary phrases (`N workflow skills`, `N AI agents`, …), or a count was hand-edited | Update files + counts together across all surfaces — ccf-doc-sync-campaign |
| `check-consistency` shows `documented="?"` | Was a summary line reworded? | The check greps exact phrases; rewording breaks extraction even if the number is right | Restore the phrase or extend the grep in `tests/check-consistency.sh` |
| `check-agent-registry` FAILED | Which of its 3 sub-checks failed | `config/agents.json` out of lockstep with `templates/agents/*.md` frontmatter, or agent name absent from README.md / `templates/CLAUDE.md.template` / `docs/teams.md` / `docs/agents-commands-rules.md` | Update registry + frontmatter + all four docs together — ccf-doc-sync-campaign |
| `check-placeholders` FAILED | The FAIL line says which script lacks the token | New `{{TOKEN}}` has no replacement in `setup.sh`, `setup.ps1`, or `config/placeholders.json` (JSON counts as present for both) | Add to BOTH scripts or to `placeholders.json` — ccf-parity-playbook |
| Setup smoke FAILED | The captured tmp-dir output the test prints on failure | Real setup.sh regression OR a harness bug | Run setup manually in a throwaway dir (below) |
| Suite green locally, CI red (or vice versa) | `command -v python3`; `git --version`; `git config --get commit.gpgsign` | python3 absence, git < 2.28, host signing config, or the ps1-only CI job | "Local green, CI red" below |
| Leftover `{{TOKEN}}` in an installed project | Which file family contains it | One of three replacement sites failed | "Tracing leftover placeholders" below |
| Hook misbehaving / never firing | Pipe JSON manually (below); check the event name in settings | Bad stdin parsing, missing jq/python3, or invalid event name | "Hook debugging" below |
| Setup "succeeded" but project half-configured | `grep Traceback` on captured setup output; validate `config/*.json` | The `eval "$(python3 …)"` set -e blind spot | "Silent half-configuration" below |

## Smoke test failed: harness bug or setup bug?

History: the repo has had BOTH. Flagship harness-bug example: `tests/check-setup-smoke.ps1` crashed on read-only automatic variables (`$Home`/`$args`) before any scenario ran, masking real setup.ps1 results; fixed by `e052200` (2026-06-11, merged 2026-07-11) — only a warning comment at `tests/check-setup-smoke.ps1:51` remains. Full story: ccf-failure-archaeology Entry 1.

The discriminating experiment is always: run setup manually in a throwaway dir (CLAUDE.md "Testing Changes" recipe) and inspect the tree yourself:

```bash
mkdir -p /tmp/ccf-probe && cd /tmp/ccf-probe && git init
CCF_PROJECT_TYPE=nodejs CCF_TRACKER=none CCF_CICD=none CCF_NOTIFICATION=none \
CCF_DESIGN_SYSTEM=none CCF_BASE_BRANCH=main CCF_PROJECT_SHORT_NAME=probe \
bash <repo>/setup.sh --non-interactive
grep -rn "{{[A-Z_]*}}" .claude/ CLAUDE.md
```

If the manual run is clean but the test fails, suspect the harness (assertion patterns, stdin `printf` answer sequences at `tests/check-setup-smoke.sh:142` etc.). If the manual run is dirty, it's a real setup bug.

## Local green, CI red (and the reverse)

Check these discriminators in order (CI definition: `.github/workflows/framework-tests.yml` — a bash job on ubuntu-latest running `bash -n` then `tests/run-all.sh`, plus a separate `pwsh ./tests/check-setup-smoke.ps1` job on windows-latest):

1. **python3 present?** `setup.sh` hard-requires it (clear error), but two checks degrade without it: `check-agent-registry.sh` prints `SKIP` and **exits 0** (silently green); `check-placeholders.sh` loses its `placeholders.json` backing and can report **spurious FAILs** for JSON-backed tokens.
2. **PowerShell path.** The ps1 smoke runs ONLY in CI — `run-all.sh` collects bash `check-*.sh` only. A setup.ps1 or ps1-harness breakage is invisible locally unless you run `pwsh ./tests/check-setup-smoke.ps1` yourself. See the e052200 history above.
3. **Host git config.** On main (as of 2026-07-11), the dry-run smoke scenario runs `git init -b old` (`tests/check-setup-smoke.sh:194` — requires git ≥ 2.28) and commits WITHOUT isolating `HOME`, so a host with global `commit.gpgsign=true` can fail/hang locally while CI stays green. Unmerged commit `199417f` hardens this (isolated-HOME `git init`, `git symbolic-ref HEAD`, `commit.gpgsign false`).
4. **macOS vs Linux sed.** `setup.sh` routes in-place edits through `sed_inplace()` (`setup.sh:41`); an edit that bypasses it breaks on exactly one OS.

## Tracing leftover {{PLACEHOLDER}} in an installed project

There are three distinct replacement sites in `setup.sh`; identify the file family first:

| Leftover token lives in | Replacement site | Failure mode to check |
|---|---|---|
| `.claude/{skills,agents,commands,rules,hooks}/**/*.md` or `*.sh` | Bulk python block (`REPLACE_ALL_EOF`, `setup.sh:945`), driven by `config/placeholders.json` | Token missing from `placeholders.json`, or its `env` var never exported before the block. Note: the bulk pass ONLY rewrites `.md`/`.sh` files — tokens in any other extension are never replaced |
| `.claude/settings.local.json` | One-off `sed_inplace "s|{{DEFAULT_MODEL}}|…|g" … 2>/dev/null \|\| true` at `setup.sh:989` | **Silent-failure site**: stderr discarded and exit forced true, so a sed failure leaves the token with no error |
| `CLAUDE.md` | `sed_inplace` at `setup.sh:1022` (BASE_BRANCH, PROJECT_SHORT_NAME) + `CLAUDE_MD_EOF` python block (~`setup.sh:1030`) | Token missing from that block's export list |

Then verify the same token in `setup.ps1` (parity — see ccf-parity-playbook), and add a `tests/check-setup-smoke.sh` assertion if the family wasn't covered. Expected exceptions: the smoke test deliberately ignores meta-reference `{{…}}` examples in `.claude/agents/framework-improver.md` and `.claude/skills/improve/SKILL.md`.

## Hook debugging

Only `guardrails.sh` has unit tests (`tests/check-guardrails.sh`). Test any hook manually by replicating Claude Code's stdin JSON, the same pattern the test uses:

```bash
printf '%s' '{"tool_input":{"command":"git push --force origin main"}}' \
  | bash templates/hooks/guardrails.sh; echo "exit=$?"      # expect 1 (soft block)
printf '%s' '{"tool_input":{"file_path":".claude/skills/develop/SKILL.md"}}' \
  | bash templates/hooks/post-edit-sync.sh                   # expect doc-sync suggestions
```

Exit-code contract: 0 = allow, 1 = soft block (ask user), 2 = hard block. Hooks parse stdin via `read_tool_input_field` in `templates/hooks/_lib.sh` (jq, falling back to python3); with neither installed it returns 2 and guardrails soft-blocks every command with "GUARDRAILS INACTIVE".

**Hook wired but never fires:** check the event name. Claude Code silently rejects invalid event names — `SessionStop` is invalid; the valid name is `SessionEnd` (recorded at `.claude/hooks/post-coding-review.sh:5`; full valid-event list is owned by `docs/troubleshooting.md` and `docs/contributing.md` — don't duplicate it here).

## Silent half-configuration

`setup.sh` runs under `set -e` and loads `config/*.json` through `CONFIG_VARS=$(python3 <<EOF …) || exit`-guarded blocks (design systems, trackers, project types, notifications). **Since 2026-07-11 a python3 failure inside these loaders aborts setup with `ERROR: failed to load config/<file>`** instead of the historical silent-empty-variable behavior (the substitution used to be `eval "$(python3 …)"`, whose failure yielded `eval ""` and set -e never fired). If an installed project is half-configured on a current checkout, first confirm the guard is present (`grep -n 'failed to load config' setup.sh` → 4 hits); if it is, the cause is elsewhere (e.g. a missing export before a python3 heredoc). Doctor command:

```bash
for f in config/*.json; do python3 -c "import json,sys;json.load(open(sys.argv[1]))" "$f" && echo "OK $f"; done
```

Also rerun setup capturing all output and grep it for `Traceback` — exactly what `assert_no_traceback` in `tests/check-setup-smoke.sh` automates.

## Edge Cases

| Situation | What to do |
|---|---|
| Drift check names a `.claude/` path you never touched | A parallel session added it — `git log --oneline -- <path>` and `git status` before assuming your change caused it |
| `check-agent-registry` green on a machine without python3 | It SKIPped (exit 0) — treat that green as unproven; re-run where python3 exists |
| You edited `setup.ps1` and the bash suite is green | Proves almost nothing about ps1 — only `check-placeholders.sh` even greps it; walk ccf-parity-playbook and run the ps1 smoke under pwsh |
| `grep -rn "{{"` in an installed project hits framework-improver.md or improve/SKILL.md | Expected meta-references — the smoke test excludes exactly these two files |
| Tempted to fix a red check by editing the check/allowlist | Routing around the gate — legitimate only with justification per ccf-change-control; default fix is syncing the counted/compared files |
| 199417f / e052200 cited as "the fix" but the symptom is back | Both merged 2026-07-11 (ccf-failure-archaeology Entry 8) — if the same symptom reappears, it is a regression or a new cause; diagnose fresh, don't re-apply old fixes |

## Related Skills

- **ccf-dogfood-and-drift** — once drift is diagnosed: allowlist mechanics and add/modify/remove runbooks.
- **ccf-doc-sync-campaign** — the full doc-surface matrix when consistency/registry checks fail.
- **ccf-parity-playbook** — any setup.sh↔setup.ps1 divergence or placeholder parity fix.
- **ccf-testing-and-qa** — what each check gates and misses in general; extending the suite.
- **ccf-build-and-env** — prerequisites and doctor commands when a machine can't even run the suite.
- **ccf-release-and-install** — setup script anatomy, flags, and rollback when debugging a target-repo install.
- **ccf-change-control** — whether a gate-touching fix (allowlist edit, check edit) is legitimate.

## Provenance and maintenance

| Fact | Re-verify with |
|---|---|
| Suite = 8 bash checks; ps1 smoke CI-only | `ls tests/check-*.sh \| wc -l; grep -n pwsh .github/workflows/framework-tests.yml` |
| DEFAULT_MODEL silent sed site (line 989) | `grep -n 'DEFAULT_MODEL.*\|\| true' setup.sh` |
| eval/python3 blind-spot sites (412/749/793/837) | `grep -n 'eval "\$(python3' setup.sh` |
| Bulk replacement block (line 945); sed_inplace (line 41) | `grep -n 'REPLACE_ALL_EOF\|sed_inplace()' setup.sh` |
| 199417f / e052200 merged (2026-07-11) | `git merge-base --is-ancestor 199417f main && echo merged \|\| echo unmerged` |
| Smoke `git init -b` removed (hermeticity fix) | `grep -n 'git init -b' tests/check-setup-smoke.sh` (expect only the explanatory comment) |
| ps1 harness `$Home` fix present | `grep -n '\$Home' tests/check-setup-smoke.ps1` (expect only the line-51 warning comment) |
| SessionStop-rejected comment location | `grep -rn 'SessionStop' .claude/hooks docs` |
| python3 SKIP in agent-registry check | `grep -n 'SKIP: python3' tests/check-agent-registry.sh` |

Re-verify this skill whenever a commit touches `tests/` or `setup.sh` (line numbers and harness behavior shift). The 199417f/e052200 merge of 2026-07-11 is already reflected; their full history lives in ccf-failure-archaeology.
