---
id: database
patterns:
  - {{DATABASE_PATTERNS}}
---

# Database Rules

When editing database-related files, follow these rules:

## Query Safety
- Never execute raw SQL from user input — always use parameterized queries
- No string concatenation or template literals for building SQL queries
- Use the ORM/query builder — drop to raw SQL only with parameterized queries when the ORM cannot express the query

## Performance
- Add database indexes for foreign keys and frequently queried columns
- No queries inside loops — use batch operations, joins, or eager loading
- Add `LIMIT` to queries that could return unbounded result sets
- Use `EXPLAIN` or query plan analysis for complex queries

## Migrations
- Migrations must be reversible — include both up and down operations
- Never modify a migration that has been deployed — create a new migration
- Test migrations against a copy of production data structure
- Add appropriate constraints at the database level (NOT NULL, UNIQUE, CHECK, FOREIGN KEY)

## Transactions
- Use transactions for multi-step operations that must be atomic
- Keep transactions as short as possible — no external API calls inside transactions
- Handle transaction rollback explicitly on error

## Row Locking for Concurrent Writers

When two processes might read and act on the same row, atomically claim it with a row lock at SELECT time. The classic failure mode: `SELECT ... WHERE status = 'pending'` from two workers returns the same row to both; both produce side effects; downstream sees duplicates. See `concurrency` rule "Producer → Queue → Worker Dispatch" for the full pattern.

### Per-dialect syntax

| Dialect | Lock syntax | Skip-locked variant |
|---|---|---|
| PostgreSQL | `SELECT ... FOR UPDATE` | `SELECT ... FOR UPDATE SKIP LOCKED` (9.5+) |
| MySQL / MariaDB | `SELECT ... FOR UPDATE` | `SELECT ... FOR UPDATE SKIP LOCKED` (MySQL 8.0+) |
| Oracle | `SELECT ... FOR UPDATE` | `SELECT ... FOR UPDATE SKIP LOCKED` (12c+); `NOWAIT` for immediate failure |
| SQL Server | `SELECT ... WITH (UPDLOCK, ROWLOCK)` | `SELECT ... WITH (UPDLOCK, ROWLOCK, READPAST)` |
| SQLite | `BEGIN IMMEDIATE` — no per-row lock, whole-DB serialization | — |
| MongoDB | `findOneAndUpdate({ status: 'pending' }, { $set: { status: 'in_flight' } })` | — (atomic find-and-modify is the equivalent) |
| Salesforce SOQL (Apex) | `SELECT ... FOR UPDATE` (cannot combine with `ORDER BY` — see below) | — |

### Use atomic claim when

- A worker reads from a queue/outbox/work table and produces a side effect (HTTP call, message publish, payment, email)
- The worker can run as multiple instances (multiple pods, app servers, cron lanes)
- The work item must be processed exactly once (or at-most-once with retries handled at the receiver)

### `FOR UPDATE` + `ORDER BY` incompatibility (Apex SOQL specifically)

Salesforce SOQL cannot combine `FOR UPDATE` with `ORDER BY` in a single query. When FIFO ordering matters, use a two-pass query:

```apex
// Pass 1: pick the FIFO candidate Id without a lock (ORDER BY allowed)
List<Outbox__c> candidates = [
    SELECT Id FROM Outbox__c
    WHERE Status__c = 'Pending'
    ORDER BY CreatedDate ASC
    LIMIT 1
];
if (candidates.isEmpty()) return null;

// Pass 2: re-fetch by Id with FOR UPDATE + re-validate status
List<Outbox__c> rows = [
    SELECT Id, /* full field list */ Status__c
    FROM Outbox__c
    WHERE Id = :candidates[0].Id AND Status__c = 'Pending'
    LIMIT 1
    FOR UPDATE
];
return rows.isEmpty() ? null : rows[0];
```

Wrap the call site in `try/catch QueryException` for `UNABLE_TO_LOCK_ROW` — the contending worker exits silently and the lock winner's chain handles remaining work.

### Lock-during-side-effect is the right design

The lock is intentionally held across the HTTP / RPC / message-send call. That's what makes the claim atomic from the producer's perspective. Other workers either block (then re-read with the row no longer matching the status filter) or get `UNABLE_TO_LOCK_ROW` (and exit cleanly).

### Anti-patterns specific to queue tables

- **In-memory status mutation before commit:** `row.status = 'in_flight'` (without `update`) followed by the side effect — invisible to a contending reader, race remains. Persist the status flip or use the row lock.
- **Application-level "claimed" marker without a constraint:** setting `claimed_by` after `SELECT` without a unique row lock — two workers both stamp their own ID. Without `FOR UPDATE` or a single atomic update statement, no claim.
- **Outbox dispatcher relying on consumer dedup:** receiver-side idempotency keys protect the receiver, not the producer. Producer must claim independently. See `concurrency` rule.

## Schema Patterns for Work Queue Tables

When designing a work queue / outbox / job table, include these columns explicitly so the claim pattern has somewhere to land:

| Column | Type | Purpose |
|---|---|---|
| `id` | UUID / serial | Primary key |
| `idempotency_key` | text | Unique constraint — prevents duplicate enqueues |
| `status` | enum / text | At minimum: `pending`, `in_flight`, `succeeded`, `failed`, `dead_letter` |
| `payload` | JSON / text | The work item content |
| `attempt_count` | int | Incremented per dispatch |
| `max_attempts` | int | Dead-letter threshold |
| `next_attempt_at` | timestamp | For retry scheduling with backoff |
| `last_error` | text | For observability and DLQ analysis |
| `claimed_by` | text (nullable) | Owner identifier for active claim (optional, useful for forensics) |
| `claimed_at` | timestamp (nullable) | When the claim was acquired (useful for stuck-row recovery) |
| `created_at` / `updated_at` | timestamp | Audit / FIFO ordering |

Add indexes on `(status, next_attempt_at)` for the dispatcher scan and `idempotency_key` (already unique). The `idempotency_key` unique constraint prevents duplicate **enqueues**; the row lock + status flip pattern prevents duplicate **dispatches** of an existing row. Both are required for end-to-end exactly-once semantics.
