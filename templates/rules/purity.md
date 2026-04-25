---
id: purity
patterns:
  - {{SOURCE_PATTERNS}}
---

# Purity, Side Effects, and SRP Rules

Citable standards used by the `purity-reviewer` agent. The principle: **side effects belong at the edges, not in business logic.**

A pure function:
- Returns the same output for the same inputs
- Has no observable side effects (no I/O, no mutation of inputs, no global state writes)
- Reads no hidden state (no globals, no module-level mutable vars, no `Date.now()` or `Math.random()` baked in)

## Pure Where Possible

Logic, transformations, calculations, and validations should be pure. Side effects (DB writes, network, logging, file I/O) get pushed to the boundary and the pure core gets called from there.

```ts
// Bad: business logic + I/O mixed
async function processOrder(orderId: string): Promise<void> {
  const order = await db.orders.get(orderId);
  const tax = order.amount * 0.21;
  const total = order.amount + tax;
  await db.orders.update(orderId, { tax, total });
  logger.info(`Processed order ${orderId}`);
  await emailService.send(order.userEmail, "Order processed");
}

// Good: pure core + thin I/O shell
function calculateOrderTotal(amount: number): { tax: number; total: number } {
  const tax = amount * 0.21;
  return { tax, total: amount + tax };
}

async function processOrder(orderId: string): Promise<void> {
  const order = await db.orders.get(orderId);
  const totals = calculateOrderTotal(order.amount);
  await db.orders.update(orderId, totals);
  logger.info(`Processed order ${orderId}`);
  await emailService.send(order.userEmail, "Order processed");
}
```

The pure version is testable without mocks, deterministic, and reusable.

## Query / Command Separation (CQS)

A function should either return data (a query) or change state (a command), not both.

**Detect:**
- Functions named `get*`, `find*`, `fetch*`, `is*`, `has*`, `calculate*` that mutate
- Functions named `set*`, `save*`, `update*`, `delete*`, `process*` that return useful business data instead of an ack/id

**Fix:** Split into two functions, OR rename to something honest. A function that creates AND returns the created entity is fine, but call it `create*` not `get*`.

```ts
// Bad — name says query, body mutates
function getUser(id: string): User {
  const user = db.users.get(id);
  user.lastSeen = Date.now();   // mutation!
  db.users.save(user);
  return user;
}

// Good — split
function getUser(id: string): User { return db.users.get(id); }
function touchLastSeen(id: string): void { db.users.update(id, { lastSeen: Date.now() }); }
```

## Hidden State Reads

A function that reads from a global, singleton, env var, or module-level mutable should declare it in the signature.

**Detect:**
- `process.env.X` deep in business logic
- `Date.now()`, `Math.random()`, `crypto.randomUUID()` baked into pure-looking functions
- Module-level mutable variables (`let counter = 0`) modified inside functions

**Fix:** Pass them as arguments. The caller has the context to choose; the callee shouldn't reach for ambient state.

```ts
// Bad
function generateToken(): string {
  return `${process.env.PREFIX}-${Math.random()}`;
}

// Good
function generateToken(prefix: string, randomFn: () => number = Math.random): string {
  return `${prefix}-${randomFn()}`;
}
```

This makes the function pure (or near-pure with a documented seam), testable, and explicit about its dependencies.

## Input Mutation

**Detect:** Function mutates an argument (object property assignment, array push/splice, calling mutator methods on inputs).

**Fix:** Return a new value. Mutation across function boundaries surprises callers and breaks referential transparency.

```ts
// Bad
function addTax(order: Order): void {
  order.tax = order.amount * 0.21;
}

// Good
function withTax(order: Order): Order {
  return { ...order, tax: order.amount * 0.21 };
}
```

**Don't flag:**
- Builder patterns where mutation is the documented API (`builder.with(x).with(y).build()`)
- Performance-critical hot paths where allocation matters and the mutation is local
- Constructors / `__init__` mutating `self`/`this`

## Single Responsibility (Function Level)

A function does one thing at one level of abstraction.

**Detect:**
- Function name contains "and" (`parseAndValidate`, `fetchAndSave`, `loadAndDecrypt`)
- Function body has 2+ comment-separated sections doing distinct work
- Function mixes high-level orchestration with low-level details

**Fix:** Split. Each piece becomes its own well-named function; the orchestrator just sequences them.

## Single Responsibility (Class/Module Level)

A class/module has one reason to change.

**Detect:**
- Public surface reveals 2+ unrelated method clusters (e.g., `UserService` with auth + profile + billing methods)
- The same module is imported by callers with very different concerns
- The class would need to be renamed if you wrote what it actually does

**Fix:** Split by concern. Each class/module owns one cohesive responsibility.

## What NOT to Flag

- **Logging is not a side effect for purity-review purposes.** It's observably ambient and rarely worth refactoring around. Suppress unless the logging carries business meaning (audit logs, event emission).
- **Reading config at the top of an entry point.** That's the boundary doing its job.
- **Constructors / factories that read defaults from env** when those are the application bootstrap.
- **Test code.** Tests do I/O, mutation, and impurity by nature; they're outside this rule's scope.
- **Generated code.**
- **Framework-required impurity** (e.g., React hooks, Vue setup) — the framework's contract overrides the rule.
