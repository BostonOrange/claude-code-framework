# Finding Schema

The standard shape for review findings emitted by every reviewer agent (`code-reviewer`, `security-auditor`, `ui-ux-reviewer`, `performance-optimizer`, etc.) and consumed by the `review-coordinator`.

A consistent schema lets the coordinator dedupe across agents, persist state across iterations, and track resolution status when the developer pushes new commits.

## Schema

Every finding is a record with these fields:

| Field | Required | Type | Description |
|-------|----------|------|-------------|
| `id` | Yes | string | Stable hash key: `{file}:{line}:{rule_id}:{short-fingerprint}` — used for dedup and cross-iteration matching |
| `severity` | Yes | enum | `critical` \| `important` \| `suggestion` \| `nit` |
| `category` | Yes | enum | `security` \| `quality` \| `performance` \| `design` \| `accessibility` \| `tests` \| `docs` \| `architecture` |
| `rule_id` | When applicable | string | Citation key from `.claude/rules/<id>.md` frontmatter (e.g., `auth-security`, `api-routes`). Omit if the finding doesn't map to a codified rule |
| `file` | Yes | string | Repo-relative path |
| `line` | When applicable | int \| range | Line number or range (`120-140`); omit for file-level findings |
| `title` | Yes | string | One-line summary, ≤80 chars |
| `description` | Yes | string | Why this is a problem, in concrete terms — not theoretical risk |
| `remediation` | When applicable | string | Specific fix; omit if the description already implies it |
| `agent` | Yes | string | Which reviewer produced it (`code-reviewer`, `security-auditor`, …) |
| `status` | Yes | enum | `open` \| `fixed` \| `wont_fix` \| `disagreed` (set by coordinator across iterations, not by the agent) |

## Severity Definitions

Stable, narrow definitions — agents must use these and not invent levels.

| Severity | Definition | Example |
|----------|------------|---------|
| `critical` | Security vulnerability, data loss, production crash, or compliance violation. Blocks merge. | SQL injection, secret in code, fail-open auth, GDPR PII leak |
| `important` | Real bug, performance regression, or convention violation that will bite later. Should fix before merge. | N+1 query, missing input validation, broken error path |
| `suggestion` | Improvement worth making but not blocking. Code works correctly without it. | Refactor for clarity, extract magic number, simplify branch |
| `nit` | Style, naming, or micro-preference. Always optional. | Variable name, comment phrasing, import order |

## Category Definitions

| Category | Owns |
|----------|------|
| `security` | Auth, secrets, injection, CSRF, CORS, SSRF, PII, dependency CVEs |
| `quality` | Bugs, error handling, dead code, code smells, design principles |
| `performance` | Queries, rendering, memory, caching, bundle size |
| `design` | Architecture, module boundaries, abstraction quality |
| `accessibility` | WCAG, ARIA, keyboard nav, color contrast, screen reader |
| `tests` | Missing coverage, brittle tests, missing edge cases |
| `docs` | Missing or stale documentation |
| `architecture` | Cross-system patterns, scalability, structural risk |

## Output Format (agents emit JSONL)

Each reviewer agent writes one JSON object per line to its report. The coordinator concatenates and dedupes them.

```jsonl
{"id":"src/auth.ts:42:auth-security:fail-open","severity":"critical","category":"security","rule_id":"auth-security","file":"src/auth.ts","line":42,"title":"Auth defaults to allow when config missing","description":"If AUTH_ENABLED is unset, the middleware calls next() — fail-open pattern.","remediation":"Add a startup check that crashes if AUTH_ENABLED is undefined in production.","agent":"security-auditor","status":"open"}
{"id":"src/users.ts:120:quality:n-plus-one","severity":"important","category":"performance","file":"src/users.ts","line":"120-140","title":"N+1 query in user list","description":"`for (const u of users) await db.posts(u.id)` runs one query per user.","remediation":"Batch with `db.posts.in(users.map(u=>u.id))`.","agent":"code-reviewer","status":"open"}
```

## Human-Readable Rendering

After the coordinator processes JSONL, it renders a markdown report grouped by severity, with rule citations:

```markdown
## Review Report — `feature/auth-refactor` (iteration 2)

### Critical (1)
- **[src/auth.ts:42]** Auth defaults to allow when config missing — *cites `auth-security`*
  > If AUTH_ENABLED is unset, the middleware calls next() — fail-open pattern.
  > **Fix:** Add a startup check that crashes if AUTH_ENABLED is undefined in production.
  > *Reported by:* security-auditor

### Important (1)
- **[src/users.ts:120-140]** N+1 query in user list
  > `for (const u of users) await db.posts(u.id)` runs one query per user.
  > **Fix:** Batch with `db.posts.in(users.map(u=>u.id))`.
  > *Reported by:* code-reviewer

### Resolved since last iteration (2)
- ~~[src/login.ts:88] Missing CSRF token~~ — fixed in commit `a1b2c3d`
- ~~[src/api/upload.ts:15] No file-size limit~~ — fixed in commit `e4f5g6h`
```

## Rule Citation

When a finding maps to a rule in `.claude/rules/<id>.md`, the agent MUST include `rule_id`. This:

1. Makes findings auditable ("which rule did this come from?")
2. Lets the coordinator group findings by rule across iterations
3. Lets the developer respond once ("we've decided not to enforce `tests` here") and have the coordinator respect it on future passes

If no rule applies, omit `rule_id`. Agents do not invent rule IDs.

## Cross-Iteration Status

The coordinator manages `status` — agents always emit `open`. On re-review:

- A finding with the same `id` that's no longer reproducible → `fixed`
- A finding the developer marked `wont_fix` (via state file or PR comment) → `wont_fix`, suppressed unless severity is `critical`
- A finding the developer pushed back on but didn't fix → `disagreed`, coordinator decides whether to re-raise based on argument quality

## Anti-Patterns

- **Don't emit findings with `severity: critical` for theoretical risks.** A finding is critical only if exploit/failure is concretely demonstrable from changed code.
- **Don't duplicate across categories.** A SQL injection is `security`, not `security` AND `quality`.
- **Don't include findings about unchanged code** unless the change makes pre-existing code newly reachable or newly dangerous.
- **Don't invent rule IDs.** If a rule doesn't exist, propose adding one — don't fabricate `auth-security-deep-mode` to look authoritative.
