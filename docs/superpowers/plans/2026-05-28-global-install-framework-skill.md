# Global `/install-framework` Skill — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a global, account-level `/install-framework` skill that installs this framework into any repo by cloning from GitHub, powered by a new `--non-interactive` mode in `setup.sh`/`setup.ps1`.

**Architecture:** The two installers gain a `--non-interactive` / `-NonInteractive` path that reads answers from `CCF_*` environment variables instead of interactive prompts (interactive stays the default). A new `global-skills/install-framework/SKILL.md` (copied into `~/.claude/skills/` by a small install script) orchestrates: detect target repo → collect minimal answers in chat → `git clone --depth 1` the framework to a temp dir → run the OS-appropriate installer non-interactively → verify no placeholders remain → clean up → hand off to the per-repo `/setup`.

**Tech Stack:** Bash, PowerShell, Markdown (skill), the repo's existing `tests/check-*.sh` smoke-test harness (auto-discovered by `tests/run-all.sh`).

**Spec:** `docs/superpowers/specs/2026-05-28-global-install-framework-skill-design.md`

**Repo remote (hardcoded into the skill):** `https://github.com/BostonOrange/claude-code-framework.git`

---

## Reference: `CCF_*` environment variable contract

These are the only inputs the non-interactive installers read. Values must match the existing interactive option names exactly.

| Variable | Values | Default | Notes |
|----------|--------|---------|-------|
| `CCF_PROJECT_TYPE` | `salesforce` `nodejs` `python` `go` `java` `react` `internal-nextjs-app` `rails` `generic` | *(required)* | Missing → error + exit 1 |
| `CCF_HOSTING_TARGET` | `local` `vercel` `azure-container-apps` `other` | `local` | Only used when type = `internal-nextjs-app` |
| `CCF_STORAGE_PROVIDER` | `azurite` `azure-blob` `vercel-blob` | `azurite` | internal-app only |
| `CCF_POSTGRES_PROVIDER` | `local-docker` `database-url` `azure-postgres-flexible-server` | `local-docker` | internal-app only |
| `CCF_TRACKER` | `ado` `jira` `linear` `github` `none` | `none` | |
| `CCF_ADO_ORG` / `CCF_ADO_PROJECT` | any | `""` | optional tracker detail |
| `CCF_JIRA_DOMAIN` / `CCF_JIRA_PROJECT` | any | `""` | optional tracker detail |
| `CCF_LINEAR_TEAM` | any | `""` | optional tracker detail |
| `CCF_CICD` | `github-actions` `gitlab-ci` `circleci` `none` | `none` | |
| `CCF_BASE_BRANCH` | any | `main` | Non-interactive NEVER renames branches |
| `CCF_NOTIFICATION` | `slack` `teams` `discord` `none` | `none` | |
| `CCF_PROJECT_SHORT_NAME` | any | repo dir basename | |
| `CCF_DESIGN_SYSTEM` | `untitled-ui` `shadcn` `custom` `none` | `none` | Only consulted for `react`/`nodejs`; other types auto-pick `_backend`/`none` |

---

## File Structure

- **Modify** `setup.sh` — add `--non-interactive` flag + `CCF_*` resolver branch; the existing prompt section becomes the `else` branch; branch-rename is skipped in non-interactive mode (it lives inside the wrapped section).
- **Modify** `setup.ps1` — mirror: `-NonInteractive` switch + resolver; guard the later rename block with `-and -not $NonInteractive`.
- **Modify** `tests/check-setup-smoke.sh` — add non-interactive pass case + missing-required-var failure case.
- **Modify** `tests/check-setup-smoke.ps1` — same two cases (mirror).
- **Create** `global-skills/install-framework/SKILL.md` — the global orchestrator skill (NOT under `skills/`, so `setup.sh` does not copy it per-repo and the per-repo skill count stays 26).
- **Create** `tests/check-global-skill.sh` — frontmatter + GitHub-URL sanity check (auto-discovered by `run-all.sh`).
- **Create** `install-global-skill.sh` and `install-global-skill.ps1` — copy `global-skills/install-framework/` into `~/.claude/skills/`.
- **Modify** `README.md` and `CLAUDE.md` — document `/install-framework`, the `CCF_*` interface, and the new `global-skills/` directory.

> **Do NOT** change the "26 workflow skills" count anywhere. The new skill is account-global, not a per-repo template skill.

---

### Task 1: `setup.sh` non-interactive mode

**Files:**
- Modify: `setup.sh` (arg parsing near top; wrap config section; reference Read of lines 8-16, 55-57, 326-327)
- Test: `tests/check-setup-smoke.sh`

- [ ] **Step 1: Write the failing smoke-test cases**

In `tests/check-setup-smoke.sh`, insert the following block immediately before the final results banner (before the `echo "--------------------------------------"` that precedes `Results:`):

```bash
echo ""
echo "Non-interactive Node.js target..."
NI_TARGET="$TMP_ROOT/ni-node"
NI_HOME="$TMP_ROOT/home-ni-node"
NI_OUTPUT="$TMP_ROOT/ni-node.out"
mkdir -p "$NI_TARGET" "$NI_HOME"
if (cd "$NI_TARGET" && \
    CCF_PROJECT_TYPE=nodejs CCF_TRACKER=none CCF_CICD=none CCF_NOTIFICATION=none \
    CCF_DESIGN_SYSTEM=none CCF_BASE_BRANCH=main CCF_PROJECT_SHORT_NAME=sample \
    HOME="$NI_HOME" bash "$FRAMEWORK_DIR/setup.sh" --non-interactive >"$NI_OUTPUT" 2>&1); then
    pass "non-interactive node setup exits 0"
else
    fail "non-interactive node setup exits 0"
    sed -n '1,120p' "$NI_OUTPUT"
fi
assert_no_traceback "$NI_OUTPUT" "non-interactive node has no Python traceback"
assert_file_exists "$NI_TARGET/.claude/skills/develop/SKILL.md" "non-interactive node installs skills"
assert_file_exists "$NI_TARGET/CLAUDE.md" "non-interactive node creates CLAUDE.md"
assert_no_unreplaced_placeholders "$NI_TARGET" "non-interactive node has no operational placeholders"

echo ""
echo "Non-interactive missing CCF_PROJECT_TYPE fails..."
MISS_TARGET="$TMP_ROOT/ni-missing"
MISS_HOME="$TMP_ROOT/home-ni-missing"
MISS_OUTPUT="$TMP_ROOT/ni-missing.out"
mkdir -p "$MISS_TARGET" "$MISS_HOME"
if (cd "$MISS_TARGET" && HOME="$MISS_HOME" bash "$FRAMEWORK_DIR/setup.sh" --non-interactive >"$MISS_OUTPUT" 2>&1); then
    fail "non-interactive without CCF_PROJECT_TYPE exits non-zero"
else
    pass "non-interactive without CCF_PROJECT_TYPE exits non-zero"
fi
assert_contains "$MISS_OUTPUT" "CCF_PROJECT_TYPE is required" "non-interactive missing type reports clear error"
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `bash tests/check-setup-smoke.sh`
Expected: FAIL. Without the flag, `setup.sh --non-interactive` ignores the unknown arg and blocks on the first interactive `read` (no stdin), so the run hangs/EOFs and the new assertions fail.

- [ ] **Step 3: Add the `--non-interactive` flag to arg parsing**

Replace this block (currently `setup.sh` lines 8-16):

```bash
DRY_RUN=false
RESET=false
for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=true ;;
        --reset) RESET=true ;;
        --help|-h) echo "Usage: setup.sh [--dry-run] [--reset]"; echo "  --dry-run  Show what would be done without making changes"; echo "  --reset    Remove framework files from target project"; exit 0 ;;
    esac
done
```

with:

```bash
DRY_RUN=false
RESET=false
NON_INTERACTIVE=false
for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=true ;;
        --reset) RESET=true ;;
        --non-interactive) NON_INTERACTIVE=true ;;
        --help|-h) echo "Usage: setup.sh [--dry-run] [--reset] [--non-interactive]"; echo "  --dry-run          Show what would be done without making changes"; echo "  --reset            Remove framework files from target project"; echo "  --non-interactive  Read answers from CCF_* environment variables (no prompts)"; exit 0 ;;
    esac
done
```

- [ ] **Step 4: Open the resolver / interactive branch**

Replace this block (currently `setup.sh` lines 55-57):

```bash
# ── 1. Project Type ──────────────────────────────────────────────

echo "What type of project is this?"
```

with:

```bash
# ── Collect configuration (non-interactive resolver OR interactive prompts) ──

if [ "$NON_INTERACTIVE" = true ]; then
    echo "Running in non-interactive mode (reading CCF_* environment variables)."

    PROJECT_TYPE_NAME="${CCF_PROJECT_TYPE:-}"
    case "$PROJECT_TYPE_NAME" in
        salesforce|nodejs|python|go|java|react|internal-nextjs-app|rails|generic) ;;
        "") echo "ERROR: CCF_PROJECT_TYPE is required in non-interactive mode."; exit 1 ;;
        *) echo "ERROR: invalid CCF_PROJECT_TYPE '$PROJECT_TYPE_NAME'."; exit 1 ;;
    esac

    HOSTING_TARGET="not-applicable"; HOSTING_TARGET_LABEL="N/A"
    STORAGE_PROVIDER="not-applicable"; STORAGE_PROVIDER_LABEL="N/A"
    POSTGRES_PROVIDER="not-applicable"; POSTGRES_PROVIDER_LABEL="N/A"

    if [ "$PROJECT_TYPE_NAME" = "internal-nextjs-app" ]; then
        HOSTING_TARGET="${CCF_HOSTING_TARGET:-local}"
        case "$HOSTING_TARGET" in
            local) HOSTING_TARGET_LABEL="Local only" ;;
            vercel) HOSTING_TARGET_LABEL="Vercel" ;;
            azure-container-apps) HOSTING_TARGET_LABEL="Azure Container Apps" ;;
            other) HOSTING_TARGET_LABEL="Other" ;;
            *) echo "ERROR: invalid CCF_HOSTING_TARGET '$HOSTING_TARGET'."; exit 1 ;;
        esac
        STORAGE_PROVIDER="${CCF_STORAGE_PROVIDER:-azurite}"
        case "$STORAGE_PROVIDER" in
            azurite) STORAGE_PROVIDER_LABEL="Local Azurite" ;;
            azure-blob) STORAGE_PROVIDER_LABEL="Azure Blob" ;;
            vercel-blob) STORAGE_PROVIDER_LABEL="Vercel Blob" ;;
            *) echo "ERROR: invalid CCF_STORAGE_PROVIDER '$STORAGE_PROVIDER'."; exit 1 ;;
        esac
        POSTGRES_PROVIDER="${CCF_POSTGRES_PROVIDER:-local-docker}"
        case "$POSTGRES_PROVIDER" in
            local-docker) POSTGRES_PROVIDER_LABEL="Local Docker Postgres" ;;
            database-url) POSTGRES_PROVIDER_LABEL="Managed Postgres via DATABASE_URL" ;;
            azure-postgres-flexible-server) POSTGRES_PROVIDER_LABEL="Azure Postgres Flexible Server" ;;
            *) echo "ERROR: invalid CCF_POSTGRES_PROVIDER '$POSTGRES_PROVIDER'."; exit 1 ;;
        esac
    fi

    TRACKER_NAME="${CCF_TRACKER:-none}"
    case "$TRACKER_NAME" in
        ado|jira|linear|github|none) ;;
        *) echo "ERROR: invalid CCF_TRACKER '$TRACKER_NAME'."; exit 1 ;;
    esac
    ADO_ORG="${CCF_ADO_ORG:-}"
    ADO_PROJECT="${CCF_ADO_PROJECT:-}"
    JIRA_DOMAIN="${CCF_JIRA_DOMAIN:-}"
    JIRA_PROJECT="${CCF_JIRA_PROJECT:-}"
    LINEAR_TEAM="${CCF_LINEAR_TEAM:-}"

    CI_NAME="${CCF_CICD:-none}"
    case "$CI_NAME" in
        github-actions|gitlab-ci|circleci|none) ;;
        *) echo "ERROR: invalid CCF_CICD '$CI_NAME'."; exit 1 ;;
    esac

    BASE_BRANCH="${CCF_BASE_BRANCH:-main}"

    NOTIFY_NAME="${CCF_NOTIFICATION:-none}"
    case "$NOTIFY_NAME" in
        slack|teams|discord|none) ;;
        *) echo "ERROR: invalid CCF_NOTIFICATION '$NOTIFY_NAME'."; exit 1 ;;
    esac

    PROJECT_SHORT="${CCF_PROJECT_SHORT_NAME:-$PROJECT_NAME}"

    case "$PROJECT_TYPE_NAME" in
        react|nodejs)
            DESIGN_SYSTEM_NAME="${CCF_DESIGN_SYSTEM:-none}"
            case "$DESIGN_SYSTEM_NAME" in
                untitled-ui|shadcn|custom|none) ;;
                *) echo "ERROR: invalid CCF_DESIGN_SYSTEM '$DESIGN_SYSTEM_NAME'."; exit 1 ;;
            esac
            ;;
        internal-nextjs-app) DESIGN_SYSTEM_NAME="none" ;;
        *) DESIGN_SYSTEM_NAME="_backend" ;;
    esac
else

# ── 1. Project Type ──────────────────────────────────────────────

echo "What type of project is this?"
```

- [ ] **Step 5: Close the branch before the shared design-system load**

Replace this block (currently `setup.sh` lines 326-327):

```bash
# Load design system values from config/design-systems.json
eval "$(python3 << DESIGN_EOF
```

with:

```bash
fi  # end non-interactive resolver vs interactive prompts

# Load design system values from config/design-systems.json
eval "$(python3 << DESIGN_EOF
```

> The entire interactive region (project type → tracker → CI → base branch + rename → notify → short name → design-system selection) is now the `else` body, so non-interactive mode skips the destructive branch-rename automatically. The shared `design-systems.json` load and everything after run in both modes.

- [ ] **Step 6: Run the tests to verify they pass**

Run: `bash tests/check-setup-smoke.sh`
Expected: PASS — including the four interactive cases (unchanged) and the two new non-interactive cases.

- [ ] **Step 7: Commit**

```bash
git add setup.sh tests/check-setup-smoke.sh
git commit -m "Add non-interactive mode to setup.sh (CCF_* env vars)"
```

---

### Task 2: `setup.ps1` non-interactive mode (parity)

**Files:**
- Modify: `setup.ps1` (param block lines 4-8; wrap config lines 48-50; close before line 271; guard rename at line 496)
- Test: `tests/check-setup-smoke.ps1`

- [ ] **Step 1: Write the failing smoke-test cases**

In `tests/check-setup-smoke.ps1`, first extend `Invoke-SetupProcess` to support a `-NonInteractive` switch. Replace its signature line (currently line 51):

```powershell
function Invoke-SetupProcess($Target, $Home, $InputText, [switch]$DryRun) {
```

with:

```powershell
function Invoke-SetupProcess($Target, $Home, $InputText, [switch]$DryRun, [switch]$NonInteractive) {
```

and replace the args-building block (currently lines 60-61):

```powershell
    $args = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $SetupScript)
    if ($DryRun) { $args += "-DryRun" }
```

with:

```powershell
    $args = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $SetupScript)
    if ($DryRun) { $args += "-DryRun" }
    if ($NonInteractive) { $args += "-NonInteractive" }
```

Then insert the following cases immediately before the final results banner (before `Write-Host "--------------------------------------"` that precedes `Results:`):

```powershell
Write-Host ""
Write-Host "Non-interactive Node.js target..."
$niTarget = Join-Path $TmpRoot "ni-node"
$niHome = Join-Path $TmpRoot "home-ni-node"
$env:CCF_PROJECT_TYPE = "nodejs"
$env:CCF_TRACKER = "none"
$env:CCF_CICD = "none"
$env:CCF_NOTIFICATION = "none"
$env:CCF_DESIGN_SYSTEM = "none"
$env:CCF_BASE_BRANCH = "main"
$env:CCF_PROJECT_SHORT_NAME = "sample"
try {
    $niResult = Invoke-SetupProcess -Target $niTarget -Home $niHome -InputText "" -NonInteractive
} finally {
    Remove-Item Env:\CCF_PROJECT_TYPE, Env:\CCF_TRACKER, Env:\CCF_CICD, Env:\CCF_NOTIFICATION, Env:\CCF_DESIGN_SYSTEM, Env:\CCF_BASE_BRANCH, Env:\CCF_PROJECT_SHORT_NAME -ErrorAction SilentlyContinue
}
if ($niResult.ExitCode -eq 0) { Pass "non-interactive node setup exits 0" } else { Fail "non-interactive node setup exits 0"; Write-Host ($niResult.Output -split "`n" | Select-Object -First 120) }
Assert-NoTraceback $niResult "non-interactive node has no PowerShell exception"
Assert-Exists (Join-Path $niTarget ".claude/skills/develop/SKILL.md") "non-interactive node installs skills"
Assert-Exists (Join-Path $niTarget "CLAUDE.md") "non-interactive node creates CLAUDE.md"
Assert-NoOperationalPlaceholders $niTarget "non-interactive node has no operational placeholders"

Write-Host ""
Write-Host "Non-interactive missing CCF_PROJECT_TYPE fails..."
$missTarget = Join-Path $TmpRoot "ni-missing"
$missHome = Join-Path $TmpRoot "home-ni-missing"
$missResult = Invoke-SetupProcess -Target $missTarget -Home $missHome -InputText "" -NonInteractive
if ($missResult.ExitCode -ne 0) { Pass "non-interactive without CCF_PROJECT_TYPE exits non-zero" } else { Fail "non-interactive without CCF_PROJECT_TYPE exits non-zero" }
if ($missResult.Output -match "CCF_PROJECT_TYPE is required") { Pass "non-interactive missing type reports clear error" } else { Fail "non-interactive missing type reports clear error" }
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `pwsh -NoProfile -File tests/check-setup-smoke.ps1`
Expected: FAIL. `setup.ps1` does not yet accept `-NonInteractive`, so PowerShell errors on the unknown parameter and the new assertions fail.

- [ ] **Step 3: Add the `-NonInteractive` switch to the param block**

Replace this block (currently `setup.ps1` lines 4-8):

```powershell
param(
    [switch]$DryRun,
    [switch]$Reset,
    [switch]$Help
)
```

with:

```powershell
param(
    [switch]$DryRun,
    [switch]$Reset,
    [switch]$NonInteractive,
    [switch]$Help
)
```

- [ ] **Step 4: Open the resolver / interactive branch**

Replace this block (currently `setup.ps1` lines 48-50):

```powershell
# -- 1. Project Type --

Write-Host "What type of project is this?"
```

with:

```powershell
# -- Collect configuration (non-interactive resolver OR interactive prompts) --

if ($NonInteractive) {
    Write-Host "Running in non-interactive mode (reading CCF_* environment variables)."

    $PROJECT_TYPE_NAME = $env:CCF_PROJECT_TYPE
    if (-not $PROJECT_TYPE_NAME) {
        Write-Host "ERROR: CCF_PROJECT_TYPE is required in non-interactive mode."
        exit 1
    }
    if ($PROJECT_TYPE_NAME -notin "salesforce", "nodejs", "python", "go", "java", "react", "internal-nextjs-app", "rails", "generic") {
        Write-Host "ERROR: invalid CCF_PROJECT_TYPE '$PROJECT_TYPE_NAME'."
        exit 1
    }

    $HOSTING_TARGET = "not-applicable"; $HOSTING_TARGET_LABEL = "N/A"
    $STORAGE_PROVIDER = "not-applicable"; $STORAGE_PROVIDER_LABEL = "N/A"
    $POSTGRES_PROVIDER = "not-applicable"; $POSTGRES_PROVIDER_LABEL = "N/A"

    if ($PROJECT_TYPE_NAME -eq "internal-nextjs-app") {
        $HOSTING_TARGET = if ($env:CCF_HOSTING_TARGET) { $env:CCF_HOSTING_TARGET } else { "local" }
        switch ($HOSTING_TARGET) {
            "local" { $HOSTING_TARGET_LABEL = "Local only" }
            "vercel" { $HOSTING_TARGET_LABEL = "Vercel" }
            "azure-container-apps" { $HOSTING_TARGET_LABEL = "Azure Container Apps" }
            "other" { $HOSTING_TARGET_LABEL = "Other" }
            default { Write-Host "ERROR: invalid CCF_HOSTING_TARGET '$HOSTING_TARGET'."; exit 1 }
        }
        $STORAGE_PROVIDER = if ($env:CCF_STORAGE_PROVIDER) { $env:CCF_STORAGE_PROVIDER } else { "azurite" }
        switch ($STORAGE_PROVIDER) {
            "azurite" { $STORAGE_PROVIDER_LABEL = "Local Azurite" }
            "azure-blob" { $STORAGE_PROVIDER_LABEL = "Azure Blob" }
            "vercel-blob" { $STORAGE_PROVIDER_LABEL = "Vercel Blob" }
            default { Write-Host "ERROR: invalid CCF_STORAGE_PROVIDER '$STORAGE_PROVIDER'."; exit 1 }
        }
        $POSTGRES_PROVIDER = if ($env:CCF_POSTGRES_PROVIDER) { $env:CCF_POSTGRES_PROVIDER } else { "local-docker" }
        switch ($POSTGRES_PROVIDER) {
            "local-docker" { $POSTGRES_PROVIDER_LABEL = "Local Docker Postgres" }
            "database-url" { $POSTGRES_PROVIDER_LABEL = "Managed Postgres via DATABASE_URL" }
            "azure-postgres-flexible-server" { $POSTGRES_PROVIDER_LABEL = "Azure Postgres Flexible Server" }
            default { Write-Host "ERROR: invalid CCF_POSTGRES_PROVIDER '$POSTGRES_PROVIDER'."; exit 1 }
        }
    }

    $TRACKER_NAME = if ($env:CCF_TRACKER) { $env:CCF_TRACKER } else { "none" }
    if ($TRACKER_NAME -notin "ado", "jira", "linear", "github", "none") {
        Write-Host "ERROR: invalid CCF_TRACKER '$TRACKER_NAME'."
        exit 1
    }
    $ADO_ORG = $env:CCF_ADO_ORG
    $ADO_PROJECT = $env:CCF_ADO_PROJECT
    $JIRA_DOMAIN = $env:CCF_JIRA_DOMAIN
    $JIRA_PROJECT = $env:CCF_JIRA_PROJECT
    $LINEAR_TEAM = $env:CCF_LINEAR_TEAM

    $CI_NAME = if ($env:CCF_CICD) { $env:CCF_CICD } else { "none" }
    if ($CI_NAME -notin "github-actions", "gitlab-ci", "circleci", "none") {
        Write-Host "ERROR: invalid CCF_CICD '$CI_NAME'."
        exit 1
    }

    $BASE_BRANCH = if ($env:CCF_BASE_BRANCH) { $env:CCF_BASE_BRANCH } else { "main" }

    $NOTIFY_NAME = if ($env:CCF_NOTIFICATION) { $env:CCF_NOTIFICATION } else { "none" }
    if ($NOTIFY_NAME -notin "slack", "teams", "discord", "none") {
        Write-Host "ERROR: invalid CCF_NOTIFICATION '$NOTIFY_NAME'."
        exit 1
    }

    $PROJECT_SHORT = if ($env:CCF_PROJECT_SHORT_NAME) { $env:CCF_PROJECT_SHORT_NAME } else { $PROJECT_NAME }

    if ($PROJECT_TYPE_NAME -in "react", "nodejs") {
        $DESIGN_SYSTEM_NAME = if ($env:CCF_DESIGN_SYSTEM) { $env:CCF_DESIGN_SYSTEM } else { "none" }
        if ($DESIGN_SYSTEM_NAME -notin "untitled-ui", "shadcn", "custom", "none") {
            Write-Host "ERROR: invalid CCF_DESIGN_SYSTEM '$DESIGN_SYSTEM_NAME'."
            exit 1
        }
    } elseif ($PROJECT_TYPE_NAME -eq "internal-nextjs-app") {
        $DESIGN_SYSTEM_NAME = "none"
    } else {
        $DESIGN_SYSTEM_NAME = "_backend"
    }
} else {

# -- 1. Project Type --

Write-Host "What type of project is this?"
```

- [ ] **Step 5: Close the branch before the shared design-system load**

Replace this block (currently `setup.ps1` lines 271-272):

```powershell
# Load design system values from config/design-systems.json
$designSystems = Get-Content "$FRAMEWORK_DIR/config/design-systems.json" -Raw -Encoding UTF8 | ConvertFrom-Json
```

with:

```powershell
}  # end non-interactive resolver vs interactive prompts

# Load design system values from config/design-systems.json
$designSystems = Get-Content "$FRAMEWORK_DIR/config/design-systems.json" -Raw -Encoding UTF8 | ConvertFrom-Json
```

- [ ] **Step 6: Skip branch rename in non-interactive mode**

Replace this block (currently `setup.ps1` lines 495-496):

```powershell
$isGitRepo = git rev-parse --git-dir 2>$null
if ($isGitRepo) {
```

with:

```powershell
$isGitRepo = git rev-parse --git-dir 2>$null
if ($isGitRepo -and -not $NonInteractive) {
```

- [ ] **Step 7: Run the tests to verify they pass**

Run: `pwsh -NoProfile -File tests/check-setup-smoke.ps1`
Expected: PASS — four interactive cases (unchanged) plus the two new non-interactive cases.

- [ ] **Step 8: Commit**

```bash
git add setup.ps1 tests/check-setup-smoke.ps1
git commit -m "Add non-interactive mode to setup.ps1 (parity with setup.sh)"
```

---

### Task 3: Global skill + sanity test

**Files:**
- Create: `global-skills/install-framework/SKILL.md`
- Create: `tests/check-global-skill.sh`

- [ ] **Step 1: Write the failing sanity test**

Create `tests/check-global-skill.sh`:

```bash
#!/bin/bash
# Claude Code Framework — Global install-framework skill sanity checks
set -euo pipefail

FRAMEWORK_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SKILL="$FRAMEWORK_DIR/global-skills/install-framework/SKILL.md"
PASS=0
FAIL=0

check() {
    local label="$1"; shift
    if "$@" >/dev/null 2>&1; then
        echo "  [PASS] $label"; PASS=$((PASS + 1))
    else
        echo "  [FAIL] $label"; FAIL=$((FAIL + 1))
    fi
}

echo "======================================"
echo "  Global Skill Sanity Checks"
echo "======================================"
echo ""

check "SKILL.md exists" test -f "$SKILL"
check "frontmatter declares name: install-framework" grep -q "^name: install-framework$" "$SKILL"
check "frontmatter has a description" grep -q "^description:" "$SKILL"
check "references the GitHub remote" grep -q "github.com/BostonOrange/claude-code-framework" "$SKILL"
check "passes --non-interactive to setup.sh" grep -q -- "--non-interactive" "$SKILL"
check "passes -NonInteractive to setup.ps1" grep -q -- "-NonInteractive" "$SKILL"

echo ""
echo "--------------------------------------"
echo "  Results: $PASS passed, $FAIL failed"
echo "--------------------------------------"

if [ "$FAIL" -gt 0 ]; then
    echo "FAILED: $FAIL global-skill check(s) failed"
    exit 1
fi
echo "All global-skill checks passed."
exit 0
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bash tests/check-global-skill.sh`
Expected: FAIL with `[FAIL] SKILL.md exists` (the file does not exist yet).

- [ ] **Step 3: Create the global skill**

Create `global-skills/install-framework/SKILL.md`:

````markdown
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
````

- [ ] **Step 4: Run the test to verify it passes**

Run: `bash tests/check-global-skill.sh`
Expected: PASS (all six checks).

- [ ] **Step 5: Commit**

```bash
git add global-skills/install-framework/SKILL.md tests/check-global-skill.sh
git commit -m "Add global /install-framework skill + sanity test"
```

---

### Task 4: Global-skill installer scripts

**Files:**
- Create: `install-global-skill.sh`
- Create: `install-global-skill.ps1`

- [ ] **Step 1: Create the bash installer**

Create `install-global-skill.sh`:

```bash
#!/bin/bash
# Installs the global /install-framework skill into ~/.claude/skills/.
# Run from a clone of claude-code-framework.
set -e

FRAMEWORK_DIR="$(cd "$(dirname "$0")" && pwd)"
SRC="$FRAMEWORK_DIR/global-skills/install-framework"
DEST="$HOME/.claude/skills/install-framework"

if [ ! -d "$SRC" ]; then
    echo "ERROR: $SRC not found. Run this from a clone of claude-code-framework."
    exit 1
fi

mkdir -p "$HOME/.claude/skills"
if [ -d "$DEST" ]; then
    echo "Updating existing global skill at $DEST"
    rm -rf "$DEST"
fi
cp -r "$SRC" "$DEST"
echo "Installed /install-framework to $DEST"
echo "It is now available in Claude Code (CLI, desktop, web)."
```

- [ ] **Step 2: Create the PowerShell installer**

Create `install-global-skill.ps1`:

```powershell
# Installs the global /install-framework skill into ~/.claude/skills/.
# Run from a clone of claude-code-framework.
$ErrorActionPreference = "Stop"

$FrameworkDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$Src = Join-Path $FrameworkDir "global-skills/install-framework"
$SkillsDir = Join-Path $env:USERPROFILE ".claude/skills"
$Dest = Join-Path $SkillsDir "install-framework"

if (-not (Test-Path $Src)) {
    Write-Host "ERROR: $Src not found. Run this from a clone of claude-code-framework."
    exit 1
}

New-Item -ItemType Directory -Force -Path $SkillsDir | Out-Null
if (Test-Path $Dest) {
    Write-Host "Updating existing global skill at $Dest"
    Remove-Item -Recurse -Force $Dest
}
Copy-Item -Recurse -Force $Src $Dest
Write-Host "Installed /install-framework to $Dest"
Write-Host "It is now available in Claude Code (CLI, desktop, web)."
```

- [ ] **Step 3: Verify the bash installer works against an isolated HOME**

Run:

```bash
HOME=$(mktemp -d) bash install-global-skill.sh && echo "---" && ls "$(HOME=/dev/null; echo)" 2>/dev/null; true
```

Simpler explicit check:

```bash
TESTHOME=$(mktemp -d); HOME="$TESTHOME" bash install-global-skill.sh; test -f "$TESTHOME/.claude/skills/install-framework/SKILL.md" && echo OK || echo MISSING; rm -rf "$TESTHOME"
```

Expected: prints `Installed /install-framework ...` then `OK`.

- [ ] **Step 4: Commit**

```bash
git add install-global-skill.sh install-global-skill.ps1
git commit -m "Add install scripts for the global /install-framework skill"
```

---

### Task 5: Documentation + consistency

**Files:**
- Modify: `README.md`
- Modify: `CLAUDE.md`

- [ ] **Step 1: Document the `CCF_*` interface and `global-skills/` in CLAUDE.md**

In `CLAUDE.md`, under the "Key Conventions" section (after the Placeholder System / before "Adding New Skills"), add:

```markdown
### Non-Interactive Setup (`CCF_*` env vars)

`setup.sh --non-interactive` and `setup.ps1 -NonInteractive` read answers from `CCF_*`
environment variables instead of prompting. This is what the global `/install-framework` skill
drives. Interactive mode remains the default. Variables: `CCF_PROJECT_TYPE` (required),
`CCF_TRACKER`, `CCF_CICD`, `CCF_BASE_BRANCH`, `CCF_NOTIFICATION`, `CCF_PROJECT_SHORT_NAME`,
`CCF_DESIGN_SYSTEM`, plus `CCF_HOSTING_TARGET` / `CCF_STORAGE_PROVIDER` / `CCF_POSTGRES_PROVIDER`
for `internal-nextjs-app`. Non-interactive mode never renames git branches. When adding a new
prompt to the installers, also add its `CCF_*` variable to both the `--non-interactive` resolver
and the resolver in `setup.ps1`.

### Global Skills (`global-skills/`)

`global-skills/` holds account-level skills installed into `~/.claude/skills/` (via
`install-global-skill.sh` / `.ps1`), NOT copied into target repos by `setup.sh`. Currently:
`install-framework`. Because these are not per-repo template skills, they do not count toward the
"26 workflow skills" total.
```

Also update the System Structure tree in `CLAUDE.md` to add, near the top level:

```
├── global-skills/               # Account-level skills (→ ~/.claude/skills/), NOT per-repo
│   └── install-framework/       # /install-framework — bootstrap framework into any repo
├── install-global-skill.sh      # Installs global skills into ~/.claude/skills/
├── install-global-skill.ps1     # PowerShell equivalent
```

- [ ] **Step 2: Document `/install-framework` in README.md**

In `README.md`, add a section describing the global skill. Place it near the existing setup/quick-start instructions:

```markdown
## Global `/install-framework` skill

Install the framework into ANY repo without referencing a local clone path — it pulls from GitHub.

One-time setup (registers the skill into `~/.claude/skills/`, where Claude Code CLI/desktop/web pick it up):

```bash
# from a clone of this repo
bash install-global-skill.sh        # macOS/Linux/Git Bash
pwsh -File install-global-skill.ps1 # Windows
```

Or fetch just the skill without cloning:

```bash
mkdir -p ~/.claude/skills/install-framework
curl -fsSL https://raw.githubusercontent.com/BostonOrange/claude-code-framework/main/global-skills/install-framework/SKILL.md \
  -o ~/.claude/skills/install-framework/SKILL.md
```

Then, in any repo, run `/install-framework`. It detects your project type, asks a few questions,
clones the framework to a temp dir, runs the installer non-interactively, verifies the result, and
cleans up. Afterward, run the per-repo `/setup` for deep configuration.

**`/install-framework` (global) vs `/setup` (per-repo):** `/install-framework` puts the framework
into a repo for the first time. `/setup` refines an already-installed framework (17-layer
detection). They do not overlap.
```

- [ ] **Step 3: Run the full test suite**

Run: `bash tests/run-all.sh`
Expected: ALL TESTS PASSED, including `check-setup-smoke` and the new `check-global-skill`.

- [ ] **Step 4: Commit**

```bash
git add README.md CLAUDE.md
git commit -m "Document /install-framework skill and CCF_* non-interactive interface"
```

---

## Self-Review

**1. Spec coverage:**
- Ephemeral temp clone → SKILL.md step 5 + 8. ✓
- `/install-framework` name → Task 3 frontmatter. ✓
- Non-interactive installers (single source of truth) → Tasks 1 & 2. ✓
- Minimum-then-defer-to-`/setup` → SKILL.md steps 4 & 9. ✓
- `global-skills/` new dir + copy step → Tasks 3 & 4. ✓
- OS detection + prereqs → SKILL.md step 1. ✓
- Idempotency guard → SKILL.md step 2. ✓
- Verify no `{{}}` → SKILL.md step 7 + smoke assertions. ✓
- Testing (extend smoke tests + frontmatter/URL check) → Tasks 1, 2, 3. ✓
- Consistency (CLAUDE.md/README, don't bump 26 count) → Task 5 + explicit note. ✓
- Spec open items: (1) provider/design enums confirmed against `setup.sh` and baked into the `CCF_*` table; (2) installer-script overwrite behavior decided (update-in-place); (3) web-sandbox git/network is a runtime assumption documented in SKILL.md edge cases. ✓

**2. Placeholder scan:** No TBD/TODO/"add error handling" placeholders; all code blocks are complete. ✓

**3. Type/name consistency:** Variable names (`PROJECT_TYPE_NAME`, `BASE_BRANCH`, `DESIGN_SYSTEM_NAME`, etc.) match the existing scripts exactly so downstream config-loading and placeholder replacement keep working. `CCF_*` names are identical across setup.sh, setup.ps1, both smoke tests, and SKILL.md. Skill name `install-framework` is identical in frontmatter, test, install scripts, and docs. ✓
