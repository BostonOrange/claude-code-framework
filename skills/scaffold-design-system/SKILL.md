---
name: scaffold-design-system
description: Bootstrap design system infrastructure — detect or create theme tokens, base components, icon library, and CLAUDE.md design conventions
---

# Scaffold Design System

Bootstrap design system infrastructure for a project. Detects existing design patterns or creates new ones.

## Usage

```
/scaffold-design-system                    — Auto-detect and scaffold (interactive)
/scaffold-design-system detect             — Detect existing design system, document in CLAUDE.md
/scaffold-design-system untitled-ui        — Scaffold Untitled UI conventions
/scaffold-design-system shadcn             — Scaffold shadcn/ui conventions
```

## Process

### Phase 1: Discovery

Scan the project to understand what design infrastructure already exists.

**1.1 — Theme/Token files:**
```bash
find . -type f \( -name "theme.css" -o -name "tokens.*" -o -name "design-tokens.*" -o -name "globals.css" -o -name "variables.css" \) -not -path "*/node_modules/*" 2>/dev/null
```

**1.2 — Component library:**
```bash
# Check for base/ui component directories
find . -type d \( -name "base" -o -name "ui" -o -name "primitives" -o -name "atoms" \) -path "*/components/*" -not -path "*/node_modules/*" 2>/dev/null
# Count component files in those directories
find . -path "*/components/base/*" -o -path "*/components/ui/*" | grep -E "\.(tsx|jsx|vue)$" | wc -l
```

**1.3 — Icon library from package.json:**
```bash
grep -E "untitledui|lucide|heroicons|phosphor|tabler|ionicons|feather" package.json 2>/dev/null
```

**1.4 — CSS framework:**
```bash
grep -E "tailwindcss|@tailwindcss|styled-components|emotion|vanilla-extract|css-modules" package.json 2>/dev/null
```

**1.5 — Existing color patterns in components:**
```bash
# Count raw vs semantic color usage
echo "Raw Tailwind colors:"
grep -rn "text-gray-\|bg-gray-\|border-gray-\|text-blue-\|bg-blue-" --include="*.tsx" --include="*.jsx" . | grep -v node_modules | wc -l

echo "Semantic tokens:"
grep -rn "text-primary\|text-secondary\|text-tertiary\|bg-primary\|bg-secondary\|fg-primary" --include="*.tsx" --include="*.jsx" . | grep -v node_modules | wc -l
```

**1.6 — Accessibility library:**
```bash
grep -E "react-aria|radix-ui|headlessui|ariakit" package.json 2>/dev/null
```

### Phase 2: Assess Current State

Based on discovery, classify the project:

| State | Criteria | Action |
|-------|----------|--------|
| **No design system** | No theme tokens, no component library, raw Tailwind everywhere | Full scaffold |
| **Partial design system** | Some tokens or components exist but gaps remain | Fill gaps, document existing |
| **Mature design system** | Complete tokens, component library, icon library | Document in CLAUDE.md only |

### Phase 3: Scaffold (if needed)

Based on the chosen design system type:

**3.1 — Design System Rule:**
If `.claude/rules/design-system.md` doesn't exist, create it from the framework template. Customize the rule's guidance to match the project's specific tokens and component names.

**3.2 — Document in CLAUDE.md:**
Fill the design system section in CLAUDE.md:

- `## Design System` → `### Color Usage`: Document which semantic tokens to use, with examples from the actual theme file
- `### Component Imports`: List the base components with their import paths and key props
- `### Icon Usage`: Document the icon library, import pattern, and sizing convention
- `### Card & Layout Patterns`: Document the project's card styling pattern (border, background, shadow, radius)
- `### Dark Mode`: Document how dark mode works (tokens, class-based, media query)

**3.3 — Fill CLAUDE.md from actual project state:**

Read the theme/token files and extract:
- The semantic color token names that exist (e.g., `text-primary`, `bg-brand-solid`)
- The component library import paths
- The icon library name and import pattern
- The card/layout patterns in use

Replace any `{{DESIGN_*}}` placeholders with concrete, project-specific values.

### Phase 4: Validate

Run a quick check to verify the design system is documented:

```bash
# Check CLAUDE.md has design section filled
grep -c "Color Usage\|Component Imports\|Icon Usage\|Card.*Pattern\|Dark Mode" CLAUDE.md
```

Verify at least 4 of 5 design sections are filled (not placeholder `{{...}}` values).

### Phase 5: Report

```
## Design System Scaffold Report

### Project State
- **Theme tokens**: {found/created/missing}
- **Component library**: {found/none} — {count} components in {path}
- **Icon library**: {name or "none"}
- **Accessibility library**: {name or "none"}
- **Color usage**: {X}% semantic, {Y}% raw Tailwind

### Changes Made
| File | Change | Reason |
|------|--------|--------|
| CLAUDE.md | Filled design system section | Document conventions |
| .claude/rules/design-system.md | Created/updated | Enforce token/component usage |

### Design System Health
- Token coverage: {X}% of components use semantic tokens
- Component library usage: {X}% of interactive elements use base components
- Icon library usage: {X}% of icons use the library vs inline SVGs

### Recommendations
- {what to improve — e.g., "Add semantic tokens for status colors"}
- {what to add — e.g., "Create a Badge base component"}

### Next Steps
1. Review the design conventions in CLAUDE.md
2. Run `/validate` to check existing code against the new rules
3. Run `/team review` to get a full UI/UX assessment
```

## Edge Cases

| Scenario | Behavior |
|----------|----------|
| Backend-only project (Go, Python, Java) | Skip — report "No frontend, design system not applicable" |
| Project has no package.json | Try to detect framework from other config files |
| Multiple CSS frameworks | Document the primary one, note the others |
| Component library exists but isn't documented | Document it in CLAUDE.md without creating new components |
| CLAUDE.md has `{{DESIGN_*}}` placeholders | Fill them with discovered values |
| CLAUDE.md already has design section filled | Update with any new findings, don't overwrite existing documentation |

## Related Skills

- `/improve` — General self-improvement (includes design section, but less thorough)
- `/validate` — Code validation (includes design consistency checks after this skill runs)
- `/team review` — Full review including UI/UX agent (enhanced with design compliance)
