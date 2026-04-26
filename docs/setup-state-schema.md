# Setup State Schema

Canonical schema for `.claude/state/setup-proposal.md` and `.claude/state/setup-applied.md`. Used by:
- `templates/agents/project-setup-detector.md` — writes the proposal
- `skills/setup/SKILL.md` — collects user decisions, populates `## Confirmed by user`
- `templates/agents/project-setup-applier.md` — reads and validates before apply
- `templates/agents/framework-improver.md` — reads `## Layers owned by /setup` from `setup-applied.md`

When you find yourself describing column names, status values, or section structure in any of those files, **add it here and reference this file** instead of duplicating. Drift between these specs has caused silent bugs (status-value mismatch, section-name typos that fail silently at gate 2).

## `setup-proposal.md` schema

```markdown
# Project Setup Proposal — <ISO timestamp>

**Mode:** greenfield | brownfield
**Working directory:** <abspath>

## Inventory summary
<short paragraph: detected language, framework, deps count, infra signal>

## Pre-apply checks
- [ ] `.claude/state/` in `.gitignore` (status: yes | no)
- [ ] CLAUDE.md backup target: `.claude/state/setup-backup-<ISO timestamp>/`
- [ ] git working tree status: <clean | dirty — applier will halt unless `Apply on dirty: yes` is set below>

**Apply on dirty:** no  *(optional override — set to `yes` only if the user has intentional uncommitted CLAUDE.md edits they want `/setup` to apply on top of)*

## Layers — proposal table

| # | Layer | Detected | Recommended | Options | Source | Status |

Required columns:
- `#` (integer, layer number 1–17)
- `Layer` (string, layer name from the canonical 17-layer list)
- `Detected` (string or `—`)
- `Recommended` (string)
- `Options` (string, slash-separated alternatives)
- `Source` (string, what evidence drove the detection)
- `Status` (one of: `detected`, `needs-confirmation`, `needs-decision`, `n/a` — see status-value table below)

## Conflicts
- **Layer N (<name>):** detection says `<X>`, existing CLAUDE.md says `<Y>`. Pick one.

## Open questions
- **<layer name>** — <question>

## Substitutions
| Placeholder | Value | In file |
Required columns: `Placeholder`, `Value`, `In file`.

**The unique set of `In file` values IS the affected-files allowlist.** A separate `## Affected files` section was previously specified but caused drift (substitutions referencing files not in the affected list, and vice versa). The applier derives the affected-files set from this table. Each `In file` value must pass the allowlist regex below.

## Bootstrap commands
\`\`\`bash
<commands the user runs themselves; greenfield only — n/a otherwise>
\`\`\`

## Confirmed by user
| Layer | Final value | Source of decision |
Required columns: `Layer` (integer), `Final value` (string), `Source of decision` (one of:
  `detected (no override)`, `user override (<reason>)`, `user choice`, `n/a`).

Initially empty; the `/setup` skill populates it during Phase 3 from user replies. Applier gate 2 fails if the section is missing or empty.
```

## `setup-applied.md` schema

```markdown
# Setup Applied — <ISO timestamp>

**Mode:** greenfield | brownfield
**Backup:** `.claude/state/setup-backup-<timestamp>/`
**Proposal source:** `.claude/state/setup-proposal.md`

## Files changed
- `<path>` (placeholders filled: <count>)

## Layers owned by /setup
| # | Layer | Final value |
Required columns: `#` (integer), `Layer` (string), `Final value` (string).
**`framework-improver` reads this table to build its skip-list.** Adding/removing rows here directly affects what `/improve` may overwrite.

## Intentionally unfilled
- `{{<PLACEHOLDER>}}` — <reason>

## Recovery
<bash snippet using $BACKUP/manifest.txt — see project-setup-applier.md Step 1 for manifest format>

## Next action
<one-line hand-off>
```

## Path allowlist (canonical regex — used by applier gate 5)

The applier validates every path in the `In file` column of `## Substitutions` (and any path referenced in proposal sections that imply file writes) against this two-step check:

**Step a — string-level pre-filter (reject if any of these are present):**
- `..`
- `\` (backslash)
- NUL byte (`\0`), `\r`, `\n`
- Leading `/` (absolute path)
- Leading `~` (home expansion)

**Step b — anchored regex match:**

```
^(CLAUDE\.md|\.gitignore|\.env\.example|\.claude/settings\.local\.json|\.claude/(rules|skills|state)/[^/].*)$
```

Both `framework-improver-applier` and `project-setup-applier` enforce this same regex. Updates land here first, then propagate to both appliers.

## Status values (load-bearing)

| Value | Meaning | Must appear in `## Confirmed by user`? |
|-------|---------|----------------------------------------|
| `detected` | Confidently detected from manifest/lockfile/config | Yes — `Source of decision: detected (no override)` (or user-override row if user disagreed) |
| `needs-confirmation` | Detected but the framework wants explicit OK (e.g., greenfield mode, or a layer where defaults are sensitive — tracker, notification, design system) | Yes — `Source of decision: user choice` or `detected (no override)` |
| `needs-decision` | Detection silent; user must pick | Yes — `Source of decision: user choice` |
| `n/a` | Layer doesn't apply (e.g., no API style for a CLI tool) | No |

**Applier gate 2 halts** if any layer with `Status` other than `n/a` is missing from `## Confirmed by user`. This is what catches the `needs-confirmation` slip-through bug.

## Layer-to-placeholder mapping (canonical)

`framework-improver` reads `## Layers owned by /setup` and uses this mapping to build its `OWNED_PLACEHOLDERS` skip-list.

| # | Layer | Placeholders affected |
|---|-------|----------------------|
| 1 | Language | `{{TECH_STACK_TABLE}}`, `{{SOURCE_PATTERNS}}`, `{{TYPE_CHECK_COMMAND}}` |
| 2 | Framework | `{{API_ROUTE_PATTERNS}}`, `{{COMPONENT_PATTERNS}}`, code structure |
| 3 | Build / package mgr | command prefixes for `{{TEST_COMMAND}}`, `{{FORMAT_COMMAND}}`, `{{TYPE_CHECK_COMMAND}}` |
| 4 | Test runner | `{{TEST_COMMAND}}`, `{{TEST_PATTERNS}}` |
| 5 | Type checker | `{{TYPE_CHECK_COMMAND}}` |
| 6 | Format / lint | `{{FORMAT_COMMAND}}`, `{{FORMAT_VERIFY_COMMAND}}` |
| 7 | Persistence / ORM | `{{DATABASE_PATTERNS}}` |
| 8 | API style | `{{API_ROUTE_PATTERNS}}` |
| 9 | Frontend framework | `{{COMPONENT_PATTERNS}}` |
| 10 | Design system | `{{DESIGN_COLOR_RULES}}`, `{{DESIGN_COMPONENT_IMPORTS}}`, `{{DESIGN_ICON_USAGE}}`, `{{DESIGN_CARD_PATTERNS}}`, `{{DESIGN_DARK_MODE}}` |
| 11 | Monorepo tooling | glob patterns inside `{{SOURCE_PATTERNS}}` and rule patterns |
| 12 | Observability | observability rule patterns, `{{ERROR_TRACKING_PATTERN}}` |
| 13 | Infra / deploy | `{{DEPLOY_COMMAND}}`, `{{DEPLOY_VALIDATE_COMMAND}}` |
| 14 | CI/CD platform | `workflows/` install path, `{{FACTORY_LOCAL_VALIDATION}}` |
| 15 | Tracker | `{{TRACKER_*}}` family, `{{TRACKER_CONFIG}}` |
| 16 | Notification | `{{NOTIFY_*}}` family |
| 17 | Branch strategy | `{{BASE_BRANCH}}` |

When new layers are added, update this table AND the layer table in `project-setup-detector.md`.

## When to update this file

1. A new schema field is added/removed/renamed in proposal or applied state.
2. A new `Status` value is introduced.
3. A new layer is added (also update the layer-to-placeholder mapping).
4. A consuming component (skill, agent) changes how it reads/writes one of these files.
