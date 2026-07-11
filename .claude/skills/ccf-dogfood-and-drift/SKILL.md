---
name: ccf-dogfood-and-drift
description: Load when working with claude-code-framework's own .claude/ directory or when tests/check-dogfood-drift.sh fails — symptoms like "Unexpected .claude/template drift", "Stale allowlist entries", "why does .claude/ here not match templates/?", "can I edit config/dogfood-drift-allowlist.txt?", "why is /team design broken in this repo?", or "I added a skill/agent and the drift check went red". Explains the curated dogfood model, the allowlist mechanics in both directions, and the runbooks for adding/modifying/removing anything the check compares.
last_updated: 2026-07-11
tested_with: claude-fable-5
stability: experimental
scope: preset
---

# Dogfood Model and Drift Policing

**Dogfooding** here means: this repo runs a copy of its own product under `.claude/`. But `.claude/` is **not** a `setup.sh` install — it is a hand-curated subset, and every byte of divergence between `.claude/` and the distributable sources is policed by an explicit allowlist (`config/dogfood-drift-allowlist.txt`) enforced by `tests/check-dogfood-drift.sh`.

## Usage

Load this skill when:
- `tests/check-dogfood-drift.sh` fails (unexpected or stale entries).
- You are adding, modifying, or removing anything under `.claude/agents/`, `.claude/hooks/`, `.claude/skills/`, `.claude/statusline/`, or `.claude/settings.local.json`.
- You are adding a **template** skill/agent/hook that will NOT be dogfooded (that also changes the drift surface — see Edge Cases).
- You need to decide: allowlist a divergence, or sync it back to the template?

Do NOT use this skill for:
- The full test-suite anatomy or "am I done?" gating — see **ccf-testing-and-qa**.
- Doc counts/tables (README, CLAUDE.md, AGENTS.md) — see **ccf-doc-sync-campaign**.
- Whether a change may merge at all, commit conventions — see **ccf-change-control**.
- Why the repo separates `templates/` vs `skills/` vs `global-skills/` — see **ccf-architecture-contract**.

## Process: touching anything the drift check compares

### Phase 1 — Classify your change

| You are... | Go to |
|---|---|
| Adding a repo-local file under `.claude/` (skill, agent) | Phase 2 |
| Modifying a dogfooded copy of a template file | Phase 3 |
| Removing anything (either side) | Phase 4 |
| Adding a template-side skill/agent/hook that is NOT dogfooded | Edge Cases table |

### Phase 2 — Add a repo-local skill or agent

```bash
mkdir -p .claude/skills/<name>
# write .claude/skills/<name>/SKILL.md
printf 'Only in .claude/skills: %s\n' '<name>' >> config/dogfood-drift-allowlist.txt
bash tests/check-dogfood-drift.sh
```

For a repo-only agent the line is `Only in .claude/agents: <name>.md` (note `.md` — agents are compared per-file, skills per-directory). The script sorts everything, so line position doesn't matter for correctness — but group lines under the file's existing comment headers for humans.

### Phase 3 — Modify a dogfooded copy of a template file

First check whether the file is currently byte-identical to its template:

```bash
diff -q .claude/agents/<file>.md templates/agents/<file>.md
```

- **Already allowlisted as "differ"** (e.g. `guardrails.sh`, `code-reviewer.md`): the check stays green no matter what you write. The allowlist records only THAT files differ, never HOW — so you must make the flow-back judgment yourself (see "The judgment call" below). No allowlist edit needed.
- **Currently identical** (as of 2026-07-11: `database-architect.md`, `devops-engineer.md`, `session-stop.sh`): your edit creates a NEW drift line. Either make the change in the template and copy it over (preferred if any target project would want it), or add the `Files .claude/... and templates/... differ` line with your reason in the commit message.

### Phase 4 — Remove something

The allowlist must match reality in BOTH directions — the check fails on stale lines too. Deleting `.claude/agents/framework-qa.md` without removing its `Only in .claude/agents: framework-qa.md` line fails with "Stale allowlist entries". A rename produces one unexpected + one stale line; fix both.

### Phase 5 — Verify

```bash
bash tests/check-dogfood-drift.sh   # must print "All dogfood drift is explicitly allowlisted."
bash tests/run-all.sh               # drift check is auto-included via the check-*.sh glob
```

## The dogfood model: what is curated, and why

The curated subset (as of 2026-07-11, all counts verified against the tree):

| Surface | In `.claude/` | Relation to distributable source |
|---|---|---|
| Agents | 12 files | 10 template-derived (8 modified copies; `database-architect.md` + `devops-engineer.md` byte-identical) + 2 repo-only: `framework-improver.md`, `framework-qa.md` |
| Skills | `improve`, `team` (both modified copies of `skills/*`) + the repo-local `ccf-*` knowledge library | Compared against top-level `skills/`, NOT `templates/` |
| Hooks | 5 of the 8 template hooks | 4 modified (`_lib.sh`, `guardrails.sh`, `post-coding-review.sh`, `post-edit-sync.sh`), `session-stop.sh` identical; `codebase-index.sh`, `pre-commit.sh`, `session-start.sh` not dogfooded |
| Rules | 3 repo-specific (`templates.md`, `setup-scripts.md`, `skills.md`) | No relation to `templates/rules/` — never compared |
| Commands | none — no `.claude/commands/` at all | `templates/commands/` not dogfooded |
| Settings/statusline | `settings.local.json` and `statusline/statusline-command.sh` modified; `statusline/README.md` repo-only | Placeholders like `{{DEFAULT_MODEL}}` and the SessionStart hook wiring are dropped/changed for this repo |

**Why curated instead of a full install:** the 29 template agents absent here (reviewer/implementer/coordinator/setup families) target *application code* — React components, API layers, databases. This repo is markdown and bash; those agents have nothing to review. The dogfooded hooks are rewritten for framework semantics (e.g. `.claude/hooks/post-edit-sync.sh` flags README/CLAUDE.md sync needs when `templates/agents/*.md` changes). Divergence is the *point* — the allowlist forces every divergence to be a decision, not an accident.

## Enforcement mechanics: `tests/check-dogfood-drift.sh`

The check diffs exactly five surfaces, strips the absolute repo prefix, sorts, then two-way-compares against the allowlist with `comm`:

1. `diff -qr .claude/agents templates/agents`
2. `diff -qr .claude/hooks templates/hooks`
3. `diff -qr .claude/skills skills` (top-level `skills/`, not `templates/`)
4. `diff -q .claude/settings.local.json templates/settings.local.json`
5. `diff -qr .claude/statusline templates/statusline`

Exact normalized line formats (these are the only strings valid in the allowlist; comments `#` and blank lines are ignored):

```
Files .claude/agents/code-reviewer.md and templates/agents/code-reviewer.md differ
Only in .claude/agents: framework-qa.md
Only in templates/agents: dry-reviewer.md
Only in .claude/skills: ccf-dogfood-and-drift
Only in skills: validate
Only in templates/hooks: pre-commit.sh
```

Failure modes: in reality but not in list → "Unexpected .claude/template drift"; in list but not in reality → "Stale allowlist entries". Either is exit 1.

**What the check does NOT cover** (know the blind spots): `.claude/rules/`, `.claude/settings.json`, `.claude/statusline.json`, `CLAUDE.md`, the absence of `.claude/commands/`, and — critically — the *content* of any file already allowlisted as "differ". A broken edit to `guardrails.sh` sails through green.

## The judgment call: allowlist vs flow back

Litmus test: **"Would a target project want this change?"**

- **Yes** → it belongs in `templates/` (or `skills/`). Edit the template first, then decide whether the dogfooded copy needs the same change applied on top of its repo-specific diffs. Allowlisting it in `.claude/` only is papering over drift — the improvement dies in this repo.
- **No, it's repo-specific** (framework-file semantics, repo-only agents like `framework-qa`, the `ccf-*` knowledge library, dropped placeholders) → allowlist it, with the reason in the commit message and grouped under a comment header in the allowlist file (the file format supports `#` comments; lines themselves carry no reason field).
- **Never** add an allowlist line purely to turn the check green. The check exists to force this exact decision.

Because "differ" lines hide content, files that diverge for one reason silently accumulate others. When touching any allowlisted "differ" pair, `diff` it against its template and confirm every hunk is still intentional.

## Trap: the reduced roster vs advertised teams

`.claude/agents/` has 12 agents; `templates/agents/` has 39. The dogfooded `.claude/skills/team/SKILL.md` was curated to match (teams: review, architecture, release, quality, documentation, full, custom — no `review-deep`, `quality-deep`, or `design`, which exist only in the template `skills/team/SKILL.md`). But the repo's own `CLAUDE.md` "Agent Teams" table still advertises `/team design` with `frontend-architecture-reviewer` — an agent absent from `.claude/agents/` (as of 2026-07-11). That invocation works in target projects and fails here. Trust `.claude/skills/team/SKILL.md` + `ls .claude/agents/` over the CLAUDE.md table when spawning teams *in this repo*.

Open/candidate finding (as of 2026-07-11, not fixed): the dogfooded team skill's "Available Agents" table lists 11 agents but says "All agents (12)" — `framework-qa` is missing from the table. Doc-table fixes belong to **ccf-doc-sync-campaign**.

Also note: template `/team full` claims 16 agents (a number ccf-doc-sync-campaign drift #6 flags as unverified — enumerate the roster before trusting it); dogfooded `/team full` = 12. The two copies drift independently and only *that* they differ is policed — when improving the template team skill, consciously decide whether the curated copy needs the same edit.

## Worked example: the ccf-* skill library (as of 2026-07-11)

This very library is live drift. Mid-session on 2026-07-11, with six `ccf-*` skill directories created and no allowlist lines yet, running the check printed `Unexpected drift entries: 6` with lines like `Only in .claude/skills: ccf-architecture-contract`, then `FAILED` (verified by running it). The fix is one `Only in .claude/skills: ccf-<name>` line per skill (including this one), then a green re-run. These are legitimate entries under the litmus test: repo-specific knowledge, never shipped to targets.

## Edge Cases

| Situation | What to do |
|---|---|
| Added a new **template** skill under `skills/` (not dogfooded) | It shows as `Only in skills: <name>` — add that line. All 26 non-dogfooded template skills are individually allowlisted this way (verified count as of 2026-07-11). |
| Added a new **template** agent/hook (not dogfooded) | Same pattern: `Only in templates/agents: <name>.md` / `Only in templates/hooks: <name>.sh`. |
| Check reports one unexpected AND one stale entry | Almost always a rename — update both lines. |
| Allowlist line looks right but still fails | Whitespace: `comm` compares exact bytes; a trailing space makes the line both stale and its real twin unexpected. |
| Edited an already-"differ" file, check is green | Green proves nothing about content. Run the full `diff` against the template and self-review every hunk for flow-back. |
| Want to dogfood a currently-excluded template file | Copy it in unmodified → its `Only in templates/...` line becomes stale; remove that line. If you then modify it, add a `Files ... differ` line. |
| Tempted to edit a `.claude/` file to silence a failure elsewhere | Check **ccf-change-control** first — allowlist edits are change-controlled, not an escape hatch. |

## Related Skills

- **ccf-testing-and-qa** — anatomy of the whole `tests/run-all.sh` suite; load when other checks fail or before claiming done.
- **ccf-change-control** — whether an allowlist edit is a legitimate part of your change; merge gating and commit conventions.
- **ccf-doc-sync-campaign** — fixing the count/table drift this skill only flags (e.g. the team-skill 11-vs-12 finding).
- **ccf-architecture-contract** — why `.claude/`, `templates/`, `skills/`, `global-skills/` are separate at all.
- **ccf-domain-reference** — vocabulary: what skills/agents/hooks/teams are; current counts.

## Provenance and maintenance

Every claim above re-verifies with one command (run from repo root):

- Check behavior + current status: `bash tests/check-dogfood-drift.sh`
- Compared surfaces + line normalization: `cat tests/check-dogfood-drift.sh` (5 diff calls, `sed` prefix-strip, `comm -23`/`-13`)
- Dogfooded agent count (12): `ls .claude/agents/*.md | wc -l`
- Template agent count (39): `ls templates/agents/*.md | wc -l`
- Which dogfooded agents are byte-identical: `for f in .claude/agents/*.md; do diff -q "$f" "templates/agents/$(basename "$f")" >/dev/null 2>&1 && echo "identical: $f"; done`
- Dogfooded hook count (5): `ls .claude/hooks/*.sh | wc -l`; template hooks (8): `ls templates/hooks/*.sh | wc -l`
- Non-dogfooded template-skill allowlist lines (26): `grep -c '^Only in skills:' config/dogfood-drift-allowlist.txt`
- Reduced team roster: `grep -n 'design\|review-deep\|quality-deep' .claude/skills/team/SKILL.md skills/team/SKILL.md`
- CLAUDE.md still advertises `/team design` here: `grep -n 'team design' CLAUDE.md`
- Drift check runs in the suite: `grep -n 'check-\*.sh' tests/run-all.sh` (glob pickup, not an explicit list)

Re-verify this skill whenever a commit touches `tests/check-dogfood-drift.sh`, `config/dogfood-drift-allowlist.txt`, anything under `.claude/`, or adds/removes entries in `templates/agents|hooks|statusline`, `templates/settings.local.json`, or `skills/`.
