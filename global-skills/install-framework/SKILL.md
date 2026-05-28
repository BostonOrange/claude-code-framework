---
name: install-framework
description: Install the Claude Code Framework into the current repo by cloning it from GitHub (no local clone path needed). Global/account-level skill. Distinct from the per-repo /setup, which refines an already-installed framework.
---

# Install Framework

Bootstraps the Claude Code Framework into the **current working directory's repo** by cloning
the framework from GitHub and running its installer in non-interactive mode. Use this in a repo
that does NOT yet have the framework. To *refine* an already-installed framework, use the
per-repo `/setup` instead.

Framework source (clone target): `https://github.com/BostonOrange/claude-code-framework.git`

## Process

### 1. Prerequisites + OS detection

- Confirm `git` is available (`git --version`). If missing, stop and tell the user to install git.
- Detect the OS to choose the installer:
  - Windows → `setup.ps1` (run with `pwsh` or `powershell`). PowerShell is required.
  - macOS / Linux / Git Bash → `setup.sh`. It requires `python3`; if `python3` is missing, stop
    and tell the user.

### 2. Idempotency guard

If the target repo already contains `.claude/settings.local.json` or
`.claude/state/setup-applied.md`, the framework is likely already installed. Stop and ask the
user whether to re-run (which overwrites template files) before continuing. Do not clobber silently.

### 3. Auto-detect what you can (target repo = current directory)

- **Project type** from marker files:
  - `package.json` with React/Next deps → `react`, otherwise `nodejs`
  - `requirements.txt` / `pyproject.toml` → `python`
  - `go.mod` → `go`
  - `pom.xml` / `build.gradle` → `java`
  - `Gemfile` → `rails`
  - `sfdx-project.json` → `salesforce`
  - none of the above → `generic`
- **Base branch**: `git symbolic-ref --short refs/remotes/origin/HEAD` (strip `origin/`); fall back
  to the current branch, then `main`.
- **Short name**: the repo directory's basename.

### 4. Collect remaining answers in chat

Confirm the detected project type, then ask (with sensible defaults) for the values you cannot
detect: tracker (`ado`/`jira`/`linear`/`github`/`none`), CI/CD
(`github-actions`/`gitlab-ci`/`circleci`/`none`), notification
(`slack`/`teams`/`discord`/`none`), and — only for `react`/`nodejs` — design system
(`untitled-ui`/`shadcn`/`custom`/`none`). Keep it minimal; deep configuration is `/setup`'s job.

Map every answer to its `CCF_*` variable (see the contract in the framework's setup docs):
`CCF_PROJECT_TYPE`, `CCF_TRACKER`, `CCF_CICD`, `CCF_NOTIFICATION`, `CCF_BASE_BRANCH`,
`CCF_PROJECT_SHORT_NAME`, `CCF_DESIGN_SYSTEM` (+ the internal-app trio
`CCF_HOSTING_TARGET`/`CCF_STORAGE_PROVIDER`/`CCF_POSTGRES_PROVIDER` when type is
`internal-nextjs-app`).

### 5. Clone the framework to a temp dir

```bash
TMP=$(mktemp -d)
git clone --depth 1 https://github.com/BostonOrange/claude-code-framework.git "$TMP"
```

(Windows: `$TMP = Join-Path $env:TEMP ("ccf-" + [guid]::NewGuid()); git clone --depth 1 https://github.com/BostonOrange/claude-code-framework.git $TMP`)

### 6. Run the installer non-interactively (cwd = target repo)

The installer derives its own location for framework files and uses the current directory as the
target, so run it from the target repo while pointing at the temp clone.

macOS / Linux / Git Bash:

```bash
CCF_PROJECT_TYPE=<type> CCF_TRACKER=<tracker> CCF_CICD=<ci> \
CCF_NOTIFICATION=<notify> CCF_BASE_BRANCH=<branch> CCF_PROJECT_SHORT_NAME=<short> \
CCF_DESIGN_SYSTEM=<design> \
bash "$TMP/setup.sh" --non-interactive
```

Windows (PowerShell):

```powershell
$env:CCF_PROJECT_TYPE = "<type>"; $env:CCF_TRACKER = "<tracker>"; $env:CCF_CICD = "<ci>"
$env:CCF_NOTIFICATION = "<notify>"; $env:CCF_BASE_BRANCH = "<branch>"
$env:CCF_PROJECT_SHORT_NAME = "<short>"; $env:CCF_DESIGN_SYSTEM = "<design>"
& "$TMP/setup.ps1" -NonInteractive
```

### 7. Verify

Confirm no unreplaced placeholders remain:

```bash
grep -R "{{[A-Z_][A-Z_]*}}" CLAUDE.md .claude 2>/dev/null | grep -v ".claude/state" | grep -v ".claude/skills/improve/SKILL.md"
```

If anything prints, surface it and do NOT report success.

### 8. Clean up

Delete the temp clone (`rm -rf "$TMP"` / `Remove-Item -Recurse -Force $TMP`). Always run cleanup,
including on failure.

### 9. Hand off

Report the files installed and recommend the per-repo `/setup` for the deep 17-layer refinement
(or `/develop <TICKET>` to start working).

## Edge Cases

| Scenario | Behavior |
|----------|----------|
| `git` not installed | Stop before cloning; instruct user to install git |
| `python3` missing on the bash path | Stop; on Windows the PowerShell installer avoids this |
| Framework already installed | Idempotency guard asks before re-running |
| Clone fails (offline) | Report the error; ensure temp dir is cleaned up; no partial install |
| Placeholders remain after install | Verification fails loudly; do not claim success |

## Related

- Per-repo `/setup` — refines an already-installed framework (17-layer detection). Run it after this.
- `setup.sh` / `setup.ps1` `--non-interactive` mode — the execution mechanism this skill drives.
