---
id: code-smells
patterns:
  - {{SOURCE_PATTERNS}}
---

# Code Smell Rules

These are **citable standards** that the `code-smell-reviewer` agent uses in its findings. When you edit code that matches these patterns, fix them inline. When reviewing, cite this rule's `id` (`code-smells`) for any finding mapping here.

The rule lists smells, what to look for, and the refactoring each points to. A smell is a symptom — the fix is the refactoring it suggests.

## Long Method

**Detect:** Any function/method over ~50 lines, or with multiple distinct sub-steps separated by blank lines or comments.

**Fix:** Extract sub-steps into named helpers. The extracted name documents intent better than a comment.

**Don't flag:**
- Test setup methods (fixtures, factories) where length is inherent
- Pure data tables (config maps, lookup tables) declared inline
- Auto-generated code

## Magic Numbers and Strings

**Detect:** Numeric or string literals appearing inline that represent thresholds, status codes, keys, limits, or domain values.

**Fix:** Extract to a named constant at module scope (or shared constants file if used across files).

**Examples:**
```ts
// Bad
if (user.age > 18) { ... }
status === 200
setTimeout(fn, 86400000)

// Good
const ADULT_AGE = 18;
const HTTP_OK = 200;
const ONE_DAY_MS = 24 * 60 * 60 * 1000;
```

**Don't flag:**
- `0`, `1`, `-1`, `2` in obvious contexts (loop counters, array indices, boolean equivalents)
- Literal HTTP status in dedicated status-handling code where the meaning is contextual
- Test data values

## Primitive Obsession (a.k.a. Strong Typing as Design)

The smell is reactive: raw `string`/`number` parameters or fields where a named type would clarify intent. The positive framing — **encode invariants in types** — is the same idea pointed at the design.

**The principle:** make invalid states unrepresentable. If a type can only be constructed when valid, the rest of the codebase doesn't have to re-validate or guess.

**Detect:**
- Raw `string` for IDs, emails, URLs, file paths, currencies, country codes, status codes
- Raw `number` for currencies (cents vs dollars), units (km vs mi), counts (positive only), percentages (0-1 vs 0-100)
- Raw `boolean` for tri-state values (`true` / `false` / `not-set`)
- Validation logic scattered across the codebase that all checks the same property (`if (!isValidEmail(s))` repeated)
- Functions whose comments document what the parameters mean instead of types ("expects a non-empty array", "must be > 0")
- Mutually-exclusive boolean flags that should be a discriminated union (cited by `solid` rule's OCP — defer)

**Fix — pick the right tool for the language:**

### Branded / nominal types (TypeScript, F#, Haskell)
Cheap, no runtime cost. Construction must go through a checked entry point.

```ts
// Bad
function transfer(fromId: string, toId: string, amount: number): void

// Good — branded types prevent passing the wrong string
type AccountId = string & { __brand: "AccountId" };
type Cents = number & { __brand: "Cents" };
function transfer(fromId: AccountId, toId: AccountId, amount: Cents): void
```

### Smart constructors / parse-don't-validate

Define a type whose only constructor checks the invariant. Once you have the value, downstream code trusts it.

```ts
// Bad — every caller validates again
function send(emailStr: string) {
  if (!isValidEmail(emailStr)) throw new Error("invalid");
  // ...
}

// Good — Email type is unforgeable; parse at the boundary, trust thereafter
class Email {
  private constructor(public readonly value: string) {}
  static parse(s: string): Email | null {
    return /^[^@]+@[^@]+$/.test(s) ? new Email(s) : null;
  }
}
function send(email: Email) { /* email is valid by construction */ }
```

The pattern: **parse at the boundary** (controllers, deserializers, user input) **into a strict type; pass that strict type through the rest of the system**. This eliminates "does this string have format X?" checks scattered through the codebase.

### Refined / constrained types

For numeric and collection invariants:

| Use | Instead of |
|-----|------------|
| `NonEmptyList<T>` | `T[]` with runtime "must be non-empty" check |
| `PositiveInt` | `number` with `assert n > 0` everywhere |
| `Percentage` (0..1 OR 0..100, pick one) | `number` |
| `Cents` | `number` (avoids float currency bugs) |
| `Duration` (ms) | `number` (no unit ambiguity) |
| `Url` | `string` |
| `Iso8601Date` | `string` |

Languages without first-class refinement types (most): use a class / record with a private constructor + smart factory; or branded types where a parse function gates construction.

### Value objects

For domain concepts with structural identity (two `Money` values are equal iff their amount and currency match), use a value object — class with read-only fields, structural `equals`, no hidden state.

```python
@dataclass(frozen=True)
class Money:
    amount: int  # cents
    currency: str
    def __post_init__(self):
        if self.currency not in {"USD", "EUR", "GBP"}: raise ValueError(...)
```

### Discriminated unions for closed sets

For status / kind / state, use a discriminated union (cited by `solid` rule OCP) — the type system enforces exhaustive handling:

```ts
type OrderState =
  | { kind: "draft" }
  | { kind: "submitted"; submittedAt: Date }
  | { kind: "shipped"; trackingNumber: string }
  | { kind: "delivered"; deliveredAt: Date };
```

This is preferred over raw string status fields with documentation listing the valid values.

**Detect (cross-language patterns):**
- Functions with `assert(x > 0)` / `assert(arr.length > 0)` at the top → push the invariant into the type
- Date strings passed around with comments like "ISO 8601 expected" → introduce a `Iso8601Date` type with a parse function
- `0` used as a sentinel "no value" → use `Option<T>` / `T | null` / `Optional[T]` and let the type system enforce checking
- Optional fields modeled as `T | null` AND a sibling boolean flag → eliminate the redundancy with one or the other

**Don't flag:**
- Genuinely unconstrained strings (free-form labels, descriptions)
- Hot-path code where the wrapper would add measurable overhead
- Primitives that already pass through a validated boundary (e.g., a Zod schema with `.brand()`)

## Data Clumps

**Detect:** The same group of 3+ parameters (or fields) appearing together repeatedly across functions/classes.

**Fix:** Introduce a data class/record/struct. The clump's appearance everywhere is a missing abstraction.

**Examples:**
```python
# Bad
def book_flight(from_city, to_city, depart_date, return_date, passengers): ...
def search_flights(from_city, to_city, depart_date, return_date, filters): ...
def price_flight(from_city, to_city, depart_date, return_date): ...

# Good
@dataclass
class Itinerary:
    from_city: str
    to_city: str
    depart_date: date
    return_date: date | None
def book_flight(itinerary: Itinerary, passengers: int): ...
def search_flights(itinerary: Itinerary, filters: Filters): ...
def price_flight(itinerary: Itinerary): ...
```

## Feature Envy

**Detect:** A method that accesses another class's data more than its own (`other.x`, `other.y`, `other.compute(other.z)` patterns dominate the body).

**Fix:** Move the method onto the class whose data it uses.

## Dead Code

**Detect:**
- Unreachable branches (`if (false)`, `if (DEBUG)` where DEBUG is hardcoded false)
- Unused variables, imports, parameters, exports
- Commented-out code blocks
- Functions/methods/classes with zero callers (verify with grep across the repo)

**Fix:** Delete it. Version control preserves history; commented-out code rots.

**Don't flag:**
- Unused intentionally for API stability (export marked `@public`/`@experimental`)
- Test helpers in shared fixtures
- TODO-tagged placeholders that link to a tracked ticket

## Comments as Deodorant

**Detect:** A multi-line comment explaining what unclear code does, where renaming/restructuring would make the code self-documenting.

**Fix:** Refactor — better names, smaller functions, extracted helpers — until the comment is redundant. Then delete the comment.

**Don't flag:**
- Comments explaining non-obvious WHY (constraints, invariants, workarounds, surprising behavior)
- API/public-interface documentation
- License headers, TODO tags, type-checker pragmas

## Speculative Generality

**Detect:**
- Abstract base classes / interfaces with one implementation
- Hooks, parameters, or extension points with no current caller
- "We might need this later" framing in commit messages or comments

**Fix:** Remove. Add it back when the second caller actually arrives.

## Long Parameter List

**Detect:** Function with 5+ parameters.

**Fix:** Introduce a parameter object (record/struct/dataclass). Often co-occurs with **Data Clumps**.

**Don't flag:**
- Constructors of value objects whose fields are the parameters
- Variadic / rest-parameter signatures (`...args`)

## Shotgun Surgery (cross-cutting)

**Detect:** A single conceptual change forces edits across many unrelated files.

**Fix:** Consolidate the scattered logic into one place. Often signals a missing service, helper, or registry.

**Don't flag:** Cosmetic ripple changes like rename refactors — those are tooling-driven and expected.
