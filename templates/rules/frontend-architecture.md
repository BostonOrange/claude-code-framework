---
id: frontend-architecture
patterns:
  - {{COMPONENT_PATTERNS}}
---

# Frontend Architecture Rules

Citable standards used by the `frontend-architecture-reviewer` agent. These cover **structural** frontend concerns — component composition, state management, data flow, render performance — not visual design (that's `design-system`) and not accessibility (that's `components`).

## Component Composition

**Detect:**
- Components over 200 lines, or with 5+ distinct concerns (data fetching, state, UI, side effects, business logic)
- Components doing data fetching AND UI rendering AND business logic in the same body
- Deep prop-drilling chains (3+ levels passing the same prop unchanged)

**Fix:**
- Split presentation from container: `<UserList>` (renders) vs `<UserListContainer>` (fetches + state)
- Extract custom hooks for cross-cutting state (`useUser()`, `useFilters()`)
- Use context, composition, or a state library to break prop-drilling chains
- Lift business logic out of components into pure functions (cited by `purity` rule)

**Don't flag:**
- Single-file demo components, examples, or storybook stories
- Routing/page components which inherently wire several concerns
- Components in a monorepo's `apps/` entry points

## Hook Discipline (React/Vue composables/Svelte stores)

**Detect:**
- Hooks called conditionally or inside loops
- Effects with missing/stale dependencies (`useEffect(fn, [])` reading values from outer scope that change)
- Effects that should be derived state (`useEffect(() => setX(compute(y)), [y])` — derive directly)
- Custom hooks that mix unrelated concerns (`useUserAndPostsAndTheme`)
- State that should be derived (`useState` for values computable from props or other state)

**Fix:**
- Move conditional logic inside the hook, not around it
- Add missing deps; if intentional, document why with a comment that explains the invariant
- Replace effect-driven derivation with computed values (`const x = compute(y)`)
- Split multi-concern custom hooks per `purity` rule's SRP guidance
- Convert redundant state to derived values

## State Management

**Detect:**
- Local component state for data that needs to be shared across siblings (lift it up)
- Global state for data that's only used in one subtree (push it down)
- State libraries used as glorified prop-drilling fixers (single consumer, single setter)
- Mutable state objects (direct property assignment instead of immutable updates)
- Server state stored in client state managers (use a server-state library: React Query, SWR, etc.)

**Fix:**
- Lift shared state to nearest common ancestor, or to a state library
- Move single-use global state back into local state
- Use server-state libraries for fetched data — don't reinvent caching in Redux
- Apply immutable update patterns (or use Immer)

## Data Flow

**Detect:**
- Data fetched in one component, refetched independently in a sibling — should share via cache or lifted state
- Synchronization issues: two pieces of state that should always agree but can drift
- Optimistic updates without rollback paths
- Mutations that don't invalidate or refetch related queries
- Mixing controlled and uncontrolled inputs

**Fix:**
- Centralize fetch with a server-state library; let consumers subscribe
- Eliminate redundant state by deriving one from the other
- Add rollback handlers to optimistic mutations
- Define cache invalidation rules with the mutation
- Pick controlled OR uncontrolled per input — don't mix

## Render Performance (architectural, not micro-optimization)

**Detect:**
- Wrapping every component in `React.memo` without measurement (premature optimization)
- Inline-defined components inside other components (recreated every render)
- Massive lists rendered without virtualization
- Heavy computation in render that should be memoized (`useMemo`, `computed`)
- New object/array literals as props on every render that propagate through children

**Fix:**
- Measure first; only memo if profiling shows benefit
- Extract inline components to module scope
- Add virtualization for lists over ~500 items
- `useMemo` for genuinely expensive computations (not for trivial ones)
- Stable references via `useMemo`/`useCallback` only when the consumer is memoized

**Don't flag:** Components that render rarely (top-level layouts, settings pages) — micro-optimization there is noise.

## Module Boundaries

**Detect:**
- Cross-feature imports: `features/billing/` importing from `features/dashboard/internal/`
- UI components importing from data/domain layers directly (skip the hook/service)
- Circular imports between component files

**Fix:**
- Define a public API per feature (`features/billing/index.ts` exports only what's intended for outside use)
- Route data access through hooks/services, not direct DAL imports
- Break cycles by introducing a shared lower-level module

## SSR / Hydration (when applicable)

**Detect:**
- Server-rendered output that mismatches client (text differences, conditional rendering on browser-only globals)
- `useEffect`-only data fetching for content that should be SSR'd
- Suspense boundaries placed where they cause waterfalls
- `window`/`document` access without guards on server

**Fix:**
- Defer browser-only state to `useEffect` after mount, not during render
- Use SSR-friendly fetching (Next.js `getServerSideProps`, Remix loaders, etc.)
- Move suspense boundaries up/down to enable parallel fetching
- Guard browser globals: `typeof window !== "undefined"`

## What NOT to Flag

- **Style preferences** for component organization (folder structure, naming conventions) unless the project rule mandates a specific pattern
- **Components in tests, fixtures, examples, storybook**
- **Generated UI** (UI from a low-code tool, design-tool exports)
- **Pre-existing components in unchanged files** — only flag changes within the diff
- **Hot-path performance opinions without measurement** — measure or don't flag
- **Library-required patterns** (e.g., Next.js page exports, React Server Component boundaries)
- **Vendor code** (`node_modules/`, `vendor/`, `dist/`)
