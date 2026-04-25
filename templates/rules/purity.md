---
id: purity
patterns:
  - {{SOURCE_PATTERNS}}
---

# Purity, Side Effects, and SRP Rules

Citable standards used by the `purity-reviewer` agent. The principle: **side effects belong at the edges, not in business logic.** A pure core wrapped in thin I/O shells is testable, deterministic, reusable, and easy to reason about.

This rule covers four related concerns under one umbrella:
1. **Pure functions** — same input → same output, no hidden state, no side effects
2. **Principle of Least Power** — use the most restricted construct that does the job (`val` over `var`, immutable over mutable, pure over effectful, declarative over imperative)
3. **Expression-Oriented Style** — prefer expressions returning values over statements with side effects
4. **Single Responsibility** — at function and class level

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

## Principle of Least Power

Use the most restricted construct that does the job. Each restriction is a guarantee for the reader and the compiler.

| Less power (preferred) | More power (only when needed) |
|------------------------|-------------------------------|
| `const` / `val` / `final` | `let` / `var` |
| Immutable collection (`readonly T[]`, `frozenset`, persistent map) | Mutable collection |
| Pure function | Effectful function |
| Declarative pipeline (`map`/`filter`/`reduce`, comprehensions) | Imperative loop with mutating accumulator |
| Expression returning a value | Statement with side effect |
| Specific type (`Email`, `PositiveInt`) | General type (`string`, `number`) |
| Static dispatch / discriminated union | Runtime type-keyed `if`/`switch` chain |

**Detect:**
- `let x` / `var x` where the value is assigned once and never re-bound (should be `const` / `val`)
- Mutable arrays/maps used where immutable would do (no callers mutate them)
- `for` loops with a mutating accumulator (`let total = 0; for (...) total += x.price`) where `reduce` / `sum` would express the intent directly
- Imperative `for (let i = 0; ...)` over a collection where `for (const x of items)` or `items.map(...)` works

**Fix:**
- `const`/`val` by default; only widen when re-binding is genuinely needed
- Immutable collections; prefer `[...arr, x]` / `{...obj, k: v}` over `arr.push(x)` / `obj.k = v`
- `items.reduce((sum, i) => sum + i.price, 0)` over `let sum = 0; for (...) sum += ...`
- Pattern matching (cited by `solid` rule's OCP section) over conditional dispatch on type codes

**Don't flag:**
- Performance-critical hot paths where mutation is documented and measurably faster
- Builder patterns where mutation is the documented API
- Loops with multiple side effects per iteration that don't reduce cleanly

## Expression-Oriented Style

Prefer expressions that **return values** over statements that mutate variables. Conditional expressions, pattern matches, and pipelines should produce the result directly — don't declare a variable, then assign to it under each branch.

**Detect:**
```ts
// Bad: statement-style with mutable accumulator
let result;
if (status === "active") result = computeActive(x);
else if (status === "pending") result = computePending(x);
else result = computeDefault(x);

// Bad: early-return-with-mutation pattern in a function that should return an expression
function classify(x) {
  let label;
  if (x > 100) label = "large";
  else if (x > 10) label = "medium";
  else label = "small";
  return label;
}
```

**Fix:**
```ts
// Good: expression returning value directly
const result = match(status)
  .with("active", () => computeActive(x))
  .with("pending", () => computePending(x))
  .otherwise(() => computeDefault(x));

// Good: ternary or match expression
function classify(x) {
  return x > 100 ? "large" : x > 10 ? "medium" : "small";
}
```

**Detect (other forms):**
- `try`/`catch` blocks that assign to an outer variable instead of returning the value
- Loops that mutate a result object that should be a `reduce` / pipeline
- Functions where the only purpose of `var` / `let` is to assign across branches (the language has expression-form alternatives — ternary, match, or extracted helper)

**Don't flag:**
- Languages without expression-form conditionals where the statement form is idiomatic (older C / Go)
- Code where the imperative form genuinely reads better than a deeply-nested ternary
- Multi-statement branches that legitimately do more than compute a value

## Composition over Inheritance

When you reach for inheritance, check first whether composition gives the same benefit with less coupling.

**Detect:**
- Class hierarchies with one or two levels created mainly to share helper methods (extract to a function or trait/mixin instead)
- `class Foo extends Bar` where `Foo` doesn't substitute for `Bar` (LSP violation — defer to `solid` rule)
- Inheritance used purely to satisfy a DI need (use a port/adapter via `solid` rule's DIP instead)

**Fix:**
- Prefer functions / traits / mixins / interfaces for shared behavior
- Use inheritance only when an IS-A relationship truly holds AND the contract is preserved
- Defer detailed LSP/ISP findings to `solid-reviewer`; this rule cites the smell that triggers the question

**Don't flag:**
- Framework-required inheritance (`class extends React.Component` where the framework demands it)
- Genuinely substitutable subtypes that satisfy the base contract

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
