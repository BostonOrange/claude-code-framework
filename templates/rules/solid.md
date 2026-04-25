---
id: solid
patterns:
  - {{SOURCE_PATTERNS}}
---

# SOLID Principles Rules

Citable standards used by the `solid-reviewer` agent. Covers Open/Closed, Liskov Substitution, Interface Segregation, and Dependency Inversion. The Single Responsibility Principle (S) is owned by the `purity` rule (`purity-reviewer`); cite that rule for SRP findings, not this one.

The principle: **named principles aren't laws — they're shapes that prevent specific failure modes**. Cite SOLID only when the violation maps to a concrete failure: regression risk, contract break, coupling that blocks testing, or the wrong thing changing together.

## OCP — Open/Closed Principle

A module should be **open for extension, closed for modification**. New behavior added by adding new code, not by editing stable code.

**Detect:**
- Conditional chains keyed on a type code that grow with each new type (`if (type === "X") ...; else if (type === "Y") ...`) — adding a new type requires editing every chain
- Switch on enum / type / kind that's repeated across multiple files — same shape, scattered
- "If/else ladder anti-pattern" where each branch encodes type-specific behavior
- Modules that gain new conditional branches every release

**Fix:**
- Introduce polymorphism / strategy: each type owns its behavior; the dispatcher just calls
- Or: a registry / table lookup keyed by type, with handlers as values
- Discriminated unions + exhaustive matching (TypeScript, Rust, Scala) — the compiler tells you when a new variant needs handling

**Don't flag:**
- A single switch over a closed enum — closed means it doesn't grow; the switch is a feature
- Two-branch conditionals on a binary (boolean) — polymorphism would be over-engineered
- Conditional logic on data values, not types (`if amount > 1000` is not OCP-relevant)

## LSP — Liskov Substitution Principle

Subtypes must be **substitutable for their base types** without callers needing to know the difference.

**Detect:**
- Subclass overrides a method to throw `NotSupportedException` / `NotImplementedError` / `UnsupportedOperationException`
- Subclass weakens a precondition violation (rejects inputs the base accepted) or strengthens a postcondition (returns less than the base promised)
- Subclass changes side-effect contract (base saves to DB, subclass saves AND publishes event without contract update)
- "Square extends Rectangle" antipattern — `Square.setWidth` violates Rectangle's contract that width and height are independent
- Code that does `if (instance instanceof Subtype) ...` to work around subtype-specific behavior

**Fix:**
- Subtype only when the IS-A relationship truly holds (and the contract is preserved)
- Otherwise: separate types, or composition, or split the base interface (also see ISP)
- Document contracts on the base; verify subtypes against them in tests (Liskov-style property tests)

**Don't flag:**
- Subtypes that genuinely satisfy the contract — subclassing is allowed; "favor composition" is a heuristic, not a rule
- Mixin / trait composition that may look like inheritance but doesn't violate substitution

## ISP — Interface Segregation Principle

Clients should not be forced to depend on **methods they don't use**. Many small interfaces beat one large one.

**Detect:**
- An interface with 10+ methods where most consumers use 1–2
- Implementers forced to stub out methods they don't support (often shows up as `NotImplemented` — overlaps with LSP)
- "God interface" that bundles read + write + admin + diagnostics
- Mock setups in tests that have to fake many irrelevant methods to satisfy the interface

**Fix:**
- Split the interface by client need: `Reader`, `Writer`, `Admin`, `Diagnostics`
- Compose interfaces where multiple roles are needed: `interface ReadWriter extends Reader, Writer`
- For TS/Python: structural typing — the consumer declares only what it needs (`(x: { read(): T }) => ...`), no nominal interface required

**Don't flag:**
- Cohesive interfaces where every method belongs to the same role and most consumers use most methods (a `UserRepository` with `find/save/delete` is fine — those are the role)
- Interfaces with many methods where the methods are part of a coherent API surface (e.g., a `Logger` interface with `debug/info/warn/error` — segregating these would over-fragment)

## DIP — Dependency Inversion Principle

High-level modules should not depend on low-level modules. **Both should depend on abstractions.**

**Detect:**
- High-level modules (services, use cases) directly instantiating low-level concrete types (`new HttpClient()`, `new PostgresDb()`)
- Domain code importing infrastructure types (`import { PrismaClient }` in a use-case file)
- Hardcoded singletons reached for inside business logic (`Logger.getInstance()`, `Database.shared`)
- Constructor / function parameter typed as a concrete class instead of an interface, where alternative implementations exist or are expected for tests

**Fix:**
- Define an interface (port) in the inner layer; let the outer layer implement it (adapter)
- Pass dependencies in via constructor or function arguments; let composition root wire them
- For testing: inject test doubles, not patch globals

**Don't flag:**
- Truly leaf-level utilities depended on directly (`String.split`, `Math.max`) — not every function call needs an interface
- Single-implementation interfaces with no realistic alternative — that's "interface for the sake of interface" (cited by `code-smells` as Speculative Generality)
- Framework-mandated direct instantiation (e.g., React component instantiation)

## When SOLID Findings Overlap Other Rules

| If finding is about | Cite |
|---------------------|------|
| One class doing many things | `purity` (SRP at class level) — not this rule's S |
| Cross-module dependency direction | `architecture-layering` (broader scope than DIP within one module) |
| Controller doing service work | `api-layering` (more specific) |
| Long conditional chain that's also high cyclomatic | `complexity` (numeric threshold) |
| Excessive getter/setter pairs over data | `code-smells` (Anemic Domain), not LSP |

When uncertain, **prefer the more specific rule**. SOLID is a meta-framework; the dedicated rules are usually more actionable.

## What NOT to Flag

- **Hypothetical SOLID violations** — only flag when there's a concrete failure mode (regression risk, broken substitution, blocked testing)
- **Frameworks that require their own DIP-violating patterns** (React's `useState`, Vue's `setup`, Express's middleware closure)
- **Test code** that intentionally couples to concrete types
- **Generated code, vendored code**
- **One-off scripts, prototypes, glue code** where SOLID would be over-engineering
- **Pre-existing violations in unchanged code**
- **"Should be more SOLID" without naming the principle and the failure mode** — that's a vibe, not a finding
