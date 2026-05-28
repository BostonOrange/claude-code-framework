# Design: `/install-framework` — Global Bootstrap Skill

**Date:** 2026-05-28
**Status:** Approved (design); pending implementation plan
**Repo:** claude-code-framework
**Remote:** https://github.com/BostonOrange/claude-code-framework

## Problem

Installing this framework into a new repo today requires running `setup.sh`/`setup.ps1`
by referencing a hardcoded local clone path (e.g. `bash ~/Developer/claude-code-framework/setup.sh`).
That breaks whenever the repo isn't cloned at the expected path, and it isn't usable from
Claude Code desktop/web where there is no terminal to invoke a local script.

We want a **global, account-level skill** — `/install-framework` — that can be run in *any*
repo, pulls the framework from GitHub (no local path needed), and installs it. Because it is a
personal skill under `~/.claude/skills/`, it surfaces across Claude Code CLI, desktop, and web.

## Non-Goals

- Reimplementing the copy/placeholder-substitution logic. That stays in `setup.sh`/`setup.ps1`,
  which remain the single source of truth (avoids a third place to drift).
- Deep per-project configuration. That is already owned by the per-repo `/setup` skill
  (17-layer detection/refinement). `/install-framework` only does the initial install, then
  hands off to `/setup`.
- Replacing or modifying the existing per-repo `/setup` skill. The two are distinct:
  `/install-framework` is global and runs *before* the framework exists in a repo;
  `/setup` is per-repo and runs *after* install to refine placeholders.

## Decisions (from brainstorming)

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Fetch strategy | **Ephemeral temp clone** (`git clone --depth 1` → temp → run → delete) | Bootstrapping is once-per-repo; freshness matters more than caching. Nothing persists on disk. |
| Skill name | **`/install-framework`** | Clear verb-object; unambiguous vs. the per-repo `/setup`. |
| Execution model | **Non-interactive mode added to installers** | Skill collects answers in chat, passes them to `setup.sh`/`ps1` via env vars. Installers stay the single source of truth = no drift. |
| Config depth | **Minimum to install, then defer to `/setup`** | Keeps this skill thin; reuses existing 17-layer refinement. |
| Distribution | **New top-level `global-skills/` dir + copy step** | `setup.sh` copies `skills/` into every target repo; this skill must stay account-global, not per-repo. |

## Architecture

Three components:

1. **Installer non-interactive mode** (`setup.sh` + `setup.ps1`)
2. **The global skill** (`global-skills/install-framework/SKILL.md`)
3. **Distribution** (copy script + README docs)

### Component 1: Installer non-interactive mode

Add a `--non-interactive` flag to **both** `setup.sh` and `setup.ps1` (the `setup-scripts.md`
parity rule requires mirroring).

Behavior when the flag is set:
- Read answers from `CCF_*` environment variables instead of `read -p` / `Read-Host`.
- Each variable has a documented default; an unset optional var falls back to its default.
- A missing **required** var (at minimum `CCF_PROJECT_TYPE`) fails fast with a clear message
  naming the missing variable.
- Interactive mode remains the **default** — zero behavior change for existing CLI users.

Environment variables (names map to existing prompts):

| Variable | Maps to prompt | Values | Default |
|----------|----------------|--------|---------|
| `CCF_PROJECT_TYPE` | Project type | salesforce \| nodejs \| python \| go \| java \| react \| internal-nextjs-app \| rails \| generic | *(required)* |
| `CCF_HOSTING_TARGET` | Internal-app hosting | local \| vercel \| azure-container-apps \| other | local |
| `CCF_STORAGE_PROVIDER` | Internal-app blob storage | (provider list) | (first option) |
| `CCF_POSTGRES_PROVIDER` | Internal-app Postgres | (provider list) | (first option) |
| `CCF_TRACKER` | Work-item tracker | azure \| jira \| linear \| github \| none | none |
| `CCF_CICD` | CI/CD system | github-actions \| azure-pipelines \| none | none |
| `CCF_BASE_BRANCH` | Base branch | any | main |
| `CCF_NOTIFICATION` | Notification system | slack \| teams \| discord \| none | none |
| `CCF_PROJECT_SHORT_NAME` | Worktree short name | any | repo dir basename |
| `CCF_DESIGN_SYSTEM` | Design system | (system list) \| none | none |

> The `HOSTING/STORAGE/POSTGRES` trio is only consumed when `CCF_PROJECT_TYPE=internal-nextjs-app`.

The exact value enumerations must match the current interactive prompts in `setup.sh`. The
implementation plan will confirm the live option lists for storage/postgres/design-system
against the script before finalizing.

### Component 2: The global skill (`SKILL.md`)

Frontmatter: `name: install-framework`, with a `description` that clearly distinguishes it from
the per-repo `/setup` (global install from GitHub vs. per-repo refinement).

Runtime flow:

1. **Prereqs + OS detection** — require `git`. Select installer by OS: Unix/macOS/Git Bash →
   `setup.sh`; Windows → `setup.ps1`. When using the bash path, verify `python3` is present
   (the bash installer requires it).
2. **Idempotency guard** — if the target repo already has `.claude/settings.local.json` or
   `.claude/state/setup-applied.md`, stop and ask the user before re-running. No silent clobber.
3. **Auto-detect** from the target repo:
   - project type — `package.json` (nodejs/react via deps), `requirements.txt`/`pyproject.toml`
     (python), `go.mod` (go), `pom.xml`/`build.gradle` (java), `Gemfile` (rails),
     `sfdx-project.json` (salesforce), else generic
   - base branch — `git symbolic-ref refs/remotes/origin/HEAD` or current branch
   - short name — repo directory basename
4. **Ask in chat** (AskUserQuestion) only for what can't be detected, plus confirm the detected
   project type: tracker, CI/CD, notification, design system. All have defaults so the user can
   accept quickly.
5. **Ephemeral clone** — `git clone --depth 1 https://github.com/BostonOrange/claude-code-framework.git <tmp>`.
6. **Run installer** — from `<tmp>`, with cwd = target repo, in non-interactive mode with `CCF_*`
   env vars set. The installer already derives `FRAMEWORK_DIR` from its own location and
   `PROJECT_DIR` from cwd, so running it from a temp clone against the target repo works without
   change.
7. **Verify** — assert no `{{...}}` placeholders remain:
   `grep -r '{{' CLAUDE.md .claude/` (excluding `.claude/state` and `.claude/backup`) returns nothing.
8. **Clean up** — delete `<tmp>`.
9. **Hand off** — report files installed and recommend running the now-installed `/setup` for
   deep 17-layer refinement (or `/develop` to start working).

### Component 3: Distribution

- Canonical source: `global-skills/install-framework/SKILL.md` in this repo. A new top-level
  `global-skills/` directory — deliberately **not** under `skills/`, because `setup.sh` copies
  `skills/` into every target repo and this skill must remain account-global.
- A small installer for the skill itself: `install-global-skill.ps1` and `install-global-skill.sh`
  (essentially one copy) that place `global-skills/install-framework/` into `~/.claude/skills/`.
- README section documenting `/install-framework`: what it does, how it differs from `/setup`,
  and the one-time copy step to register it globally.

## Error Handling

| Failure | Behavior |
|---------|----------|
| `git` missing | Stop with clear message; cannot clone. |
| `python3` missing (bash path) | Stop with message; suggest Windows uses `setup.ps1` automatically. |
| Framework already installed in target repo | Idempotency guard prompts before continuing. |
| Required `CCF_*` var missing in non-interactive mode | Installer fails fast naming the variable. |
| Clone fails (network/offline) | Skill reports the clone error; temp dir cleaned up; no partial install. |
| `{{...}}` placeholders remain after install | Verification step fails loudly; surface offending files; do not report success. |
| Temp clone left behind on error | Cleanup runs in all exit paths. |

## Testing

- Extend `tests/check-setup-smoke.sh` and `tests/check-setup-smoke.ps1` to run the installer in
  `--non-interactive` mode with `CCF_*` vars set in a temp dir, asserting all template files copy
  and no `{{...}}` remain.
- Add a sanity check that `global-skills/install-framework/SKILL.md` has valid frontmatter
  (`name`, `description`) and references the correct GitHub remote URL.
- Confirm interactive mode is unchanged (default path still prompts).

## Consistency Obligations (per repo rules)

- `setup.sh` ↔ `setup.ps1` parity for the new `--non-interactive` flag and all `CCF_*` mappings.
- Document new `CCF_*` interface in CLAUDE.md "Key Conventions" / setup-script docs.
- Update README and any docs that enumerate skills/commands to mention `/install-framework`
  (noting it is global, not a per-repo template skill).

## Open Items for the Implementation Plan

1. Confirm the live option enumerations for `CCF_STORAGE_PROVIDER`, `CCF_POSTGRES_PROVIDER`, and
   `CCF_DESIGN_SYSTEM` against the current `setup.sh` prompts.
2. Decide whether `install-global-skill.{sh,ps1}` overwrites an existing
   `~/.claude/skills/install-framework/` or prompts first.
3. Verify Claude Code web sandbox has `git` + network access for the ephemeral clone.
