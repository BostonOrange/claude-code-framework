---
name: ccf-build-and-env
description: Load when setting up a dev environment for the claude-code-framework repo itself — fresh clone, new machine, new agent session — or when asked "how do I build/run this repo?", "what tools do I need?", "why does the test suite pass on my machine but fail in CI (or vice versa)?", or "can I run setup.sh here to try it?". Covers prerequisites, the clone-to-verified sequence, doctor commands, and environment traps (python3 silent-skip, macOS sha256sum, throwaway-dir setup testing). NOT for what the tests gate (ccf-testing-and-qa) or setup.sh internals (ccf-release-and-install).
last_updated: 2026-07-11
tested_with: claude-fable-5
stability: experimental
scope: preset
---

# CCF Build & Environment

## Usage

Load this skill when you need a working development environment for **this repo** (the framework itself): first clone, new machine, or proving your environment is healthy before/after changes. Also load it when a "works here, fails there" symptom smells environmental (missing python3, missing pwsh, macOS-vs-Linux tooling).

Do NOT use this skill for:
- What each test gates or how to extend the suite → **ccf-testing-and-qa**
- setup.sh/setup.ps1 flags, CCF_* variables, install/rollback into target projects → **ccf-release-and-install**
- Why `.claude/` differs from `templates/` and the drift allowlist → **ccf-dogfood-and-drift**
- A failing check's design intent → **ccf-architecture-contract**

## Process: clone to verified

There is no build step. "Environment works" means the test suite passes.

```bash
git clone https://github.com/BostonOrange/claude-code-framework.git
cd claude-code-framework
python3 --version   # MUST print a version — see Trap 2 before trusting a green suite without it
bash tests/run-all.sh
```

Expected tail of step 4 on a clean clone (verified 2026-07-11):

```
RESULT: ALL TESTS PASSED (8 of 8)
```

Anything else: match the failing check name against **ccf-testing-and-qa** (what it gates) and **ccf-debugging-playbook** (triage). One known-benign case: `check-dogfood-drift` fails whenever you have *untracked* files under `.claude/` (see Trap 3).

## What this repo is

claude-code-framework is markdown + bash + PowerShell + JSON. There is nothing to compile, no `npm install`, no virtualenv, no lockfile to restore for framework work. The vendored app template `templates/internal-nextjs-business-app/` contains a `package-lock.json`, but it is payload that setup.sh copies into target projects — you never install its dependencies to develop the framework (the only `npm install` string in setup.sh is documentation text it *generates* for target projects, line ~593). Full vocabulary/object model: **ccf-domain-reference**.

## Prerequisites

| Tool | Needed for | Check | If absent |
|---|---|---|---|
| bash 3.2+ | setup.sh, all tests, hooks | `bash --version` | Nothing works. macOS's stock 3.2.57 is sufficient — setup.sh uses `#!/bin/bash`, a grep for bash-4-only features (`declare -A`, `mapfile`, `${var,,}`) finds none, and the full suite passes under 3.2.57 (verified 2026-07-11) |
| git | clone, tests (`git hash-object`, smoke tests `git init`), guardrails | `git --version` | Tests and setup fail |
| python3 | setup.sh (hard requirement), JSON parsing in 2 tests | `python3 --version` | setup.sh exits with `ERROR: python3 is required`; one test silently skips, two fail loudly — see Trap 2 |
| pwsh (optional) | `tests/check-setup-smoke.ps1` locally | `pwsh -v` | The bash suite still passes — it never runs `.ps1` files. Windows CI covers it (see Trap 6) |
| shellcheck (optional) | Ad-hoc linting only | `command -v shellcheck` | Nothing — not enforced anywhere. CI runs only `bash -n` syntax checks + the suite. The `# shellcheck` comments in hooks are directives for humans who run it by hand |
| jq, sqlite3, curl (optional) | Only `templates/hooks/codebase-index.sh` at *target-project* runtime | `command -v jq sqlite3 curl` | Framework tests never invoke that hook; you only need these to exercise it manually (Trap 4) |

## Doctor table

Run these when you doubt the environment; all healthy outputs verified 2026-07-11.

| Command | Healthy output |
|---|---|
| `python3 --version` | Any `Python 3.x` (3.11.6 on the reference machine) |
| `bash tests/run-all.sh 2>&1 \| tail -3` | `RESULT: ALL TESTS PASSED (8 of 8)` on a clean tree |
| `git remote -v` | `origin https://github.com/BostonOrange/claude-code-framework.git` (fetch + push) |
| `pwsh -v` | `PowerShell 7.x` — only if you want to run the PS smoke test locally |
| `git status --short` | Empty before starting work; untracked `.claude/**` files predict a dogfood-drift failure (Trap 3) |

## Traps

**1. Never run setup.sh inside this repo.** CLAUDE.md states it: this repo is the framework, not a target project. Running it here would overwrite the curated dogfood `.claude/` with generated output. To test installer changes, use the throwaway-dir recipe from CLAUDE.md's "Testing Changes" section:

```bash
FRAMEWORK_DIR="$(pwd)"                      # run from the repo root
mkdir /tmp/test-project && cd /tmp/test-project && git init
bash "$FRAMEWORK_DIR/setup.sh"
grep -r "{{" .claude/ CLAUDE.md | grep -v ".git"   # must print nothing
```

`tests/check-setup-smoke.sh` automates this in `mktemp` dirs with an isolated `HOME` — prefer extending it over manual runs (see **ccf-testing-and-qa**).

**2. python3 absence: one check silently skips, two fail loudly.** Verified behavior (2026-07-11):
- `tests/check-agent-registry.sh` prints `SKIP: python3 not available` and **exits 0** — a green PASS that verified nothing (reproduced by running it with python3 stripped from PATH). This is the one silent, dangerous case.
- `tests/check-placeholders.sh` loses its `config/placeholders.json` backing (`JSON_NAMES` stays empty) and the 26 JSON-only tokens (of 47 unique) **FAIL loudly** — a red placeholders check on a python3-less machine is an environment problem, not a placeholder regression. Detailed mechanics: **ccf-testing-and-qa**, "The python3 reality" (the single home for this fact).
- `tests/check-setup-smoke.sh` fails loudly, because setup.sh itself hard-requires python3 (top of `setup.sh`).

Net: always run `python3 --version` before trusting results, and be suspicious of any environment where check-placeholders/check-setup-smoke fail while check-agent-registry "passes".

**3. Untracked `.claude/` files fail `check-dogfood-drift`.** Adding anything under `.claude/` that is not in `config/dogfood-drift-allowlist.txt` turns the suite red (observed live 2026-07-11: in-progress `.claude/skills/ccf-*` additions produced `Only in .claude/skills: ...` failures while a clean clone of HEAD passed 8/8). This is the check working as designed. Whether editing the allowlist is legitimate for your change: **ccf-dogfood-and-drift** and **ccf-change-control**.

**4. `sha256sum` on macOS.** `templates/hooks/codebase-index.sh` calls `sha256sum` in two places; the file-level call falls back to `git hash-object` first, but the chunk-level call (line ~158) has **no `shasum -a 256` fallback** (as of 2026-07-11). The reference machine (Darwin 25) ships `/sbin/sha256sum`, but older stock macOS does not — check `command -v sha256sum` before exercising this hook on a Mac. The hook also needs `jq`, `sqlite3`, and an embedding provider selected by `CLAUDE_FRAMEWORK_EMBED_PROVIDER` (`voyage` default → needs `VOYAGE_API_KEY`; `openai` → `OPENAI_API_KEY`; `local` → a running ollama). Reference the env-var names only; never put key values in files. None of this affects the framework test suite, which never runs this hook.

**5. `mktemp -d` portability is already solved — copy the pattern.** GNU and BSD mktemp disagree on template syntax; the tests use the portable form `mktemp -d "${TMPDIR:-/tmp}/ccf-<name>.XXXXXX"` (see `tests/check-setup-smoke.sh` and `tests/check-dogfood-drift.sh`). New temp-dir code should copy it verbatim.

**6. A green bash suite proves nothing about setup.ps1 runtime.** `tests/run-all.sh` collects only `check-*.sh`; `tests/check-setup-smoke.ps1` runs only via `pwsh ./tests/check-setup-smoke.ps1` locally or the `windows-latest` job in `.github/workflows/framework-tests.yml`. The bash suite covers setup.ps1 only via textual placeholder-parity greps. Before merging setup-script changes without local pwsh, wait for Windows CI. Mirror discipline details: **ccf-parity-playbook**.

## Editor/session setup

- **Claude Code**: nothing to configure. The repo's own `.claude/` (curated dogfood subset — see **ccf-dogfood-and-drift**) plus `CLAUDE.md` and `.claude/rules/*.md` auto-load per session.
- **Codex**: a mirror exists as `AGENTS.md` plus `.codex/` (`agents/`, `hooks/`, `config.toml`, `hooks.json`) — verified present 2026-07-11. Keeping it in sync with `.claude/` is part of the doc-surface problem owned by **ccf-doc-sync-campaign**.

## Edge Cases

| Situation | What to do |
|---|---|
| Suite fails only on `check-dogfood-drift`, `git status` shows untracked `.claude/**` | Expected (Trap 3). Finish the change properly per **ccf-dogfood-and-drift**; don't "fix" the environment |
| No python3 on the machine | Install it before concluding anything from test results (Trap 2). setup smoke cannot pass without it |
| Need to try setup.sh interactively | Throwaway dir only (Trap 1). Never in this repo, never in a real project you care about without reading **ccf-release-and-install** first |
| `codebase-index.sh` errors on a Mac | Check `command -v sha256sum jq sqlite3` and the embed-provider env vars (Trap 4) |
| Want to test setup.ps1 but no pwsh locally | `brew install --cask powershell` (unverified install path), or rely on the Windows CI job (Trap 6) |
| Windows/Git Bash development | Hooks and tests are written to tolerate it (CRLF guards exist in `tests/check-agent-registry.sh`), but the reference environment is macOS/Linux; treat Windows-local results as secondary to CI |

## Related Skills

- **ccf-testing-and-qa** — what each of the 8 checks actually gates and misses; extending the suite
- **ccf-release-and-install** — setup.sh/setup.ps1 anatomy, `--dry-run`/`--reset`/`--non-interactive`, CCF_* interface
- **ccf-dogfood-and-drift** — `.claude/` vs `templates/` model and drift allowlist mechanics
- **ccf-parity-playbook** — bash↔PowerShell mirror checklist before touching setup scripts
- **ccf-debugging-playbook** — symptom→triage when a doctor command's output is unhealthy
- **ccf-domain-reference** — vocabulary: skills/agents/rules/hooks/placeholders/project types

## Provenance and maintenance

Every claim above was verified against the working tree on 2026-07-11. Re-verification one-liners:

- Suite count & result: `bash tests/run-all.sh 2>&1 | tail -3` (expect `ALL TESTS PASSED (8 of 8)` on a clean tree)
- Test roster: `ls tests/check-*.sh | wc -l` (8, plus `check-setup-smoke.ps1` outside the bash runner)
- python3 hard-required by setup.sh: `grep -n "python3 is required" setup.sh`
- Silent-skip behaviors: `grep -n "SKIP: python3" tests/check-agent-registry.sh` and `grep -n "command -v python3" tests/check-placeholders.sh`
- JSON-only tokens (Trap 2's loud-failure claim): `grep -roh '{{[A-Z_]*}}' templates/ skills/ | sort -u | wc -l` (47 unique); 26 of them appear ONLY in `config/placeholders.json`, not literally in either setup script — count with the one-liner in ccf-testing-and-qa's Provenance
- sha256sum no-fallback: `grep -n "sha256sum" templates/hooks/codebase-index.sh` (fallback exists only on the `git hash-object` line)
- CI shape: `cat .github/workflows/framework-tests.yml` (ubuntu: `bash -n` + suite; windows: pwsh smoke)
- Codex mirror: `ls .codex/ AGENTS.md`
- No bash-4 features in setup.sh: `grep -nE 'declare -A|mapfile|readarray|\$\{[a-zA-Z_]+(\^\^|,,)' setup.sh` (expect no output)

**Re-verify this skill when:** a new `tests/check-*.sh` lands or one is removed (the "8 of 8" and roster claims), setup.sh's dependency preamble changes, `codebase-index.sh` gains a `shasum` fallback or new providers, or the CI workflow adds jobs (e.g., shellcheck enforcement would obsolete a prerequisites row).
