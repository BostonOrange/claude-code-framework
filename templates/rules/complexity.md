---
id: complexity
patterns:
  - {{SOURCE_PATTERNS}}
---

# Complexity Rules

Citable standards used by the `complexity-reviewer` agent. The thresholds are pragmatic, not absolute — exceeding them isn't always wrong, but it's a signal that something can probably be simplified.

## Function Length

| Range | Action |
|-------|--------|
| ≤30 lines | Fine |
| 31–50 | Acceptable; check if it has multiple sub-steps that could extract |
| 51–80 | Probably too long; flag and propose extraction |
| >80 | Almost certainly doing multiple things; flag |

**Don't count:** blank lines, comments, single-token lines (closing braces).

**Suppress for:** tests, fixtures, lookup tables, switch statements over a closed enum (each case is one branch), generated code, JSX/template-heavy UI components where most lines are markup.

## Cyclomatic Complexity

Count of independent paths through a function. Roughly: 1 + count of `if`, `else if`, `case`, `&&`, `||`, `?:`, `for`, `while`, `catch`.

| Range | Action |
|-------|--------|
| 1–5 | Fine |
| 6–10 | Watch; usually OK |
| 11–15 | Refactor recommended; flag |
| >15 | Refactor required; flag |

**Common reductions:**
- Replace conditional chains with table lookups
- Extract guard clauses into a validator and `return early`
- Replace nested `if/else` with polymorphism / strategy
- Split into two functions along the natural seam

## Nesting Depth

Max indentation level for control structures (`if`, `for`, `while`, `try`, `with`).

| Depth | Action |
|-------|--------|
| 1–3 | Fine |
| 4 | Last warning — refactor opportunity |
| ≥5 | Flag |

**Common reductions:**
- Guard clauses with early `return` / `continue` / `break`
- Extract inner loops/blocks into named helpers
- Invert conditions to flatten

```ts
// Bad — depth 4
function process(items: Item[]): void {
  for (const item of items) {
    if (item.active) {
      if (item.qty > 0) {
        if (item.price > 0) {
          ship(item);
        }
      }
    }
  }
}

// Good — depth 1
function process(items: Item[]): void {
  for (const item of items) {
    if (!item.active || item.qty <= 0 || item.price <= 0) continue;
    ship(item);
  }
}
```

## Parameter Count

| Count | Action |
|-------|--------|
| 0–4 | Fine |
| 5–6 | Acceptable; consider parameter object |
| ≥7 | Flag — introduce parameter object |

**Don't flag:** constructors of value objects (their parameters are the fields), variadic signatures, generated code.

## Branch Density

Ratio of conditional statements to total lines. A function that's 30 lines but contains 12 `if`s is harder to follow than one of 60 lines with 3 `if`s.

**Heuristic:** if more than 1 in 4 logical lines is a branch, the function is doing decision-making more than work. Consider splitting decision-making (a routing function) from execution (the work each branch does).

## Cognitive Complexity (qualitative)

Cyclomatic complexity treats every branch equally. Cognitive complexity weights nested branches more heavily — a `for` inside an `if` inside a `try` is much harder to follow than three sibling branches.

**Detect:** any function where you have to scroll, page, or hold mental state across more than one screenful to follow what it does.

**Fix:** extract; rename for clarity; introduce intermediate named values for sub-expressions.

## What NOT to Flag

- **Switch/match over a closed enum.** Each case is shallow and the structure is a feature, not a smell.
- **Validation chains.** A list of guard clauses at the top of a function is high cyclomatic but very low cognitive complexity. Don't flag.
- **Pure data tables / config maps** declared inline as long literals.
- **Performance-critical hot paths** where the alternative (function calls, allocations) measurably hurts. Comment-justify the choice.
- **DSL-style code** (route definitions, query builders, schema definitions) that's declarative even if it parses as one long expression.
- **Test setup** in fixtures and factories.
- **JSX/template UI** where line count is dominated by markup, not logic.
- **Generated code.**
