---
id: concurrency
patterns:
  - {{SOURCE_PATTERNS}}
---

# Concurrency Rules

Citable standards used by the `concurrency-reviewer` agent. Covers race conditions, atomicity, async/await pitfalls, locking discipline, and shared-state coordination.

The principle: **concurrency bugs are deterministic — they're only rare.** Most show up under load, in production, when reproducing them is hardest. Flag them when they're introduced.

## Race Conditions on Shared State

**Detect:**
- Read-then-write on shared state without atomic operation: `if (cache[k] === undefined) cache[k] = compute()`
- Counter increments / array appends / map writes from multiple async callers without coordination
- File operations: read → modify → write without lock or atomic rename
- Database read-modify-write that should be a single atomic statement (`UPDATE balance = balance + 100` instead of `SELECT balance; UPDATE balance = ?`)

**Fix:**
- Atomic primitives: `AtomicInteger`, `compareAndSwap`, language-specific atomics
- Single atomic SQL: `UPDATE table SET col = col + ? WHERE ...`
- Locks where atomicity primitives don't fit; release in `finally` / `defer`
- Concurrent collections (`ConcurrentHashMap`, `sync.Map`, `Arc<Mutex<T>>`)

## TOCTOU (Time of Check, Time of Use)

**Detect:**
- `if (file.exists()) { read(file) }` — file may have been deleted between check and use
- `if (user.canAccess(resource)) { perform(resource) }` — permission may have changed
- `if (!exists(key)) insert(key, value)` — another writer may have inserted between check and insert
- Auth check at controller, action at service, both reading auth state independently

**Fix:**
- Skip the check; perform the action and handle the failure (`open(); catch FileNotFound`)
- Atomic operations: `INSERT ... ON CONFLICT`, `INSERT IF NOT EXISTS`, compare-and-swap
- Single transaction encompassing both check and action
- Pass the auth decision (capability / token) from check to action, don't re-check

## Async Discipline

**Detect:**
- Missing `await` on a Promise / Future — fire-and-forget where the caller expected the result, errors silently swallowed
- `await` inside a tight loop sequencing what should be parallel (`for (const x of items) await fetch(x)`)
- `Promise.all` over too-many concurrent operations (memory blowup, downstream rate-limit)
- `async` function that doesn't actually `await` anything — should be sync, signature lies
- Mixing async paradigms (callbacks + promises + async/await on the same code path)
- Top-level `await` in a context that doesn't support it (and the runtime allows the file to load before the promise resolves)

**Fix:**
- Always `await` or `.catch()`; if intentionally fire-and-forget, name it (`void emitMetric(...)`) and document why
- Parallelize with `Promise.all([...items.map(fetch)])` when items are independent
- Bounded concurrency: `pMap(items, fetch, { concurrency: 10 })` (or language equivalent)
- Convert callback APIs once at the boundary; use one paradigm internally
- Drop `async` if the function never awaits — be honest

## Lock Discipline

**Detect:**
- Locks acquired but not always released (missing `finally` / `defer` / `Drop`)
- Two locks acquired in different orders in different code paths → deadlock risk
- Lock held across an `await` / I/O / RPC call → starvation, deadlock, throughput cliff
- "Optimistic" check inside a lock that's also done outside (overlap with TOCTOU)
- Locks in long-running code paths (acquired at the top of a 200-line function)
- Recursive locking on a non-reentrant lock

**Fix:**
- Acquire in `try`, release in `finally` (or `defer`, RAII, scoped guard)
- Define a global lock-ordering convention; document it; enforce in code review
- Don't hold locks across I/O — release before, re-acquire after, re-validate state
- Keep critical sections short; extract to a small function that's the entire critical section
- Use reentrant locks only when re-entry is genuinely needed

## Mutable Shared State

**Detect:**
- Module-level mutable variables modified from multiple call sites
- Singleton with mutable state shared across requests (not thread-safe)
- Caches without LRU bound or eviction (memory leak under load)
- Per-request state stored in a global instead of in the request context
- Mutable closures captured by multiple goroutines / threads / async tasks

**Fix:**
- Prefer immutable data; mutate via "produce a new value"
- Per-request scoped state, passed explicitly
- Bounded caches (LRU, TTL)
- Where mutation is needed: `Arc<Mutex<T>>`, `Lock + state`, channel-based coordination

## Background Work

**Detect:**
- Background tasks started without a way to cancel them
- Workers that don't drain on shutdown → in-flight work lost
- Background jobs that retry forever without backoff or dead-letter
- Multiple workers consuming the same queue without idempotency keys
- Cron jobs that overlap when one run takes longer than the interval

**Fix:**
- Pass a cancellation token / `Context` / `AbortSignal` through every background flow
- Implement graceful shutdown: stop accepting, drain queue, exit
- Exponential backoff with max attempts and dead-letter queue
- Idempotency keys (cited by `api-layering`) for workers that may double-process
- Cron jobs: lock with timeout, or single-instance scheduler

For DB-backed queue tables (transactional outbox, work tables, polling dispatchers) the producer-side atomic claim pattern below is mandatory in addition to consumer-side idempotency.

## Producer → Queue → Worker Dispatch

The pattern: an application writes work items to a queue (DB table, message broker, file system, etc.); a worker reads pending items and produces side effects (HTTP call, message publish, payment, email, file write, etc.). The race lives in the gap between read and side-effect.

**The trap:** "we have idempotency keys, so duplicates are fine" is true for the *receiver* and false for the *producer*. If two workers both read the same item and both emit the side effect, the consumer needs to dedup. If the consumer's dedup is misconfigured, racy itself, or simply absent (a common state for in-progress middleware), duplicates land downstream as customer-visible errors — duplicate invoices, duplicate emails, duplicate charges. The fix has two layers and both are non-negotiable for production-grade systems:

1. **Producer atomically claims the work item before the side effect.**
2. **Consumer dedupes by idempotency key.**

Both layers, every time. Skipping either is a future incident.

### Atomic claim — make the read-then-side-effect single-owner

**Detect:**
- Background worker (cron, queueable, scheduled job, daemon, lambda triggered by polling) reading from a queue/outbox table by status filter and dispatching to an external system, with no row lock or claim mechanism
- `SELECT ... WHERE status = 'pending' LIMIT N` followed by an HTTP/RPC/message-send call — no `FOR UPDATE`, no status flip-and-commit, no `Lock_Owner__c`-style field
- Multiple instances of the worker can run on different processes / pods / app servers / nodes
- Code or comments saying "we rely on the consumer to dedup" — fine for the receiver, but it offers zero protection if the producer emits twice and the receiver's dedup races or is missing
- Worker that reads → mutates in-memory → side-effect → DML, where the DML is after the side-effect (the in-memory mutation is invisible to a contending worker)

**Fix (DB-backed queue):**
- `SELECT ... FOR UPDATE` (PostgreSQL, MySQL, Oracle, Apex SOQL) — row lock held until the transaction commits or rolls back
- `SELECT ... FOR UPDATE SKIP LOCKED` (PostgreSQL 9.5+, MySQL 8.0+, Oracle 12c+) — skip rows another worker has claimed; ideal for parallel-worker scale-out
- `SELECT ... WITH (UPDLOCK, ROWLOCK, READPAST)` (SQL Server) — equivalent intent
- `findAndModify` / `findOneAndUpdate` with `$set: { status: 'in_flight', owner_id: <workerId>, claimed_at: now }` (MongoDB) — atomic claim in a single round trip
- For dialects where `FOR UPDATE` conflicts with `ORDER BY` (Apex SOQL is the notable case): two-pass query — Pass 1 picks the candidate Id ordered, no lock; Pass 2 re-fetches by Id with `FOR UPDATE` + re-validates the status filter. The loser's catch handler exits silently; the chain handles the rest.
- The lock is intentionally held across the side-effect call. Yes, this is the right design: the lock IS what serializes the row across processes.

**Fix (external queue with native at-least-once delivery):**
- Most brokers handle the producer-side claim natively — one consumer per partition (Kafka), one visibility timeout per message (SQS), one peek-lock holder (Azure Service Bus), one delivery tag (RabbitMQ). Rely on the broker's contract; don't roll your own DB-backed queue when a real broker is available.
- Prefer `peekLock` over `receiveAndDelete` semantics; explicit `complete` on success, `abandon` on failure → broker redelivers to the next consumer.

**Fix (distributed coordination across instances):**
- Redis `SETNX` with TTL, Redlock for multi-node Redis
- etcd / ZooKeeper leases for stronger consistency
- PostgreSQL `pg_advisory_lock` / MySQL `GET_LOCK` for in-database mutexes
- Single-instance dispatcher pattern (one leader runs the dispatcher; replicas warm-standby) — k8s leader election, AWS Step Functions, GCP Cloud Scheduler with concurrency=1

### Idempotency at the receiver — defense in depth

The producer's atomic claim prevents your service from emitting duplicates. Receiver idempotency catches duplicates from network retries, replays, manual reprocessing, schema migrations that re-run jobs, and future producer regressions. Both layers, every time.

**Detect:**
- Receiver inserts/upserts work without an idempotency-key column or unique constraint
- Idempotency key passed in the request body / message but logged-only, not enforced by a DB unique index or broker dedup setting
- Receiver's "is this a duplicate" check is a `SELECT` followed by `INSERT` — racy without a unique constraint
- Broker queue with `requiresDuplicateDetection: false` despite producers sending stable `MessageId`s
- HTTP receiver that doesn't cache responses by idempotency key — retries with the same key recompute the side effect

**Fix:**
- Unique index on `idempotency_key` at the receiver's persistence layer
- `INSERT ... ON CONFLICT DO NOTHING` (PostgreSQL) / `INSERT IGNORE` (MySQL) / `MERGE` (SQL Server) — push the dedup into one atomic statement
- For HTTP receivers: cache the response keyed by idempotency-key for a window (5–60 min); return the cached response on retries (Stripe-style `Idempotency-Key` header)
- For message brokers: enable native deduplication (Azure Service Bus `requiresDuplicateDetection` + producer sets `MessageId`; SQS FIFO with `MessageDeduplicationId`; Kafka idempotent producer)

### Transactional outbox specifically

When your service needs to atomically commit a domain change AND publish an event/message to another system:

**Anti-pattern:** commit DB → then publish to broker. The broker publish can fail (network, broker down, timeout). DB and broker drift. Customers see "the action says it succeeded but the downstream didn't get the event."

**Pattern:** in the same DB transaction as the domain change, insert a row into an `outbox` table holding the event payload. A separate worker (cron, scheduled job, change-data-capture stream) reads pending outbox rows and publishes them — using the atomic claim pattern from above.

The outbox dispatcher MUST use atomic claim. A producer-side race in the dispatcher produces duplicate downstream effects even though the original domain change committed exactly once.

### Cross-cutting test approach

Real concurrency cannot be simulated inside most test frameworks' single-transaction test runners. Pragmatic coverage:
- Unit-test the `is-this-a-contention-error` helper deterministically with a synthesized exception or stub
- Unit-test the status-filter re-validation path (Pass 2 returning empty when status has advanced)
- Sandbox or staging: rapid concurrent invocations (two terminals, ApacheBench, k6) — assert exactly-once side effects downstream
- Production observability: count of distinct work-item IDs in downstream logs per 24h window equals expected dispatched count; alert on drift

### Hit in production

Pattern hit on May 11, 2026 in a Salesforce → Azure Logic App → Billecta invoicing integration: two SF app servers concurrently SELECTed the same Pending row from `Integration_Outbox__c` and both POSTed to the Logic App, producing duplicate invoices in Billecta. The producer's SOQL had no `FOR UPDATE`. The receiver (Logic App) didn't set a `MessageId` on the Service Bus send. The Service Bus queue had `requiresDuplicateDetection: false`. The consumer service had no DB unique index on the idempotency key. *Every* layer of defense was missing — single fix at any layer would have caught the duplicate.

## Channel / Queue Discipline

**Detect:**
- Unbounded channels / queues (memory leak under producer surge)
- Channels written to without a reader (deadlock for blocking sends, silent drop for non-blocking)
- Closing a channel from the consumer side (typically wrong; producer closes)
- Multiple producers closing the same channel (panic in Go)
- Reading from a closed channel without checking the closed signal

**Fix:**
- Bounded channels with explicit policy on full (block, drop, error)
- Document and enforce: producer owns close
- For multi-producer: WaitGroup + dedicated closer goroutine

## Test Concurrency

**Detect:**
- Sleeps used to "wait for" async operations in tests (`sleep(100)`) — flaky
- Tests that pass sequentially but fail under `--parallel` (shared mutable state across tests)
- Mocking that's not thread-safe
- Tests that mutate global state without restoring

**Fix:**
- Wait on conditions / promises / channels, not wall-clock
- Test isolation: per-test fresh state; no shared mutable globals
- Concurrency-safe mocks where the SUT is concurrent

## What NOT to Flag

- **Single-threaded code** with no async, no shared state, no I/O concurrency — concurrency rules don't apply
- **Frameworks where the runtime guarantees thread-safety** (single-threaded event loop in Node — no race conditions on local memory; multi-process workers communicate only via shared infra)
- **Hypothetical races** that the type system, framework, or runtime prevents
- **Pre-existing concurrency in unchanged code** — flag changes within the diff
- **Test code** with deliberate sequential behavior
- **Vendored / generated code** with its own concurrency model
- **Performance-tuned code** with documented concurrency invariants — read the comments before flagging
