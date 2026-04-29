---
id: architecture-layering
patterns:
  - {{SOURCE_PATTERNS}}
---

# Architecture Layering Rules

Citable standards used by the `architecture-reviewer` agent. These cover **module boundaries and dependency direction** — the structural rules that keep a codebase from collapsing into a graph of mutual dependencies.

## Layer Dependency Direction

A typical layered application has roughly:

```
HTTP / UI / API edge      ← outermost, depends inward
  ↓
Application / use cases   ← orchestration of domain logic
  ↓
Domain / business logic   ← pure, no I/O
  ↓
Infrastructure / data     ← innermost, depended upon
```

**Rule:** Dependencies flow inward only. The domain does not import from the application layer; the application does not import from the HTTP layer.

**Detect:**
- Domain modules importing from `controllers/`, `routes/`, `pages/`, `api/`
- Domain modules importing HTTP-specific types (`Request`, `Response`, `NextApiRequest`)
- Database/repository modules importing from application or HTTP layers
- Infrastructure adapters importing domain entities directly when they should use ports/interfaces

**Fix:** Invert the dependency. Define a port (interface) in the inner layer; let the outer layer implement it. The Dependency Inversion Principle.

## Cross-Module Reach

**Detect:**
- One feature/module reaching into another's internals: `features/billing/` importing `features/dashboard/internal/utils.ts`
- Direct imports of repository/DAL classes from UI/controller layers (should go through a service)
- Code reading from a global service locator without declaring the dependency

**Fix:**
- Define a public API per module (`features/billing/index.ts` re-exports the intended surface)
- Route through the proper layer (controller → service → repo, not controller → repo)
- Inject dependencies (constructor / function args), don't reach for them

## Circular Dependencies

**Detect:**
- Module A imports B, B imports A (direct cycle)
- A → B → C → A (transitive cycle)
- Two classes in different files mutually referencing each other's types

**Fix:**
- Extract the shared concern to a third module both depend on
- Convert one direction to a callback/event/observer
- Merge the two modules if they're truly inseparable

## God Modules / God Classes

**Detect:**
- A single module that 5+ unrelated modules import from
- A class with 20+ public methods spanning multiple unrelated responsibilities (also caught by `purity` rule's class-level SRP)
- An "everything bag" file: `utils.ts`, `helpers.ts`, `common.ts` with grab-bag functions for unrelated domains

**Fix:**
- Split by responsibility, even if some imports get longer
- Extract cohesive sub-modules
- Resist the temptation to colocate "general utilities" — they tend to grow into a tangle

## Anemic vs Rich Domain (when an OO style is used)

**Detect:**
- Domain entities that are pure data bags + a service layer with all the logic (anemic domain)
- Or the inverse: services with no logic, all behavior on entities that also do their own persistence (god entities)

**Fix:**
- Move domain rules onto the entity that owns the data
- Keep persistence concerns in repositories
- Services orchestrate; entities encode rules; repositories persist

**Don't flag:**
- DTOs and wire-format types — these are intentionally anemic
- Functional codebases where "entities" are just data + functions (different style, not a smell)

## Public API Discipline

**Detect:**
- Modules with no clear "what's public, what's internal" indication
- Internal helpers leaked through re-exports
- Private types/functions used outside the module
- Type exports that expose implementation details (e.g., raw DB rows)

**Fix:**
- Establish convention: `index.ts` is the public API; everything else is internal
- Or use `internal/` subfolder; or language-level visibility (`_` prefix in Python, `private`/`internal` in TS/Java)
- Define explicit DTOs for the boundary

## Event/Pub-Sub Boundaries

**Detect:**
- Direct synchronous calls where loose coupling was the intent (events ignored, replaced with imports)
- Event handlers that reach back synchronously into their publisher
- Subscribers depending on knowledge that should be encoded in the event payload

**Fix:**
- Restore the event contract; pass full context in the payload
- If the call must be synchronous, drop the event abstraction (it's not buying anything)

## Hexagonal / Ports & Adapters (where applicable)

**Detect:**
- Adapter classes that leak adapter-specific types up into ports
- Port interfaces that expose `Promise<DBResult>` instead of domain types
- Multiple adapters for one port that drift in shape

**Fix:**
- Ports speak in domain terms only; adapters translate
- Verify all adapters satisfy the port's full contract (use interface enforcement)

## What NOT to Flag

- **Stylistic disagreements about layer boundaries** — flag rule violations only, not preferences
- **Small projects without explicit layering** — premature for a 3-file project
- **Generated code, vendor code, lockfiles**
- **Pre-existing layering issues** in code the diff doesn't touch
- **Cross-cutting concerns that legitimately span layers** (logging, telemetry, error mapping) — these are usually wired by infrastructure, not architecture violations
- **Microservices boundaries** — different rule, different scope
- **Test code** that intentionally reaches across layers for integration testing
