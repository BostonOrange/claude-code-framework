---
name: ccf-parity-playbook
description: Load before touching setup.sh or setup.ps1 in claude-code-framework, or when asked "does the PowerShell installer match the bash one?", "why does setup work on macOS but fail on Windows?", "where do I add a new setup prompt / CCF_* variable?", or when a Windows CI setup job fails while bash tests pass. Covers the bash<->PowerShell mirror discipline, the parity checklist to walk for any setup change, sed/python3/PowerShell platform traps that have actually bitten, and the currently-open parity gaps.
last_updated: 2026-07-11
tested_with: claude-fable-5
stability: experimental
scope: preset
---

# CCF Parity Playbook: setup.sh <-> setup.ps1 Mirror Discipline

## Usage

Load this skill when you are about to change `setup.sh` or `setup.ps1`, review a diff that touches either, debug a Windows-only installer failure, or audit whether the two installers still match. **Not** for: what the setup scripts install, their flag semantics, and the CCF_* variable catalog (see **ccf-release-and-install**), or general test anatomy (see **ccf-testing-and-qa**). Doc-count drift is **ccf-doc-sync-campaign**'s territory.

Core law (from `.claude/rules/setup-scripts.md`): the two installers MUST have feature parity — every prompt, placeholder mapping, copy operation, conditional, and summary line in one must exist in the other. There is no shared implementation; parity is maintained by hand and enforced only partially by tests, which is why this playbook exists.

## Process: the parity walk for any setup change

1. **Make the change in `setup.sh` first.** It is the reference implementation (1332 lines vs 1153 in `setup.ps1`, as of 2026-07-11) and the only one the local test suite executes.
2. **Walk the parity checklist** (next section) row by row and mirror each touched row into `setup.ps1`. Match section numbering — both scripts use identical numbered prompt sections `1. Project Type` through `7. Design System` (`setup.sh:138-407`, `setup.ps1:133-356`, as of 2026-07-11).
3. **If you added a prompt, add its `CCF_*` variable to BOTH non-interactive resolvers**: `setup.sh` ~lines 59-136 (`${CCF_X:-default}` plus a validation `case`) and `setup.ps1` ~lines 51-131 (`if ($env:CCF_X) {...} else {default}` plus validation). CLAUDE.md ("Non-Interactive Setup") makes this mandatory. Also register the placeholder in `config/placeholders.json` if templates consume it.
4. **Run the gates**: `bash tests/check-placeholders.sh`, then `bash tests/check-setup-smoke.sh`, then full `bash tests/run-all.sh`.
5. **Exercise `setup.ps1` yourself** — `pwsh -NoProfile -File tests/check-setup-smoke.ps1` if you have pwsh, otherwise a manual `-DryRun` run. Do not rely on run-all or CI here (see "How to verify parity" for why).
6. If your change alters install output or counts, hand off to **ccf-doc-sync-campaign** before calling it done.

## The parity checklist

For any setup change, confirm each surface exists in both scripts:

| Surface | setup.sh location | setup.ps1 location |
|---|---|---|
| Prompt text + numbered section header | `## 1..7` sections, lines 138-407 | `# -- 1..7 --` sections, lines 133-356 |
| `CCF_*` non-interactive resolver entry | lines 59-136 | lines 51-131 |
| Placeholder mapping | python3 heredocs (lines 412, 749, 793, 837, 945) reading `config/*.json` | `ConvertFrom-Json` blocks (lines 359, 716, 738, 768, 783) |
| Copy operation | `cp` loops after line 722 | `Copy-Item` loops after line 616 |
| Conditional logic (skip rules for backend, internal-app extras) | mirrored branches | mirrored branches |
| Summary output line | Summary block, lines 1281-1332 | Summary block, lines 1105-1153 |
| Smoke-test case | `tests/check-setup-smoke.sh` (`run_setup_case`) | `tests/check-setup-smoke.ps1` (`Run-SetupCase`) |

Line numbers are as of 2026-07-11; treat them as anchors, re-grep before relying on them.

## Bash-side portability traps

- **Portable in-place sed.** macOS `sed -i` requires an argument, GNU sed forbids one. `setup.sh:40-47` defines the wrapper — use it, never raw `sed -i`:

  ```bash
  sed_inplace() {
      if [[ "$OSTYPE" == "darwin"* ]]; then
          sed -i '' "$@"
      else
          sed -i "$@"
      fi
  }
  ```

  Note: `.claude/rules/setup-scripts.md` still calls this "`$SED_INPLACE` variable"; the current implementation is the `sed_inplace()` function (as of 2026-07-11). Same intent.
- **Export before python3 heredocs.** The replacement engine is python3 reading `os.environ` (e.g. the bulk pass at `setup.sh:945-982`). Any shell variable a heredoc consumes MUST be `export`ed first — see the export blocks at lines 747 and 931-942. A forgotten export fails *silently*: `os.environ.get(...)` returns the default and the placeholder gets wrong-but-plausible content.
- **The `eval "$(python3 <<EOF)"` blind spot — guarded since 2026-07-11.** The four config loaders are now `CONFIG_VARS=$(python3 …) || { echo "ERROR: failed to load config/<file>…"; exit 1; }; eval "$CONFIG_VARS"`, so a python failure aborts loudly (matching ps1's `$ErrorActionPreference = "Stop"` behavior). History and doctor command: **ccf-debugging-playbook** "Silent half-configuration". Keep the guard when touching these blocks — a bare `eval "$(python3 …)"` reintroduces silent half-configuration under `set -e`.

## PowerShell-side traps (all actually happened)

| Commit | What bit | Lesson |
|---|---|---|
| `42e6a98` (on main) | Windows PowerShell 5.1 read BOM-less `setup.ps1` as ANSI and mis-decoded an em-dash in the pre-commit sentinel string as a smart-quote, closing the string early — parser errors before a single line ran. Fixed by adding a UTF-8 BOM (1-line diff). | `setup.ps1` MUST keep its UTF-8 BOM (verify: `head -c 3 setup.ps1 \| xxd` → `efbb bf`). Any tool that rewrites the file BOM-less re-breaks WPS 5.1. Beware em-dashes in PS string literals generally. |
| `e052200` (2026-06-11, merged 2026-07-11 — full story: ccf-failure-archaeology Entry 1) | The PS smoke harness itself used `$Home`/`$home`/`$args` as a parameter and locals — read-only automatic variables — and crashed before any scenario ran, so the CI job "ran" while gating nothing. | Never name PS parameters/locals after automatic variables (`$Home`, `$args`, `$input`, ...). A test harness that crashes at startup is indistinguishable from a red build people learn to ignore — check the harness first. |
| `0fe93ea` (2026-06-11, merged 2026-07-11 — same Entry 1) | Real `setup.ps1` bugs surfaced only after the harness was repaired: (a) `ConvertFrom-Json` rejects npm `package-lock.json`'s empty-string root key — needs `-AsHashtable` on PS 6+; (b) the branch-rename confirmation was asked far later than in `setup.sh`, so scripted/dry-run input reached the wrong prompt. | A broken harness hides an entire class of bugs; expect a bug wave right after fixing one. |
| Latent (no incident yet) | Null-vs-empty divergence in the placeholder map builders: `setup.sh` python uses `os.environ.get(env, default)` — an exported-but-empty var wins with `''` (`setup.sh:959-961`); `setup.ps1` falls back to the `config/placeholders.json` default whenever the looked-up variable is `$null` (`setup.ps1:787-798`). A resolver path leaving a variable empty (`''` in bash, unassigned in PS) yields different installed content per platform. Currently unreachable — both resolvers assign every variable — but any new resolver branch can arm it. | When adding resolver variables, always assign a concrete string on every path in both scripts. |

## Known open parity gaps (as of 2026-07-11, each verified in the scripts)

Candidates to fix, not documentation of intent. (A former gap — branch-rename prompt ordering — was closed when `0fe93ea` merged on 2026-07-11: ps1 now asks right after the base-branch prompt, `setup.ps1:296-325`, mirroring `setup.sh:307`.)

1. **`-DryRun` has no early-exit summary in `setup.ps1`.** `setup.sh --dry-run` prints a `[DRY-RUN]` plan and `exit 0` (lines 673-716). `setup.ps1` threads `if (-not $DryRun)` and `[DRY-RUN] Would copy` messages through the whole script and ends by printing "Setup Complete!" even in dry-run — its only `exit 0`s are `-Help` and `-Reset`.

(Three former gaps closed 2026-07-11 in one parity commit: `-Help` now documents `-NonInteractive`; reset prints the "To fully clean up…" hint; the summary prints the conditional `CLAUDE.md — project instructions (customize!)` line. The same commit also mirrored setup.sh's new non-interactive tracker-detail validation and `.env` family gitignore handling into ps1.)

If you close one, mirror the fix, re-verify this list, and update this skill.

## How to verify parity

| Tool | What it checks | Blind spot |
|---|---|---|
| `bash tests/check-placeholders.sh` | Static: every `{{PLACEHOLDER}}` in `templates/` and `skills/` has a replacement in BOTH scripts (entries in `config/placeholders.json` count as present for both). | Only placeholders — nothing about prompts, ordering, output, or behavior. |
| `bash tests/check-setup-smoke.sh` | Behavioral, **bash only**: runs `setup.sh` in throwaway repos with isolated HOME (interactive-scripted, dry-run, non-interactive, missing-CCF_PROJECT_TYPE cases). | Never executes `setup.ps1`. |
| `tests/check-setup-smoke.ps1` | Behavioral for `setup.ps1`, mirror scenarios. | **TRAP:** `tests/run-all.sh` collects `check-*.sh` only (line 19) — the `.ps1` harness is CI-only (`.github/workflows/framework-tests.yml`, `powershell` job on windows-latest). A green local `run-all.sh` proves nothing about `setup.ps1`. (The harness startup crash that once disabled this gate was fixed by `e052200`, merged 2026-07-11 — history: ccf-failure-archaeology Entry 1.) |

## Edge Cases

| Situation | What to do |
|---|---|
| No pwsh available locally, change touches setup.ps1 | State it untested on PowerShell in the PR and watch the CI windows job (its harness has been sound since the 2026-07-11 merge; if it crashes at startup rather than failing an assert, suspect the harness per Entry 1's lesson). |
| Change only makes sense on one platform (e.g. `chmod +x`) | Mirror the *intent*: ps1 skips chmod but must still copy hooks; leave a comment in both scripts pointing at the counterpart. |
| Placeholder check passes but installed files differ per platform | Suspect the null-vs-empty divergence or a missing export before a python3 heredoc — both are invisible to the static check. |
| Corrupt or hand-edited `config/*.json` | Both scripts now fail loudly (guarded loaders in bash since 2026-07-11; `$ErrorActionPreference = "Stop"` in ps1). If bash instead continues silently, the loader guard was removed — restore it. |
| Editing `tests/check-setup-smoke.ps1` | Grep your diff for `$Home`, `$home`, `$args`, `$input` as parameter/local names before committing. |
| Tempted to fix a gap in only one script | Don't. Fixing sh-only widens the gap; a parity fix touches both scripts in one commit. |

## Related Skills

- **ccf-release-and-install** — what the installers actually do, flag semantics, CCF_* interface end-to-end; switch there for install/rollback questions.
- **ccf-domain-reference** — the CCF_* variable and `config/*.json` catalog.
- **ccf-testing-and-qa** — full anatomy of `tests/*.sh` and what each gates/misses.
- **ccf-doc-sync-campaign** — when your setup change alters counts or summary lines that appear in docs.
- **ccf-change-control** — merge gates and session-end workflow after any framework edit.
- **ccf-debugging-playbook** — symptom-first triage when an installer misbehaves and you don't yet know it's a parity issue.

## Provenance and maintenance

Re-verify before trusting; all facts dated 2026-07-11:

- Parity contract text: `cat .claude/rules/setup-scripts.md`
- Line counts / anchors: `wc -l setup.sh setup.ps1`; prompt sections: `grep -n '── [0-9]\|-- [0-9]' setup.sh setup.ps1`
- `sed_inplace` definition: `grep -n -A6 'sed_inplace()' setup.sh`
- loader guards present: `grep -c 'failed to load config' setup.sh` (expect 4)
- BOM present: `head -c 3 setup.ps1 | xxd` (expect `efbb bf`)
- Commit history: `git show --stat 42e6a98 e052200 0fe93ea`; merge status: `git branch --contains e052200` (merged 2026-07-11; expect the current integration branch listed)
- Harness fix present: `grep -n '\$Home\b\|\$args\b' tests/check-setup-smoke.ps1` (expect only the line-51 warning comment)
- Gap 1: `grep -n 'exit 0' setup.ps1` (dry-run early exit added when a third appears); gap 2: `sed -n '11,16p' setup.ps1`; gap 3: `grep -n 'fully clean up' setup.sh setup.ps1`; gap 4: `grep -n 'customize!' setup.sh setup.ps1`; closed rename-order gap: `grep -n 'Rename to' setup.sh setup.ps1` (both ~line 300)
- run-all glob trap: `grep -n 'check-\*.sh' tests/run-all.sh`; CI wiring: `cat .github/workflows/framework-tests.yml`

**Re-verify this skill whenever**: `setup.sh`/`setup.ps1`/`tests/check-setup-smoke.*` change (line-number anchors and the gaps list shift), or a new prompt/CCF_* variable is added. The 2026-07-11 assessment-branch merge is already reflected here.
