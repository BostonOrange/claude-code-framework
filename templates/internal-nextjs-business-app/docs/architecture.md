# Architecture

The starter separates the reusable platform layer from the business-specific layer.

## Platform Layer

- `src/lib/auth`: session cookies, dev auth, OIDC SSO
- `src/lib/db`: Prisma client singleton
- `src/lib/users`, `src/lib/tasks`, `src/lib/files`, `src/lib/audit-log`: repository boundaries over Prisma
- `src/lib/blob`: private object storage boundary
- `src/lib/ai`: AI provider boundary
- `src/lib/http`: API helpers such as rate limiting and JSON errors
- `src/app/api/health`: operational readiness endpoint

## Business Layer

The starter uses `Task` as a placeholder business object. For a real app, replace it with the team's actual operational object, for example:

- customer onboarding case
- contract review request
- compliance exception
- IT access request
- finance approval

The important pattern is the same: relational state in Postgres, private objects in blob storage, auth and audit at every boundary, and AI used as a workflow accelerator rather than a hidden source of truth.

Prisma is intentionally treated as an internal persistence tool. Route handlers and pages should not build queries directly; they call repository modules. That gives the same shape as the Hemfrid backend's storage/service boundary while keeping the developer speed and schema safety of Prisma.

## Local Runtime

```text
npm run dev
  -> scripts/setup-dev.mjs
     -> Docker Compose: Postgres + Azurite
     -> Prisma generate
     -> Prisma db push
     -> seed demo data
  -> Next.js dev server
```

## Hosted Runtime

```text
Browser
  -> Next.js Container App
     -> OIDC provider for SSO
     -> Postgres for relational state
     -> Blob Storage for private files
     -> AI provider through server-side route only
```
