---
id: api-layering
patterns:
  - {{API_ROUTE_PATTERNS}}
---

# API Layering Rules

Citable standards used by the `api-layering-reviewer` agent. These cover the **layered structure of API request handling** — controller, service, repository — and the contracts between them. Distinct from `api-routes` (which covers single-route concerns like validation, auth, errors) and `architecture-layering` (which covers app-wide module boundaries).

## Controller Responsibilities (Thin)

Controllers should do exactly:
1. Parse and validate input (delegate to a schema validator)
2. Authenticate / authorize the caller
3. Call one or more services with parsed inputs
4. Map the service result to a response
5. Map errors to HTTP status codes

**Detect:**
- Business logic in controllers (calculations, conditionals on domain rules, multiple service calls orchestrating a workflow)
- Direct DB access in controllers (skipping the service+repo layers)
- Controllers calling other controllers
- Controllers >100 lines (the work belongs in a service)

**Fix:** Push business logic into a service. Controllers stay thin.

## Service Responsibilities

Services own:
1. Business workflows (use cases)
2. Orchestration of repositories, external services, domain logic
3. Transactional boundaries
4. Domain validation (rules, invariants)

**Detect:**
- Services accepting HTTP-shaped types (`Request`, `Response`, raw query strings) — leak from controller
- Services calling controllers or framework HTTP helpers
- Services performing input shape validation that should be at the boundary
- Multiple services doing the same workflow with slight variations (extract a shared workflow)

**Fix:**
- Services accept domain types or DTOs, not HTTP shapes
- Push HTTP concerns up to the controller, domain rules down to the entity
- Validate shape at the boundary; validate business rules in the service

## Repository Responsibilities

Repositories own:
1. Persistence (CRUD against the data store)
2. Query construction
3. Mapping between persistence shape and domain shape

**Detect:**
- Repositories with business logic in queries (e.g., conditional joins based on user role — that's authorization, not persistence)
- Services constructing raw SQL/queries (should go through a repository method)
- Repositories returning raw rows / ORM objects to services (should map to domain types)
- Repositories that take HTTP/controller-specific filters

**Fix:**
- Add named repository methods per query intent (`getActiveUsers()` not `findUsers(filters)`)
- Map persistence types to domain types at the repository boundary
- Push authorization decisions to the service, not the query

## Validation Layer Placement

Validation lives at multiple layers, each owning specific concerns:

| Layer | Validates |
|-------|-----------|
| Controller | Shape: required fields, types, formats. Use a schema (Zod, Pydantic, Joi) |
| Service | Business rules: "user can't book a flight in the past", "balance must cover transfer" |
| Repository | Persistence constraints handled by the DB schema, not re-checked in code |

**Detect:**
- Controllers performing business-rule validation ("can this user do X?")
- Services re-validating shape that was already validated at the controller
- Database constraints duplicated as code-level checks "to be safe" (when the DB constraint already prevents the bad state)

**Fix:** Move each validation to its right layer. Don't validate the same thing twice; trust the layer that owns it.

## Error Contract

**Detect:**
- Inconsistent error shapes across endpoints (one returns `{ error: "..." }`, another `{ message: "..." }`, another raw stack)
- Service errors leaking ORM/DB exceptions to controllers (which then leak them to clients)
- Status codes invented ad-hoc (returning 200 for failures, 500 for client errors, 404 instead of 403)
- Missing error categorization: every failure is `500 Internal Server Error`

**Fix:**
- Define a domain error type hierarchy (`NotFoundError`, `ValidationError`, `AuthorizationError`, `ConflictError`)
- Services throw domain errors; controllers map domain errors to HTTP status + standard JSON shape
- Document the error contract once and apply it everywhere

## Pagination, Filtering, Sorting

**Detect:**
- List endpoints without pagination (cited by `api-routes` for the route concern; cited here for layering: pagination should be handled at the repo/query level, not in-memory after fetch)
- Filter parameters parsed in the controller and passed through the service unchanged — service should accept domain-shaped filters
- Sorting via raw SQL strings from user input (injection + leak)

**Fix:**
- Pagination implemented in the repository, with a stable cursor or offset
- Define a typed Filter DTO that controllers populate and services consume
- Whitelist sort fields; reject unknown ones

## Idempotency and Side Effects

**Detect:**
- POST/PUT/PATCH endpoints that retry-trigger side effects on duplicate calls (e.g., charging a card twice)
- Side effects (email, webhook, payment) inside a transaction that gets rolled back — the side effect already happened
- Multiple services performing the same external call without coordinating

**Fix:**
- Idempotency keys for state-changing endpoints
- Side effects happen *after* the transaction commits, via outbox or event
- Centralize external-call logic in one service

## Versioning Discipline

**Detect:**
- Breaking changes to request/response shapes without a version bump
- Mixed versions in URL vs header (inconsistent strategy)
- Internal types reused as wire types — they evolve together and break external clients on internal refactor

**Fix:**
- Pick a strategy (URL versioning OR header) and apply consistently
- Define separate wire DTOs from internal types — they're allowed to diverge
- Document the deprecation policy

## What NOT to Flag

- **Frameworks that legitimately collapse layers** (e.g., Express middleware acting as a thin service). Cite the rule only when there's clear benefit to splitting.
- **Single-file scripts, prototypes, internal admin tools** where layering would be over-engineering
- **Domain shapes intentionally identical to wire shapes** (CRUD admin endpoints) — they're allowed to drift later but don't have to start split
- **Pre-existing layering issues** in routes the diff doesn't touch
- **Generated SDK code, OpenAPI-generated controllers**
- **GraphQL resolvers** — different layering model; this rule is REST-shaped. Don't try to apply controller/service/repo to resolver code without thought.
