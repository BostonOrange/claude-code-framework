# Troubleshooting

Common issues and solutions when using the Claude Code Framework.

## Hooks Not Firing

**Symptom:** Lifecycle hooks (guardrails, pre-commit, session-start, etc.) don't run.

**Common causes (in order of likelihood):**

1. **Invalid event name in `settings.local.json`.** Claude Code validates event names against its schema. `SessionStop` is rejected silently — use `SessionEnd` or `Stop`. Valid events: `PreToolUse`, `PostToolUse`, `UserPromptSubmit`, `SessionStart`, `SessionEnd`, `Stop`, `SubagentStart`, `SubagentStop`, `PreCompact`, `PostCompact`.
2. **Missing JSON parser.** Hooks read tool input as JSON from stdin via `jq` or `python3`. If both are missing, `guardrails.sh` soft-blocks every Bash command with an instructive message; `post-edit-sync.sh` and `post-coding-review.sh` silently no-op. Install jq (`brew install jq` / `apt install jq` / Chocolatey on Windows).
3. **`_lib.sh` missing from `.claude/hooks/`.** The shared library is sourced by `guardrails.sh` and `post-edit-sync.sh`. If absent, `guardrails.sh` soft-blocks with "_lib.sh not found" message. Re-run setup.
4. **Hook not wired.** Scripts in `.claude/hooks/` don't fire until they're registered under the matching event in `.claude/settings.local.json`.
5. **Missing execute permission.** On Unix: `chmod +x .claude/hooks/*.sh`.

**Debug procedure:**
```bash
# 1. Confirm the hook script is syntactically OK and accepts a test payload
echo '{"tool_input":{"command":"ls"}}' | bash .claude/hooks/guardrails.sh
echo "exit: $?"

# 2. Confirm the hook is wired to a valid event
grep -A5 '"hooks"' .claude/settings.local.json

# 3. For post-edit-sync, send a tool_input.file_path payload
echo '{"tool_input":{"file_path":"src/foo.ts"}}' | bash .claude/hooks/post-edit-sync.sh
```

## Test Suite Failures (`bash tests/run-all.sh`)

**Symptom:** The framework's own test suite (`check-*.sh` scripts) reports failures.

The suite runs 5 scripts. Each one targets a specific drift surface:

| Test | What it checks | Most common failure mode |
|------|---------------|-------------------------|
| `check-consistency.sh` | File counts match across README, CLAUDE.md, setup.sh, setup.ps1 | Added a new skill/agent/rule/hook but forgot to bump count in one of those files |
| `check-placeholders.sh` | Every `{{PLACEHOLDER}}` in templates has a replacement in both setup.sh AND setup.ps1 | Added a placeholder to templates but only mapped it in one script |
| `check-agent-registry.sh` | `config/agents.json` matches agent frontmatter byte-for-byte, every agent referenced in README/CLAUDE.md.template/docs/teams.md/docs/agents-commands-rules.md | Changed an agent description in frontmatter but not the registry (or vice-versa); forgot to name a new agent in a downstream doc |
| `check-guardrails.sh` | Runs 55 test cases against `templates/hooks/guardrails.sh` (soft-block / hard-block / safe commands + bypass patterns) | Added a new guardrail regex that unintentionally blocks a benign command, or removed a block |
| `check-templates.sh` | Frontmatter validity, placeholder naming conventions in templates | Added a new agent/skill with malformed YAML |

**Debug procedure:** Run each failing test in isolation — output tells you exactly which entry mismatched and what the expected value was:
```bash
bash tests/check-placeholders.sh
bash tests/check-agent-registry.sh 2>&1 | grep FAIL
```

## `post-coding-review.sh` Never Nudges

**Symptom:** You finished a coding session with substantial changes but no review recommendation appeared.

**Likely causes:**

1. **Base branch not locally tracked.** The hook does `git rev-parse --verify {{BASE_BRANCH}}` and silently exits if base doesn't exist locally. On fresh clones of a non-default-branch checkout, fetch the base: `git fetch origin {{BASE_BRANCH}}:{{BASE_BRANCH}}`.
2. **Cooldown active.** The hook writes `{repo-root}/.claude/state/last-review-nudge` after firing and skips repeat nudges for the same branch+HEAD. New commits re-enable it.
3. **Below thresholds.** Default: 3+ source files OR 50+ changed LOC (insertions + deletions). Edits confined to `*.md`, `*.txt`, lockfiles, `.gitignore` don't count.
4. **On base branch.** The hook exits immediately if you're on `{{BASE_BRANCH}}`.
5. **Symlink detected.** If `.claude/state/` or `.claude/state/last-review-nudge` is a symlink, the hook refuses to write (security hardening) and exits silently.

**Force a manual nudge** to verify the hook fires: delete `.claude/state/last-review-nudge` and trigger a SessionEnd event.

## `framework-qa` Reports Drift

**Symptom:** Running the `framework-qa` agent (or the QA step at session end) reports inconsistencies across README / CLAUDE.md / CLAUDE.md.template / docs.

**Fix:** Run `/improve` first (it spawns `framework-improver-detector` → `framework-improver-applier`, the mutating pair). `framework-qa` is read-only and only verifies. The improver pair edits docs to bring them back in line with actual file state; the QA agent re-runs and confirms the fix.

## Unreplaced `{{...}}` Placeholders After Setup

**Symptom:** Files in `.claude/` still contain `{{PLACEHOLDER}}` tokens after running setup.

**Causes:**
- `python3` is not installed or not on PATH. The setup scripts use Python for multi-line placeholder replacement.
- Setup was interrupted before placeholder replacement completed.

**Fix:**
1. Verify Python 3 is available: `python3 --version` (or `python --version` on Windows)
2. Re-run setup with `--reset` to overwrite existing files: `bash setup.sh`
3. After setup, check for remaining placeholders: `grep -r "{{" .claude/ CLAUDE.md | grep -v ".git"`
4. Run `/improve` to auto-fill project-specific values from your codebase

## Windows Path Issues

**Symptom:** Setup or hooks fail with path-related errors on Windows.

**Cause:** The framework uses Unix-style shell scripts. Windows CMD does not support Bash syntax.

**Fix:**
- Use **Git Bash** or **PowerShell** (via `setup.ps1`), never CMD
- If using Git Bash, ensure it is a recent version (2.40+)
- For PowerShell, run `setup.ps1` directly: `& ~/Developer/claude-code-framework/setup.ps1`
- Paths in hook scripts use forward slashes; Git Bash handles translation automatically

## MCP Server Connection Issues

**Symptom:** Context7 or other MCP servers fail to connect. Errors like "spawn npx ENOENT" or timeouts.

**Causes:**
- `npx` is not installed or not on PATH
- Network connectivity issues (MCP servers fetch packages on first run)
- Version mismatch in `.mcp.json`

**Fix:**
1. Verify Node.js and npm are installed: `node --version && npm --version`
2. Test npx directly: `npx @upstash/context7-mcp@latest`
3. Check `.mcp.json` at project root for correct server configuration
4. If behind a corporate proxy, configure npm proxy settings
5. Pin a specific version in `.mcp.json` if `@latest` is unstable

## Agent Spawning Failures

**Symptom:** `/team` or agent invocations fail or agents don't produce output.

**Causes:**
- The specified model is not available in your Claude plan
- Permission issues in `settings.local.json` or `settings.json`
- Agent definition file is malformed (bad YAML frontmatter)

**Fix:**
1. Check agent definitions in `.claude/agents/` for valid YAML frontmatter (`name`, `description`, `tools`, `model`)
2. Verify your Claude plan supports the `opus` model (agents default to opus)
3. Check `settings.json` and `settings.local.json` for tool permissions -- agents need their listed tools to be allowed
4. Try invoking a single agent before running a full team

## Setup Fails Midway

**Symptom:** `setup.sh` or `setup.ps1` exits with an error before completing.

**Causes:**
- Missing prerequisites (python3, git)
- Target directory is not a git repository
- Existing files conflict with setup

**Fix:**
1. Ensure prerequisites are installed: `git --version && python3 --version`
2. Initialize git if needed: `git init`
3. Re-run setup. The script will overwrite existing framework files
4. On PowerShell, ensure execution policy allows scripts: `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned`

## Design System Rule Not Prompted

**Symptom:** The `design-system` rule does not activate when editing UI components.

**Cause:** The design system rule is only installed for frontend project types (`react`, `nodejs`). Backend-only project types (`python`, `go`, `java`) skip it during setup.

**Fix:**
- This is intentional. If you have a backend project with a frontend component, manually copy `templates/rules/design-system.md` to `.claude/rules/design-system.md`
- Run `/scaffold-design-system` to generate design tokens and theme configuration
