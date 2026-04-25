---
id: components
patterns:
  - {{COMPONENT_PATTERNS}}
---

# UI Component Rules

When editing component files, follow these rules:

## Accessibility
- All interactive elements must have appropriate ARIA attributes
- Clickable non-button elements need `role="button"` and keyboard handlers
- Images must have meaningful `alt` text (or `alt=""` for decorative)
- Form inputs must have associated labels
- Color must not be the only means of conveying information

## Structure
- Keep components under 200 lines — extract sub-components beyond that
- No business logic in components — delegate to hooks, services, or utilities
- Props interfaces must be explicitly typed — no `any` types
- Default export one component per file matching the filename

## State Management
- Include loading, error, and empty states for all async data
- Use error boundaries to prevent cascading failures
- Avoid prop drilling beyond 2 levels — use context or composition
- Memoize expensive computations and callbacks when they cause measurable re-renders

## Event Handling
- Event handlers should be named descriptively (`handleSubmitForm`, not `onClick`)
- Clean up side effects (subscriptions, timers, listeners) in cleanup functions
