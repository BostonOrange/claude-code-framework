---
patterns:
  - {{COMPONENT_PATTERNS}}
---

# Design System Rules

When editing UI component files, enforce design system consistency. These rules prevent visual fragmentation and ensure every component inherits the project's design language.

## Color Tokens

- **NEVER use raw Tailwind colors** in components (`text-gray-900`, `bg-blue-600`, `border-red-200`). Use semantic design tokens (`text-primary`, `bg-brand-solid`, `border-secondary`, `text-error-primary`).
- **Exception**: `theme.css` / design token definition files may use raw colors to define the token values.
- **Exception**: Tailwind's `black` and `white` are acceptable in opacity modifiers (`bg-black/10`, `border-white/15`).
- Dark mode must come from semantic tokens automatically — never add manual `dark:text-gray-*` or `dark:bg-gray-*` overrides on raw colors in components.
- If you find yourself adding a `dark:` prefix with a raw color, the design token system has a gap. Flag it and fix the token, don't patch the component.

## Component Library

- **Use the project's base components** for all standard UI elements — buttons, inputs, selects, checkboxes, badges, avatars, modals, slideouts, tables.
- **NEVER use raw HTML elements** for interactive controls in feature code:
  - `<button className="...">` → use the project's `Button` component
  - `<input className="...">` → use the project's `Input` component
  - `<select>` → use the project's `Select` component
  - `<table>` with manual styling → use the project's `DataTable` or `Table` component
- **Exception**: Base component implementation files themselves may use raw HTML elements — that's where the abstraction is defined.
- When composing UI, check if a component already exists before building from scratch. Duplicating a card layout or badge style that already exists in the design system is a consistency violation.

## Icon Usage

- **Use the project's icon library** — never add inline `<svg>` elements in feature components.
- Icons should be imported as components and sized via the project's standard classes (e.g., `size-4`, `size-5`).
- Icon color should use semantic foreground tokens (`text-fg-primary`, `text-fg-secondary`, `text-fg-quaternary`), not raw colors.
- **Exception**: Highly specialized one-off illustrations or logos that don't exist in the icon library.

## Spacing & Layout

- Use the project's spacing scale consistently — don't mix arbitrary pixel values with Tailwind spacing tokens.
- Card styling must follow the project's established card pattern (check CLAUDE.md for the exact classes).
- Separators and dividers must use the project's separator convention — not ad-hoc border colors.

## Loading & Empty States

- Every page or data-dependent section must have a loading skeleton or spinner.
- Empty states should include an icon, title, and description — not just a text string.
- Error states should provide a clear message and, where possible, a recovery action (retry button).

## Typography

- Page titles and headings should use the design system's display text scale (`text-display-xs`, `text-display-sm`, etc.) rather than raw Tailwind sizes (`text-4xl`).
- Body text should use the standard text sizes from the design token system.
- Font weights should be consistent across similar UI patterns (e.g., all card titles use the same weight).

## Dark Mode

- Dark mode is handled at the design token level. Components should not need per-element dark mode classes when using semantic tokens.
- If dark mode requires additional treatment (e.g., different opacity, different shadow), add it to the design token system, not to individual components.
- Logos and images that don't adapt to dark mode should use a separate dark variant asset, not CSS `invert` or `filter` hacks.
