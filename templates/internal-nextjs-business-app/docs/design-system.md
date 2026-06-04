# Design System

Use this when shaping the first UI and all later app screens.

## Source

This project follows an internal-tools visual standard:

- Untitled UI-inspired product patterns
- a single brand color, set per project
- Inter as the product typeface
- restrained, business-first layouts
- semantic color tokens instead of raw color classes

## Product Tone

- Write for business users, not developers.
- Prefer concrete workflow language: `Opportunities`, `Owners`, `Follow-up`, `Status`, `Exceptions`.
- Avoid framework language in the UI: do not show `Next.js`, `Prisma`, `Blob`, `OIDC`, or `Layer` unless the screen is for IT/admin.
- The first screen should be the actual working tool, not a marketing page.

## Layout

- Use dense but calm application layouts.
- Prefer tables, filter bars, summaries, side panels, and task/detail views over large hero sections.
- Keep cards for repeated items, panels, modals, and framed tools. Do not nest cards inside cards.
- Keep border radius at `8px` or less unless an existing component requires otherwise.
- Make scan paths obvious: title, summary metrics, filters, primary table/list, detail panel.

## Colors

Use semantic tokens or CSS variables. Do not hard-code one-off palettes.

Example brand palette — replace these with your project's brand values:

```css
--brand-50: #eff6ff;
--brand-100: #dbeafe;
--brand-600: #2563eb;
--brand-700: #1d4ed8;
```

Preferred semantic names:

- text: `text-primary`, `text-secondary`, `text-tertiary`, `text-brand-secondary`, `text-error-primary`, `text-warning-primary`, `text-success-primary`
- borders: `border-primary`, `border-secondary`, `border-brand`, `border-error`
- backgrounds: `bg-primary`, `bg-secondary`, `bg-brand-solid`, `bg-success-primary`, `bg-warning-primary`, `bg-error-primary`
- icons: `fg-primary`, `fg-secondary`, `fg-tertiary`, `fg-brand-primary`

If the app is not using Tailwind token classes yet, define equivalent CSS variables and use those consistently.

## Components

When using the shared Untitled UI React component library:

- Base components live under `components/base/`.
- Application components live under `components/application/`.
- Foundation components live under `components/foundations/`.
- Use React Aria Components as the accessibility foundation.
- Prefix all imports from `react-aria-components` with `Aria`.

Correct:

```tsx
import { Button as AriaButton, TextField as AriaTextField } from "react-aria-components";
```

Incorrect:

```tsx
import { Button, TextField } from "react-aria-components";
```

## File Naming

All new files must use kebab-case:

- `opportunity-table.tsx`
- `salesforce-client.ts`
- `owner-filter.tsx`
- `mock-opportunities.ts`

Do not create PascalCase or camelCase filenames.

## Icons

Prefer Untitled UI icons when available.

```tsx
import { Home01, Settings01, ChevronDown } from "@untitledui/icons";
```

Use icons in buttons for recognizable actions. Decorative icons need `aria-hidden="true"`.

## States

- Show empty, loading, error, and no-results states.
- Disabled controls should use `disabled:cursor-not-allowed disabled:opacity-50` or equivalent CSS.
- For small hover/focus transitions, use a short transition around `100ms`.

## First App Screen Checklist

Before calling a UI done, make sure the app has:

- a business-specific title
- summary metrics relevant to the workflow
- a useful table/list or work queue
- filters or search where the data set can grow
- a clear empty state
- no raw technical setup language on the user-facing screen
- no hard-coded production credentials or real confidential records
