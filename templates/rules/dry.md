---
id: dry
patterns:
  - {{SOURCE_PATTERNS}}
---

# DRY (Don't Repeat Yourself) Rules

Citable standards used by the `dry-reviewer` agent. DRY is about **knowledge duplication**, not character-level similarity. Three lines that look the same but encode different knowledge are not duplication.

## What Counts as Duplication

**True duplication** — same logic, same intent, expected to change together:

```ts
// File A
function totalWithTax(items: Item[]): number {
  return items.reduce((sum, i) => sum + i.price, 0) * 1.21;
}

// File B
function totalCartWithVAT(cart: Cart): number {
  return cart.items.reduce((sum, i) => sum + i.price, 0) * 1.21;
}
```
Both encode "sum prices, apply 21% VAT". A rule change to either must change the other. Extract.

**False duplication** — same shape, different intent, won't change together:

```ts
function userId(user: User): string { return user.id; }
function postId(post: Post): string { return post.id; }
```
Same shape, but they belong to different domains. Don't extract `getId<T>(x: T): string`.

## Detection Threshold

- 2 sites: probably fine; flag only if the duplicated logic is non-trivial (>5 lines or contains a domain rule)
- **3+ sites: flag**. Three is the canonical threshold for extraction.
- Any number of sites if the duplicated logic encodes a business rule, security check, or invariant — extract immediately.

## What to Extract

| Pattern | Extract to |
|---------|-----------|
| Computation/transformation | A pure function |
| Validation logic | A schema (Zod, Pydantic) or a validator function |
| Data shape repeated | A type/interface/dataclass |
| Network call boilerplate | A client wrapper |
| Error formatting | A formatter helper |
| Component layout | A shared component |

## Anti-Patterns to Suppress (don't extract)

- **Premature abstraction.** Two similar lines do not justify a helper. Three is the threshold.
- **Coincidental duplication.** Same shape, different domains — these will diverge.
- **Test setup that's intentionally explicit.** Tests benefit from being self-contained; don't DRY out fixtures unless the duplication hides a real fixture bug.
- **DTO/wire-format types vs domain types.** They look the same; they're allowed to diverge. Don't unify.
- **Generated code.** Diff-noise duplication in generated SDKs/protobufs is the generator's problem.
- **Documentation/comments.** Same explanation in two places is fine if both readers benefit; don't aggressively dedupe prose.

## What NOT to Flag

- Repeated *imports* (every file has its own)
- Boilerplate the language requires (Java getters/setters, Go error checks)
- Two implementations of the same interface (that's polymorphism, not duplication)
- A function appearing in tests AND production — that's the production function being tested
