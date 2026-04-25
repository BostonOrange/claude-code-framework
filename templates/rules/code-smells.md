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

## Primitive Obsession

**Detect:** Raw `string`/`number` parameters or fields where a named type or wrapper would clarify intent — especially for IDs, units, currencies, emails, dates-as-strings.

**Fix:** Introduce a branded type, value object, or struct.

**Examples:**
```ts
// Bad
function transfer(fromId: string, toId: string, amount: number): void

// Good
type AccountId = string & { __brand: "AccountId" };
type Cents = number & { __brand: "Cents" };
function transfer(fromId: AccountId, toId: AccountId, amount: Cents): void
```

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
