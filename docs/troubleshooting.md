# Troubleshooting

Common issues and solutions when using the Claude Code Framework.

## Hooks Not Firing

**Symptom:** Lifecycle hooks (guardrails, pre-commit, session-start, etc.) don't run.

**Cause:** Hooks must be wired in `settings.local.json` under the `hooks` section. Simply placing `.sh` files in `.claude/hooks/` is not enough.

**Fix:**
1. Open `.claude/settings.local.json`
2. Verify the `hooks` section maps each hook event to the correct script path
3. Ensure hook scripts have executable permissions (`chmod +x .claude/hooks/*.sh`)

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
