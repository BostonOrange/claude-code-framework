---
id: observability
patterns:
  - {{SOURCE_PATTERNS}}
---

# Observability Rules

Citable standards used by the `observability-reviewer` agent. Covers OWASP A09:2021 (Security Logging & Monitoring Failures) plus broader operational observability — structured logging, metrics, tracing, audit logs, alert-worthy events.

The principle: **if the system silently fails, you don't have a bug, you have an incident waiting to happen**. Logs / metrics / traces aren't "nice to have"; they're the rollback path's eyes.

## Structured Logging

**Detect:**
- String-concatenated log messages: `log.info("User " + userId + " did " + action)` — unparseable in aggregation
- Mixed log formats in the same module (some JSON, some text, some `printf`-style)
- Log messages without contextual fields (request ID, user ID, operation, duration, outcome)
- `console.log` / `print` / `System.out.println` in production code paths (not a structured logger)
- `log.error("something happened")` with no further detail

**Fix:**
- Use a structured logger (`pino`, `winston`, Python `structlog`, `zap`, `slog`)
- Format: log message is the constant event name; variable data goes in fields (`log.info({event: "user.action", userId, action})`)
- Always attach: request/correlation ID, user ID (or `anon`), operation name
- For errors: include the error type, message, stack trace, and the operation context

## What to Log

**Must log:**
- Request received + completed (with status, duration, route)
- Auth events: login success/failure, logout, password reset, role change, session revocation
- Authorization decisions: access granted/denied with subject + resource + reason
- State-changing operations: create/update/delete with subject + entity + diff/before-after IDs
- Errors that reached the error handler (with full context)
- Background-job lifecycle: started / succeeded / failed / retried

**Should log:**
- Slow operations (above a threshold appropriate to the operation)
- External calls: target, status, duration
- Cache hits/misses for hot paths
- Feature flag evaluations for risky / new flags

**Never log:**
- Passwords (raw or hashed beyond what's needed for the auth event)
- Full credit card numbers (PCI; mask to last 4)
- Secrets / API keys / tokens / session IDs
- PII (cited by `data-protection` rule) — use opaque IDs, not names/emails/personal numbers
- Whole request/response bodies on PII-containing endpoints
- File contents from user uploads

## Log Levels

**Detect:**
- Everything at `info` (no signal/noise distinction)
- `error` used for warnings and `warn` used for noise
- `debug` left enabled in production (volume / cost)
- `error` logged AND re-thrown (double-logging in handler chain)

**Fix:**
| Level | When |
|-------|------|
| `fatal` / `critical` | Process / service is dying or unable to function |
| `error` | An operation failed; an alert may fire; user-visible failure |
| `warn` | Unexpected but recoverable; investigate if frequent |
| `info` | Normal lifecycle events: requests, jobs, state changes |
| `debug` | Detailed trace; off in production (or sampled) |
| `trace` | Per-statement; off in production |

Log at the boundary that owns the response. Don't log+rethrow — the outer handler will log.

## Metrics

**Detect:**
- New endpoints / background jobs without latency / error / throughput metrics
- Counters incremented but not exposed to the metrics system
- High-cardinality labels (`user_id` as a Prometheus label) → cardinality explosion / cost
- Metric names that don't follow convention (mixing `snake_case` and `dotted.style` in the same project)
- Critical paths without RED metrics (Rate, Errors, Duration) or USE (Utilization, Saturation, Errors)

**Fix:**
- Wire RED metrics on every request-handling middleware once; don't reinvent per route
- Use low-cardinality labels: `route`, `method`, `status_class` — not raw IDs
- Convention: name `domain_resource_action_unit` (`http_request_duration_seconds`, `worker_jobs_processed_total`)
- For business metrics: keep cardinality bounded; emit aggregates not raw events to time-series

## Tracing

**Detect:**
- Distributed call graphs without trace propagation (tracing breaks at service boundaries)
- Spans created but never closed (memory leak in tracer; broken trace tree)
- Trace sampling configured at 100% in production (cost / volume) without sampling strategy
- High-cardinality span attributes (raw user IDs as searchable attributes)

**Fix:**
- Propagate W3C `traceparent` header through every outbound call
- `with span:` / `try-with-resources` to guarantee close
- Tail-based sampling for important traces (errors, slow); head-based for the rest
- Span attributes: low-cardinality dimensions; put high-cardinality stuff in events on the span

## Audit Logs

**Detect:**
- Sensitive operations (admin actions, role changes, data exports, deletions) without audit logs
- Audit logs written to the same store as application logs (compliance failure)
- Audit logs that can be edited or deleted by application code
- Audit log entries missing the WHO / WHAT / WHEN / RESULT / IP

**Fix:**
- Separate sink for audit (append-only store, separate retention)
- Audit entries: `{timestamp, actor_id, actor_ip, action, resource, before, after, result, request_id}`
- Auditable events defined by policy, not ad-hoc

## Alerting

**Detect:**
- New critical paths without alerts
- Alerts on raw metrics with no recovery condition (alert storms)
- Alerts that fire constantly → ignored → real fires missed
- "Watch this dashboard" as a substitute for an alert
- Alerts without a runbook link

**Fix:**
- For each new critical path: define an alert + runbook link before merge
- SLO-based alerts where applicable (burn rate alerts, not raw thresholds)
- Pageable alerts must be actionable within minutes; non-actionable goes to a non-page channel
- Test the alert before relying on it (intentionally trigger; verify it fires)

## Correlation

**Detect:**
- Request handlers that don't propagate a request/correlation ID through downstream calls
- Background jobs without a parent trace / correlation ID
- Errors logged in different services for the same request that can't be tied together

**Fix:**
- Generate a request ID at the edge if not present; propagate via header
- Inject request ID into the logger context for every log line within that request
- For background work: pass the originating request ID through the queue message

## Sampling and Volume

**Detect:**
- All logs at all levels in production (cost / storage)
- Hot-path operations logging once per call (volume)
- No retention policy on logs (legal / compliance / cost)

**Fix:**
- Production: `info` and above; `debug` sampled or off
- Hot paths: log lifecycle events, not every step
- Define retention per log type: app logs 30d, audit 7y (or per regulation)

## What NOT to Flag

- **Logs in tests, fixtures, scripts** — they're for human reading, not aggregation
- **One-off tools** that don't run in production
- **Generated code, vendored code**
- **Pre-existing observability gaps in unchanged code** — only flag changes that add new code without observability
- **CLI / batch tools that print to stdout** — that's their UX, not a "logging" concern
- **Frontend logging** — different rules apply (browser console, telemetry SDK), don't apply server-side logging rules
- **Existing `console.log` in code being deleted** — don't flag what's going away
