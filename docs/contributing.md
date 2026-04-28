# Contributing to claude-code-framework

This guide explains how to safely extend and modify the framework.

## Repository model

This repo is the **framework itself**, not a target project. `setup.sh` / `setup.ps1` copy files from here into a target project's `.claude/` directory. Do not run `setup.sh` inside this repo.

The framework has two sides:
- `templates/`, `skills/`, `workflows/`, `config/` — files that get distributed to target projects via setup
- `.claude/`, `CLAUDE.md`, `docs/`, `tests/` — framework-repo-only tooling

When editing anything under `templates/` or `skills/`, you're changing what every future install ships with.

## The parity rule

**`setup.sh` and `setup.ps1` must stay in lockstep.** Every prompt, placeholder mapping, copy operation, and summary line in one must exist in the other. The rule is codified in `.claude/rules/setup-scripts.md`.

Enforcement:
- `tests/check-placeholders.sh` validates every `{{PLACEHOLDER}}` in templates has a replacement in **both** scripts
- `tests/check-consistency.sh` validates file counts match across README, CLAUDE.md template, setup scripts, and docs
- `tests/check-agent-registry.sh` validates `config/agents.json` matches agent frontmatter and every agent is referenced in docs

Run the full suite before submitting a PR:

```bash
bash tests/run-all.sh
```

## Adding a new skill

1. Copy `skills/_template/` to `skills/your-skill-name/`
2. Edit `SKILL.md` — frontmatter must include `name` and `description`. See `docs/skill-authoring.md` for conventions.
3. Update:
   - `README.md` skills table
   - `templates/CLAUDE.md.template` Skills Available table
   - `docs/architecture.md` file tree (if structurally visible)
   - `setup.sh` and `setup.ps1` summary lines (if the skill count changes)
4. Run `bash tests/run-all.sh` — `check-consistency.sh` will flag count mismatches.

## Adding a new agent

1. Create `templates/agents/your-agent.md` with frontmatter: `name`, `description`, `tools`, `model`.
2. Add an entry to `config/agents.json` — include `name`, `category`, `model`, `blurb`, `description`. The `description` must be **byte-identical** to the frontmatter description.
3. Update:
   - `README.md` agent table
   - `templates/CLAUDE.md.template` Agents Available tables
   - `docs/teams.md` — add to appropriate team(s)
   - `docs/agents-commands-rules.md` agent table
   - `skills/team/SKILL.md` — if the agent belongs to a pre-defined team
4. Run `bash tests/check-agent-registry.sh` — validates all 5 doc locations reference the agent.

## Adding a new rule

1. Create `templates/rules/your-rule.md` with frontmatter: `patterns` array (file globs).
2. Use `{{PLACEHOLDER}}` syntax for project-specific patterns — every placeholder needs a mapping in **both** setup scripts.
3. If the rule should be skipped for certain project types (e.g., backend-only), add the skip logic to `setup.sh` (lines ~479–497) AND `setup.ps1` equivalent.
4. Update:
   - `README.md` rules table
   - `docs/agents-commands-rules.md` rules table
5. Run `bash tests/check-placeholders.sh` to verify no orphan placeholders.

## Adding a new hook

1. Create `templates/hooks/your-hook.sh`. Shebang: `#!/bin/bash`. Handle missing input gracefully.
2. **Hooks receive input as JSON on stdin**, not via environment variables or command-line args. Use `jq` if available, else `python3`. See existing hooks for the pattern:

   ```bash
   if command -v jq >/dev/null 2>&1; then
       FILE_PATH=$(jq -r '.tool_input.file_path // empty' 2>/dev/null)
   elif command -v python3 >/dev/null 2>&1; then
       FILE_PATH=$(python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('tool_input',{}).get('file_path',''))" 2>/dev/null)
   else
       exit 0
   fi
   ```

3. Wire the hook in `templates/settings.local.json` under the correct event. **Valid events** (per Claude Code schema): `PreToolUse`, `PostToolUse`, `PostToolUseFailure`, `UserPromptSubmit`, `SessionStart`, `SessionEnd`, `Stop`, `SubagentStart`, `SubagentStop`, `PreCompact`, `PostCompact`, and others. Do **not** use `SessionStop` — it's invalid and hooks wired to it silently never fire.
4. Exit codes: `0` = allow, `1` = soft block (prompt user), `2` = hard block (deny).
5. Update:
   - README hooks table
   - `docs/agents-commands-rules.md` hooks table
   - Both setup script summary lines (if hook count changes)

## Adding a new placeholder

1. Add it to the template/skill/rule where needed as `{{YOUR_PLACEHOLDER}}` (UPPER_SNAKE_CASE).
2. Add replacement logic to **both** setup scripts:
   - `setup.sh` — add to the Python replacement dict around line 535 (for files under `.claude/`) AND/OR the CLAUDE.md replacement dict around line 661 (for CLAUDE.md itself)
   - `setup.ps1` — add `$claudeContent = $claudeContent.Replace('{{YOUR_PLACEHOLDER}}', $YourValue)` or add to the main placeholder map
3. Document it in `CLAUDE.md` under "Key Conventions → Common placeholders".
4. Run `bash tests/check-placeholders.sh`.

## Testing your changes

```bash
# Full suite
bash tests/run-all.sh

# Targeted
bash tests/check-consistency.sh     # file counts + tables match
bash tests/check-placeholders.sh    # every placeholder has replacement in sh+ps1
bash tests/check-agent-registry.sh  # agent JSON + frontmatter + doc refs
bash tests/check-templates.sh       # template structural validity
bash tests/check-guardrails.sh      # guardrails.sh hook patterns
bash tests/check-setup-smoke.sh     # Bash setup end-to-end smoke
bash tests/check-dogfood-drift.sh   # self-hosted .claude/ drift policy
pwsh -File tests/check-setup-smoke.ps1  # PowerShell setup smoke (Windows CI)
```

For end-to-end validation, run setup against a throwaway directory:

```bash
mkdir /tmp/test-project && cd /tmp/test-project && git init
bash ~/path-to/claude-code-framework/setup.sh
# Verify: all files copied, placeholders replaced, no {{...}} remaining
grep -r "{{" .claude/ CLAUDE.md | grep -v ".git"
```

## Self-improvement workflow

When you edit framework files, the `framework-improver` agent (framework-repo-only, not distributed) can update downstream docs when explicitly invoked. From CLAUDE.md:

> **Before ending any session where framework files were modified**, spawn the `framework-improver` agent in the background. Additionally, run the `framework-qa` agent to validate that all counts and tables are consistent.

```bash
# In a Claude Code session:
# "Run framework-improver and framework-qa on the recent changes."
```

No hidden hook mutates files at session end. Hooks only provide guardrails and advisory reminders; the agents are an explicit contributor workflow and `tests/run-all.sh` is the deterministic gate.

## Known parity drifts (tracked)

- **Dry-run behavior** — `setup.sh` consolidates dry-run output into a preview block at line 269 then exits. `setup.ps1` interleaves `if (-not $DryRun)` checks throughout. Both produce correct output but the shapes differ. Low risk; refactoring deferred until a user hits a real divergence.
- **Dogfood config** — this repo's own `.claude/` files intentionally differ from distributable templates in a few places (`framework-qa`, framework-specific hooks, and narrowed self-hosted skills). Keep `config/dogfood-drift-allowlist.txt` in sync when a difference is intentional.

## PR checklist

- [ ] Both `setup.sh` and `setup.ps1` updated if adding prompts / placeholders / copy operations
- [ ] `tests/run-all.sh` passes locally (all 7 Bash suites green)
- [ ] PowerShell setup smoke passes in CI, or locally with `pwsh -File tests/check-setup-smoke.ps1`
- [ ] Agent/skill/rule/hook count changes reflected in README, CLAUDE.md template, setup summaries, and docs
- [ ] No literal `{{...}}` in target-project output (run setup in a throwaway dir and grep)
- [ ] Commit message follows `Add | Fix | Update | Remove` prefix convention
