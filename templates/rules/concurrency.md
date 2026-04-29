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
