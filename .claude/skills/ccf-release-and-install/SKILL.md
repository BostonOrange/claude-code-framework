---
name: ccf-release-and-install
description: Load when installing or uninstalling the claude-code-framework in a target repo, or answering how installation works — driving setup.sh / setup.ps1, choosing flags (--dry-run, --reset, --non-interactive / -DryRun, -Reset, -NonInteractive), setting CCF_* env vars, using the global /install-framework skill, or explaining what files land where (project vs ~/.claude user level). Also load for rollback ("undo the install", re-running setup over an existing install), Windows/PowerShell installer differences, and "what version of the framework is installed?" questions.
last_updated: 2026-07-11
tested_with: claude-fable-5
stability: experimental
scope: preset
---

# Release and Install: How the Framework Gets Into (and Out of) a Target Repo

There is no package registry, build artifact, or version pinning — "releasing" the framework means running `setup.sh` (bash, requires `python3`) or `setup.ps1` (PowerShell, no python dependency) from inside a target repo; the installer reads templates from the framework clone and substitutes `{{PLACEHOLDER}}` values from `config/*.json`. **Never run the installers inside the framework repo itself** (CLAUDE.md: "Do not run setup.sh here"); test in a throwaway dir per CLAUDE.md's "Testing Changes".

## Usage

Load this skill to **run or debug an installation**: choosing an install path, the exact flag/CCF_* interface, what files the installers write, uninstalling, or the Windows parity traps that affect *operators*.

Do NOT load it for:
- **Editing** setup.sh/setup.ps1 → **ccf-parity-playbook** (mirror discipline, sed/python3/PS traps)
- Placeholder/vocabulary/config-catalog questions → **ccf-domain-reference**
- The setup smoke test and merge gates → **ccf-testing-and-qa** and **ccf-change-control**
- Why this repo's own `.claude/` differs from `templates/` → **ccf-dogfood-and-drift**

## Process: standard install (non-interactive, recommended for agent sessions)

`$FRAMEWORK_CLONE` below = path to a clone of claude-code-framework.

1. **Preflight** (in the target repo): `git rev-parse --git-dir` (should be a git repo; not fatal but branch/pre-commit steps are skipped otherwise) and, on the bash path, `command -v python3` — setup.sh exits 1 immediately without it.
2. **Preview without prompts** — combine both flags; `--dry-run` alone still runs the interactive prompts:
   ```bash
   CCF_PROJECT_TYPE=nodejs bash "$FRAMEWORK_CLONE/setup.sh" --non-interactive --dry-run
   ```
   Bash prints `[DRY-RUN]` lines plus a config summary and exits 0 **before any write**.
3. **Install**:
   ```bash
   CCF_PROJECT_TYPE=nodejs CCF_TRACKER=github CCF_CICD=github-actions \
   CCF_BASE_BRANCH=main CCF_PROJECT_SHORT_NAME=myapp CCF_DESIGN_SYSTEM=none \
   bash "$FRAMEWORK_CLONE/setup.sh" --non-interactive
   ```
4. **Verify** — no unreplaced placeholders may remain:
   ```bash
   grep -R "{{[A-Z_][A-Z_]*}}" CLAUDE.md .claude 2>/dev/null | grep -v ".claude/state" | grep -v ".claude/skills/improve/SKILL.md"
   ```
   Any output = failed install; do not report success (this is the same check `/install-framework` mandates).
5. **Rollback if needed** — see Rollback below.

Interactive mode (`bash setup.sh` with no flags) asks, in order: project type (1–9) → *(internal-nextjs-app only:* hosting 1–4, storage 1–3, postgres 1–3*)* → tracker (1–5, plus ADO org/project, Jira domain/key, or Linear team ID) → CI/CD (1–4) → base branch [main] **with an offer to rename the current branch and push/flip the remote default — the only git-mutating step in setup** → notification (1–4) → short name → design system (1–4, react/nodejs only).

## CCF_* variable table (from the resolver in setup.sh; setup.ps1 mirrors it)

This table is the **single canonical home** for CCF_* values/defaults/conditionals — sibling skills (ccf-domain-reference, ccf-parity-playbook) point here instead of restating it. Invalid values hard-error (exit 1). Non-interactive mode **never renames git branches** — `CCF_BASE_BRANCH` only feeds placeholder substitution.

| Variable | Required | Valid values | Default |
|---|---|---|---|
| `CCF_PROJECT_TYPE` | **yes** | salesforce, nodejs, python, go, java, react, internal-nextjs-app, rails, generic | — (error) |
| `CCF_TRACKER` | no | ado, jira, linear, github, none | none |
| `CCF_ADO_ORG`, `CCF_ADO_PROJECT` | no | free text (tracker=ado) | "" |
| `CCF_JIRA_DOMAIN`, `CCF_JIRA_PROJECT` | no | free text (tracker=jira) | "" |
| `CCF_LINEAR_TEAM` | no | free text (tracker=linear) | "" |
| `CCF_CICD` | no | github-actions, gitlab-ci, circleci, none | none |
| `CCF_BASE_BRANCH` | no | any | main |
| `CCF_NOTIFICATION` | no | slack, teams, discord, none | none |
| `CCF_PROJECT_SHORT_NAME` | no | any | target dir basename |
| `CCF_DESIGN_SYSTEM` | no | untitled-ui, shadcn, custom, none — **only consulted for react/nodejs**; internal-nextjs-app forced `none`, all other types forced `_backend` | none |
| `CCF_HOSTING_TARGET` | no (internal-nextjs-app only) | local, vercel, azure-container-apps, other | local |
| `CCF_STORAGE_PROVIDER` | no (internal-nextjs-app only) | azurite, azure-blob, vercel-blob | azurite |
| `CCF_POSTGRES_PROVIDER` | no (internal-nextjs-app only) | local-docker, database-url, azure-postgres-flexible-server | local-docker |

The tracker-detail vars (`CCF_ADO_*`, `CCF_JIRA_*`, `CCF_LINEAR_TEAM`) are read by both resolvers but are absent from CLAUDE.md's CCF_* list (as of 2026-07-11).

## Flag catalog (both scripts)

| bash | PowerShell | Effect | Parity trap (as of 2026-07-11) |
|---|---|---|---|
| `--dry-run` | `-DryRun` | Preview without writes | **sh**: single early exit after the plan+summary, prints "No files were modified." **ps1**: threads `if (-not $DryRun)` guards through every step but still prints the unconditional `Setup Complete!` banner and "Files created:" list at the end — never parse ps1 output to decide whether files were written; check the filesystem. |
| `--reset` | `-Reset` | Uninstall (see Rollback) | sh additionally prints "To fully clean up, manually remove CLAUDE.md and .env"; ps1 omits that hint. |
| `--non-interactive` | `-NonInteractive` | Read CCF_* instead of prompting; never renames branches | Behavior matches; ps1 has no python3 requirement. |
| `--help` / `-h` | `-Help` | Usage text | ps1 help lists only `-DryRun` and `-Reset` — **`-NonInteractive` is omitted from the help text but the switch works**. |

## The three install paths

1. **Interactive** — `cd target && bash "$FRAMEWORK_CLONE/setup.sh"`. Prompt sequence above. Only path that may rename branches (asks first; pushes new branch → flips remote default via `gh` if present → deletes old branch).
2. **Non-interactive** — `--non-interactive` + CCF_* vars. This is what `/install-framework` drives and what scripted tests use.
3. **Global skill** — `bash install-global-skill.sh` (from a framework clone) copies `global-skills/install-framework/` into `~/.claude/skills/install-framework` (rm -rf's any existing copy first). Then `/install-framework` in **any** repo: clones `https://github.com/BostonOrange/claude-code-framework.git --depth 1` to a temp dir, auto-detects project type / base branch / short name, asks minimal questions, maps answers to CCF_*, runs the installer non-interactively, verifies zero `{{…}}` remain, deletes the temp clone. **It installs from GitHub, not your local clone** — to test uncommitted framework changes, run setup.sh from the local clone directly.

## What lands where

Project-level (written into the target repo):

| Target path | Source | Notes |
|---|---|---|
| `.claude/skills/` | `skills/*/` | 27 skills; `_template` excluded |
| `.claude/agents/` | `templates/agents/*.md` | 39 agents |
| `.claude/commands/` | `templates/commands/*.md` | 11 commands |
| `.claude/rules/` | `templates/rules/*.md` | 23 rules, minus conditionals below |
| `.claude/hooks/` | `templates/hooks/*.sh` | 8 files incl. `_lib.sh` shared library; `chmod +x` |
| `.claude/statusline/statusline-command.sh` | `templates/statusline/` | |
| `.claude/settings.local.json` | `templates/settings.local.json` | `{{DEFAULT_MODEL}}` → `sonnet` (hardcoded in both scripts) |
| `.mcp.json` | `templates/mcp.json` | Context7 via `npx @upstash/context7-mcp@1.0.5` |
| `CLAUDE.md` | `templates/CLAUDE.md.template` | **only if absent**; placeholders substituted |
| `.env` | generated | **only if absent**; tracker/notification env-var *names* appended; `.env` and `.claude/state/` added to `.gitignore` |
| `docs/stories/` | created empty | |
| `.github/workflows/` | `workflows/*.yml` (4 `factory-*.yml`) | only when CI/CD = github-actions |
| `.git/hooks/pre-commit` | copy of `.claude/hooks/pre-commit.sh` | skipped if a foreign hook exists (prints chaining instruction); a locally-modified framework hook is preserved (sentinel string check) |

User-level (written **outside** the target repo — a common surprise): `~/.claude/settings.json` (from `templates/settings.json`, only if absent) and `~/.claude/hooks/session-stop.sh` (only if absent).

Conditionals: python/go/java delete `components.md` and `design-system.md` after copy; any project with design system `none` (including react/nodejs answering "none", and internal-nextjs-app always) additionally loses `design-system.md`. **internal-nextjs-app extras**: the whole `templates/internal-nextjs-business-app/` tree is copied into the repo root (excluding `.git`, `.github`, `.next`, `.env.local`, `CLAUDE.md`, `node_modules`, `tsconfig.tsbuildinfo`, `src/generated/prisma`), `package.json`/`package-lock.json` `name` rewritten to a sanitized dir name, plus `.env.example`, `docs/setup.md`, `.claude/internal-app.json` (records hosting/storage/postgres choices), and an "Internal app runtime" block appended to an existing `.env`.

The installers read six of the eight `config/` files (`design-systems`, `trackers`, `project-types`, `notifications`, `placeholders`, `precommit` .json); `agents.json` and `dogfood-drift-allowlist.txt` are test/orchestration inputs only (catalog: ccf-domain-reference).

## Rollback

`--reset` / `-Reset` removes exactly: `.claude/{skills,agents,commands,rules,hooks}`, `.claude/settings.local.json`, `.mcp.json`. It does **NOT** remove: `CLAUDE.md`, `.env`, `.claude/statusline/`, `.claude/state/`, `docs/stories/`, `.github/workflows/`, `.git/hooks/pre-commit`, `.gitignore` edits, anything in `~/.claude/`, or any internal-app files (the copied app tree, `.env.example`, `docs/setup.md`, `.claude/internal-app.json`). For a true rollback in a repo with prior content, prefer git: commit before installing, then `git revert` / `git checkout` — and delete the leftovers above by hand.

**Re-running setup over an existing install** overwrites template-derived files but preserves `CLAUDE.md`, `.env`, user-level files, and a modified `.git/hooks/pre-commit`. On macOS this is a clean in-place overwrite (verified: BSD `cp -r src/ dest` with existing dest copies contents over). On Linux, GNU cp treats the trailing-slash source differently and may nest skill dirs (`.claude/skills/x/x`) — **unverified**; safest cross-platform re-install is `--reset` first.

## Versioning reality

`VERSION` at the repo root contains `1.0.0`, and **nothing reads it** — no reference in setup.sh, setup.ps1, tests/, or README (as of 2026-07-11). No version stamp is written into target repos, and `/install-framework` deletes its temp clone, so "which framework version does this target have?" is answerable only by diffing the target's `.claude/` against framework git history. Releases are effectively git-history-only. Candidate improvement (open, not done): stamp the installing commit hash into the target (e.g. `.claude/state/`) and make something consume VERSION.

## Edge Cases

| Situation | What to do |
|---|---|
| `-DryRun` on Windows printed "Setup Complete!" | Expected (trap above). Verify via filesystem, not the banner. |
| `--dry-run` still prompting | It runs interactive collection first; add `--non-interactive` + CCF_* for a promptless preview. |
| python3 missing | setup.sh exits 1 up front. Install python3, or use setup.ps1 on Windows. |
| Asked to install into the framework repo itself | Refuse; use a temp dir (`mkdir /tmp/test-project && cd … && git init`) per CLAUDE.md. |
| Existing husky/pre-commit hook in target | Setup skips its hook and prints the chain line: `bash .claude/hooks/pre-commit.sh \|\| exit 1`. |
| Testing local framework edits via `/install-framework` | Won't work — it clones GitHub. Run `setup.sh` from the local clone. |
| `CCF_DESIGN_SYSTEM` set for python/go/java/etc. | Silently ignored; resolver only consults it for react/nodejs. |
| Current branch ≠ CCF_BASE_BRANCH in non-interactive mode | No rename ever happens; placeholders get CCF_BASE_BRANCH. Rename manually if wanted. |
| Framework already installed (`.claude/settings.local.json` present) | `/install-framework`'s idempotency guard asks before re-running; for manual runs, `--reset` first (Linux nesting risk above). |
| Changing the summary "Files created:" counts | Those blocks near the end of both scripts hardcode 27/39/11/23 — they are doc surfaces; never hand-edit counts in isolation (see ccf-doc-sync-campaign). |

## Related Skills

- **ccf-parity-playbook** — switch to it before *editing* either installer; owns the bash↔PowerShell mirror checklist.
- **ccf-domain-reference** — vocabulary, `{{PLACEHOLDER}}` catalog, project types, full `config/*.json` catalog.
- **ccf-testing-and-qa** — the setup smoke test and what "done" requires after installer changes.
- **ccf-change-control** — gates and conventions before committing installer changes.
- **ccf-dogfood-and-drift** — why this repo's own `.claude/` is a curated subset, not an install.
- **ccf-doc-sync-campaign** — the doc-surface matrix including both setup summary blocks.

## Provenance and maintenance

Re-verify each fact before relying on it (all commands from the framework repo root):

- Flags + help text: `sed -n '7,18p' setup.sh` and `sed -n '4,16p' setup.ps1` (confirms `-NonInteractive` missing from ps1 help)
- Reset scope + messages: `sed -n '31,38p' setup.sh`; `sed -n '24,38p' setup.ps1`
- CCF_* resolver (values/defaults): `sed -n '59,135p' setup.sh`; `sed -n '51,131p' setup.ps1`
- Non-interactive never renames: `grep -n 'NonInteractive' setup.ps1 | head -5`; in setup.sh the rename block sits inside the interactive `else` branch (`grep -n 'Rename to' setup.sh`)
- ps1 dry-run banner trap: `grep -n '"  Setup Complete!"' setup.ps1` (unguarded)
- Counts: `ls -d skills/*/ | grep -v _template | wc -l` (27); `ls templates/agents/*.md | wc -l` (39); `ls templates/commands/*.md | wc -l` (11); `ls templates/rules/*.md | wc -l` (23); `ls templates/hooks/*.sh | wc -l` (8); `ls workflows/*.yml | wc -l` (4)
- What lands where / conditionals: read setup.sh from `# Generate project files` to EOF
- Global skill mechanics: `cat install-global-skill.sh`; `cat global-skills/install-framework/SKILL.md`
- Config files read by installers: `grep -o "config.\{0,4\}[a-z-]*\.json" setup.sh setup.ps1 | sort -u` (the `.\{0,4\}` also matches setup.sh's Python form `'config', 'x.json'`)
- VERSION is unread: `cat VERSION`; `grep -rn VERSION setup.sh setup.ps1 tests/ README.md` (expect no consumer)

Re-verify this skill whenever a commit touches `setup.sh`, `setup.ps1`, `install-global-skill.*`, `global-skills/`, `config/*.json`, `VERSION`, or either script's summary block.
