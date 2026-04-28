---
name: generate-internal-app
description: Adapt the internal Next.js business app template from an app blueprint.
---

# Generate Internal App

Consume an app blueprint and modify the internal Next.js business app template into a working business application. This skill owns orchestration and code generation steps; keep the app's core architecture inside the app template.

## Usage

```
/generate-internal-app docs/app-blueprint.json
/generate-internal-app docs/app-blueprint.json --feature invoice-approval
```

If no blueprint path is provided, look for `docs/app-blueprint.json`. If it is missing, run `/app-blueprint` first.

## Preconditions

The target repo should contain the internal app preset:

- `package.json`
- `prisma/schema.prisma`
- `src/app/api`
- `src/lib/db/prisma.ts`
- `src/lib/blob/client.ts`
- `src/lib/auth`

If these are missing, stop and tell the user to re-run setup with the "Internal Next.js Business App" preset.

## Process

1. Validate the blueprint JSON.
   - Ensure `appName`, `usersAndRoles`, `entities`, `workflows`, `permissions`, `filesBlobNeeds`, `auditEvents`, `dashboardsViews`, and `aiAssistPoints` exist.
   - Report open questions that block safe generation.
2. Plan the generation slice.
   - Full app: generate all core entities and views.
   - Feature mode: generate only the requested workflow/entity slice and do not churn unrelated files.
3. Update Prisma.
   - Add enums for entity statuses and role/action concepts where useful.
   - Add models for blueprint entities.
   - Keep `User`, `FileObject`, and `AuditLog` unless the blueprint explicitly replaces them.
   - Prefer relational foreign keys over denormalized JSON for workflow state.
4. Generate repository modules under `src/lib/<entity>/repository.ts`.
   - Keep Prisma calls inside repositories.
   - Return plain domain objects to routes/pages.
   - Add create/update/status-transition helpers matching workflows.
5. Generate API routes under `src/app/api/<entity>/route.ts` and focused subroutes when needed.
   - Use auth helpers from `src/lib/auth`.
   - Validate input with Zod.
   - Create audit events for every workflow transition.
   - Keep blob operations behind `src/lib/blob/client.ts`.
6. Generate dashboard UI.
   - Add queue/table/detail/form views from `dashboardsViews`.
   - Keep operational density appropriate for internal tools.
   - Include file upload controls only where `filesBlobNeeds` requires them.
7. Update seed data in `prisma/seed.ts`.
   - Seed users/roles and a small synthetic sample for each generated workflow.
   - Never use real PII.
8. Add tests where the app has a test harness.
   - If no harness exists, add a short `docs/stories/<feature>/how-to-test.md` with manual and typecheck validation.
9. Update docs.
   - `README.md`: app-specific quick start and core workflows.
   - `docs/setup.md`: provider notes only when generation changes env needs.
   - `docs/stories/<feature>/`: generated story, solution components, how-to-test, manual steps.
10. Run validation.
   - `npm run typecheck`
   - `npm run lint`
   - `npm run build` when dependencies and env are available.

## Ownership Boundaries

The framework may:

- Read the blueprint.
- Modify app code in the target repo.
- Add docs/stories and validation notes.
- Preserve one app stack while preparing environment guidance for hosting providers.

The framework must not:

- Fork the app into separate Vercel/Azure/local codebases.
- Bypass Prisma with ad hoc database calls in routes/pages.
- Hardcode provider-specific blob logic outside `src/lib/blob/client.ts`.
- Generate AI actions that silently change workflow state without a human action.

## Output

End with:

- Files changed, grouped by Prisma, repositories, API, UI, tests, docs.
- Validation commands run and their result.
- Any generation gaps that need app-creator template support.
