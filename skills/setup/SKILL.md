---
name: setup
description: First-time onboarding — orchestrates project-setup-detector and project-setup-applier across a confirm checkpoint. Distinct from /improve (ongoing evolution); /setup owns the first-run shape decisions
---

# Setup — First-Time Onboarding

`setup.sh` puts the framework files on disk. `/setup` makes them fit *your* project.

The bash installer can only ask the eight questions it was built around. `/setup` walks 17 layers — language, framework, build, test, type-check, format/lint, persistence, API style, frontend, design system, monorepo, observability, infra, CI/CD, tracker, notification, branch — and uses what's actually in the repo to pre-fill answers. For each layer it can't auto-answer, it shows the options, the tradeoffs, and a recommended default. You pick "default" or pick differently — no research required.

**Lifecycle vs `/improve`:** `/setup` decides shape (first run, or re-baseline). `/improve` keeps shape in tune as the project grows. They don't overlap — `framework-improver` reads the `## Layers owned by /setup` block in `setup-applied.md` and refuses to overwrite values `/setup` decided.

## Usage

```
/setup                    full onboarding pass; detect → propose → confirm → apply
/setup --refresh          re-run all 17 layers using existing values as the baseline
/setup --layer=<name>     re-run a single layer (e.g., /setup --layer=ci-cd)
/setup --dry-run          detect + propose only; do not apply even after confirmation
```

Layer names: `language`, `framework`, `build`, `test`, `type-check`, `format-lint`, `persistence`, `api-style`, `frontend`, `design-system`, `monorepo`, `observability`, `infra`, `ci-cd`, `tracker`, `notification`, `branch`.

## Process

### Phase 1: Detect (read-only)

Spawn `project-setup-detector`:

```
Run your full process. Inventory the repo, classify greenfield vs brownfield,
walk the 17 layers, and write the proposal to .claude/state/setup-proposal.md
following the schema in your Phase 4. Do not apply changes — you don't have
Edit/Write tools. End with the surface summary.
```

The detector is read-only by tool restriction (no Edit/Write). It writes only `.claude/state/setup-proposal.md` (creating `.claude/state/` via `mkdir -p` if missing).

### Phase 2: Present Proposal

Read `.claude/state/setup-proposal.md` and surface a condensed view to the user. Always include both a confirmation prompt for *detected* values (per finding #9 — even brownfield silently auto-accepts is wrong) and explicit asks for `needs-decision` layers.

```markdown
## Setup Proposal

**Mode:** brownfield (Next.js 15 + Postgres detected)
**Backup target:** `.claude/state/setup-backup-<timestamp>/` (created on apply)

### Detected (confirm these are right)
- Language: TypeScript
- Framework: Next.js 15 App Router
- Build: pnpm
- Test: vitest
- Type check: tsc --noEmit
- Format/Lint: eslint + prettier
- Persistence: Drizzle ORM
- API style: REST (Next.js route handlers)
- Frontend: React 18
- Design system: Tailwind + shadcn/ui
- Monorepo: single-repo
- Observability: Sentry
- Infra: Vercel (vercel.json — overrides framework default? no, matches)
- CI/CD: GitHub Actions
- Branch: main

### Conflicts (must resolve)
1. Layer 7 (Persistence) — detection says Drizzle, existing CLAUDE.md mentions Prisma. Pick one.

### Open questions (no detection)
1. Tracker — Azure DevOps / Jira / Linear / GitHub Issues / None?
2. Notification — Slack / Teams / Discord / None?

Reply: "use detected values + Linear + Slack + drop Prisma" — or layer-by-layer.
```

Greenfield mode looks similar but each layer presents 2–4 options with one-sentence tradeoffs, and the proposal ends with bootstrap commands the user runs themselves.

### Phase 3: Collect Decisions

Wait for user reply. Common shapes:
- **"use detected"** — every detected layer takes its detected value; open questions still need answers.
- **"use detected + <answer1> + <answer2>"** — detected plus answers to open questions.
- **Layer-by-layer** — explicit choice per layer.

Update `.claude/state/setup-proposal.md` in place with the resolved values under the existing `## Confirmed by user` section. **Schema (load-bearing — applier reads this exact shape):**

```markdown
## Confirmed by user

| Layer | Final value | Source of decision |
|-------|-------------|--------------------|
| 1 | TypeScript | detected (no override) |
| 2 | Next.js 15 | detected (no override) |
| 7 | Drizzle | user override (rejected Prisma) |
| 15 | Linear | user choice |
| 16 | Slack | user choice |
```

Required columns: `Layer` (number), `Final value` (string), `Source of decision` (one of: `detected (no override)`, `user override (<reason>)`, `user choice`, `n/a`). Every layer with `Status` other than `n/a` in the proposal table must appear here, otherwise the applier will halt at gate 5.

If `--dry-run`, stop here. Print the path to `setup-proposal.md` so the user can inspect.

### Phase 4: Apply

Spawn `project-setup-applier`:

```
--apply mode. Read .claude/state/setup-proposal.md (with the populated `## Confirmed by user` section).
Run all 5 pre-apply gates. If any fail, halt.
Otherwise: snapshot to .claude/state/setup-backup-<ts>/, ensure .gitignore, apply substitutions
per the table, smoke-check, write .claude/state/setup-applied.md.
```

The applier has Edit/Write but refuses to run if `## Confirmed by user` is empty, conflicts are unresolved, the working tree has uncommitted changes to affected files, or any path violates the allowlist.

### Phase 5: Verify

After the applier returns:

1. Run the smoke check yourself (don't trust the agent's report alone):
   ```bash
   grep -r '{{' CLAUDE.md .claude/ 2>/dev/null | grep -vE '\.claude/(state|backup)/' | head -20
   ```
2. Confirm `.claude/state/setup-applied.md` exists and lists files changed.
3. Confirm the backup directory exists (`ls .claude/state/setup-backup-*/`).
4. Show the user:
   - Which files changed
   - Backup location (rollback path if anything is wrong)
   - Which placeholders were intentionally left unfilled (e.g., backend-only keeps `{{DESIGN_*}}`)
   - The next recommended action

### Phase 6: Hand-off

- **Brownfield:** "Run `/develop TICKET-123` to try the dev cycle, or `/team review` to validate the framework picked up your conventions."
- **Greenfield:** "Run the bootstrap command listed in `.claude/state/setup-proposal.md` (under `## Bootstrap commands`). After your first commit, `framework-improver` will keep things in sync as conventions emerge."

## State Files

| File | Owner | Lifecycle |
|------|-------|-----------|
| `.claude/state/setup-proposal.md` | `project-setup-detector` (Phase 1); skill updates `## Confirmed by user` (Phase 3) | Append-only audit |
| `.claude/state/setup-applied.md` | `project-setup-applier` (Phase 4) | Append-only; `framework-improver` reads `## Layers owned by /setup` |
| `.claude/state/setup-backup-<ts>/` | `project-setup-applier` (Phase 4 step 1) | Created every apply; rollback path |

All under `.claude/state/` (the applier ensures `.gitignore` covers it).

## Network Boundary (honest version)

Both the detector and applier are *instructed* not to make network calls — no `npm view`, no `gh api`, no `curl`/`wget`/registry queries. The framework's `guardrails.sh` does not enforce this at the harness level (it blocks destructive ops, not network egress). The agents' tool-list does not include MCP servers that reach the network.

If you're onboarding a sensitive repo, **verify in your transcript** that no network commands were run. The "local-only" property is a contract maintained by the agents' instructions and `docs/project-detection.md`'s "what NOT to run" list — treat it as that, not a sandbox guarantee.

## When to Use `/setup` vs `/improve`

| Situation | Use |
|-----------|-----|
| Just ran `setup.sh` for the first time | `/setup` |
| Re-onboarding after a major stack change (e.g., switched ORMs, migrated framework) | `/setup --refresh` |
| One layer is wrong (e.g., switched npm → pnpm) | `/setup --layer=build` |
| Convention drift after weeks of development | `/improve` |
| Filling specific `{{...}}` placeholders that ended up unset | `/improve claude-md` |
| Adding new rule patterns based on actual file structure | `/improve rules` |

## Edge Cases

| Scenario | Behavior |
|----------|----------|
| `.claude/state/setup-applied.md` already exists | Tell user setup was already run; offer `--refresh` |
| `## Confirmed by user` not populated when applier runs | Applier halts at gate 2 — return to Phase 3 |
| Conflict unresolved when applier runs | Applier halts at gate 3 — surface the conflict, ask user to pick |
| Working tree has uncommitted CLAUDE.md changes | Applier halts at gate 4 — tell user to commit/stash |
| Apply pass leaves unexpected `{{...}}` | Applier halts before writing apply log; backup is intact; user can re-run after fix |
| User aborts during Phase 3 | Proposal stays on disk; next `/setup` continues from it |
| Detector ran but no proposal was written | Skill detects empty `.claude/state/setup-proposal.md` and re-spawns detector |
| Apply succeeds but user wants to revert | `cp -r .claude/state/setup-backup-<ts>/CLAUDE.md ./` and similar for `.claude/` files |

## Related

- `project-setup-detector` agent — runs Phase 1, produces the proposal (read-only by tool removal)
- `project-setup-applier` agent — runs Phase 4, applies with backup + allowlist + audit log
- `docs/project-detection.md` — shared detection bash (used by detector + framework-improver)
- `/improve` — ongoing evolution; reads `setup-applied.md` to respect `/setup`'s decisions
- `framework-improver` agent — what `/improve` spawns
- `setup.sh` / `setup.ps1` — bash/PowerShell installers; `/setup` refines what they generated
