# Agent Patterns — When to Use Which

The framework has 38 agents across three orchestration patterns. New agents should fit one of these patterns; if a new pattern emerges, add it here.

## 1. Single-pass agent

**One agent, one job, no checkpoint.** The agent reads, possibly writes, returns a report. Most agents fall here.

**Tools:** depends on job. Read-only review agents have `Read, Glob, Grep, Bash`; implementation agents add `Edit, Write`.

**Examples:**
- All review specialists (`code-reviewer`, `security-auditor`, `crypto-reviewer`, etc.)
- All planning specialists (`requirements-clarifier`, `scope-decomposer`, etc.)
- Single-purpose tools (`test-writer`, `documentation-writer`)

**When to use:** the work fits in one spawn. No human gate in the middle. No state needs to outlive the spawn.

## 2. Coordinator with Agent tool

**One coordinator agent that spawns parallel sub-agents and synthesizes their output.** Used when sub-tasks are independent and benefit from parallelization.

**Tools:** `Read, Glob, Grep, Bash, Agent`. The `Agent` tool is the distinguishing feature — coordinators delegate; non-coordinators don't.

**Examples:**
- `review-coordinator` — spawns parallel reviewer agents, dedupes findings, persists state
- `planner-coordinator` — spawns planning specialists in waves, synthesizes one plan
- `build-coordinator` — sequences build phases, spawns one specialist per phase

**When to use:** the work decomposes into independent sub-tasks; running them in parallel is meaningfully faster; output needs to be merged/dedup'd/synthesized.

## 3. Detector + Applier pair

**Two agents separated by a checkpoint (user confirmation, time delay, or skill orchestration).** The detector is read-only by tool restriction (no `Edit`/`Write`); the applier has write tools but is gated by pre-apply checks. State survives across the checkpoint via a proposal file.

**Detector tools:** `Read, Glob, Grep, Bash`.
**Applier tools:** `Read, Edit, Write, Bash`.

The two agents are *paired* — they share a state-file contract documented in a schema doc. They are orchestrated by a skill, not by the detector itself.

**Examples:**
- `project-setup-detector` + `project-setup-applier` (orchestrated by `/setup`) — onboarding
- `framework-improver-detector` + `framework-improver-applier` (orchestrated by `/improve`) — ongoing tuning

**When to use:**
- Read/write separation is load-bearing for safety (the agent shouldn't be able to write during the detect phase, even if it tried).
- A checkpoint exists between detect and apply: user confirmation, skip-list filtering, schema validation, etc.
- State outlives a single spawn (the proposal file).

**When NOT to use:**
- The work is autonomous end-to-end and a single agent suffices — don't add a checkpoint just to look uniform.
- The "applier" would always run immediately after the detector with no validation in between — the split adds files for no safety benefit.

## How to add a new pair

If you find yourself wanting a third detector/applier pair:

1. Create `<name>-detector.md` and `<name>-applier.md` in `templates/agents/`.
2. The detector frontmatter `tools:` line MUST omit `Edit` and `Write`. The applier frontmatter MUST include them.
3. Both files reference `docs/applier-pattern.md` for the canonical gate template, manifest format, recovery bash, and smoke-check pattern. Don't drift from the pattern doc — domain-specific gate prose can sit in the agent file as long as it cites the canonical spec by section name (e.g., "per `docs/applier-pattern.md` Lockfile spec"). The user-facing apply-log template legitimately embeds the recovery bash inline so the rendered `setup-applied.md` / `improve-applied.md` is self-contained.
4. Define the proposal + applied state-file schema in `docs/setup-state-schema.md` (or a new schema doc if the new pair's state is structurally different).
5. The orchestrating skill goes in `skills/<name>/SKILL.md` and spawns: detector → present (if user gate) → applier.
6. Cross-link the pair in each file's frontmatter description and in a `## Paired with` section near the top of each agent body.
7. Update `config/agents.json`, README, CLAUDE.md template, docs/teams.md, docs/agents-commands-rules.md, docs/architecture.md (the standard agent-add consistency surfaces).

## Why three patterns and not more

Each pattern earns its place by structurally enforcing a property the others can't:

| Pattern | Structural property |
|---------|---------------------|
| Single-pass | Simplicity — minimum file count, easiest to understand |
| Coordinator | Parallelism + synthesis — output dedup is centralized |
| Detector + Applier pair | Read/write separation across a checkpoint — write capability is gated by structure, not prose |

Fit new work into one of the three unless a genuinely different structural property is needed. Adding a fourth pattern is a meaningful framework change — discuss before implementing.
