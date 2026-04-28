---
id: docs-staleness
patterns:
  - "**/*"
---

# Docs Staleness Rule

Material changes to project shape (package manager, test framework, build tool, directory layout, env vars, CI workflows) MUST be accompanied by an update to CLAUDE.md / AGENTS.md / project-level docs in the same MR. AI coding agents rely on those files to understand conventions; stale docs make agents stubbornly reproduce old patterns.

## What counts as a material change (MUST update docs)

| Change type | Triggers update |
|-------------|-----------------|
| Package manager swap | `package-lock.json` ↔ `pnpm-lock.yaml` ↔ `yarn.lock` ↔ `bun.lockb` |
| Test framework swap | jest → vitest, pytest → unittest, rspec → minitest, etc. |
| Build tool swap | webpack → vite, gulp → esbuild, pip → poetry, etc. |
| Major directory restructure | renaming `src/` to `app/`, splitting modules |
| New required env vars | additions to `.env.example` or settings schemas |
| CI/CD workflow changes | new `.github/workflows/*.yml`, new pipeline stages, new deployment targets |
| Framework migration | Next.js Pages Router → App Router, React → Solid, Express → Fastify |
| Database / ORM swap | Prisma → Drizzle, raw SQL → ORM, MySQL → Postgres |
| Auth provider swap | NextAuth → Clerk, custom session → Auth0 |
| Public API contract change | new/removed endpoints, breaking response schema changes |

When any of the above land without a corresponding CLAUDE.md / AGENTS.md / README change in the same diff, flag as a `warning`-severity finding citing this rule.

## What is medium materiality (SUGGEST update)

| Change type | Suggest update |
|-------------|----------------|
| Major dependency bump (major version) | only if conventions change |
| New linting rules | if they affect code style agents should follow |
| New API client wrappers | if shared usage patterns emerge |
| State management library change | Redux → Zustand, MobX → Jotai |

## What is low materiality (DON'T flag)

- Bug fixes that don't change conventions
- Feature additions using existing patterns
- Minor dependency bumps (patch/minor)
- CSS / styling changes
- Test additions to existing test framework
- Refactors that preserve external behavior

## Anti-patterns to flag in existing CLAUDE.md / AGENTS.md

When reviewing a CLAUDE.md update (or noting that one is missing), also penalize these existing-doc smells:

- **Generic filler** ("write clean code", "follow best practices") — useless to an agent
- **Files over 200 lines** — cause context bloat; lossy at compaction time
- **Tool names without runnable commands** ("we use jest") instead of (`npm test -- --watch`)
- **Out-of-date paths** referencing moved/renamed directories
- **Conventions described in negation only** ("don't use class components") without the positive ("use functional components with hooks")

A concise, command-driven CLAUDE.md is always better than a verbose conceptual one.

## How reviewers cite this rule

In findings JSONL:

```json
{
  "rule_id": "docs-staleness",
  "severity": "warning",
  "title": "Material change without CLAUDE.md update",
  "description": "<change details>",
  "remediation": "Update CLAUDE.md sections: <list>"
}
```
