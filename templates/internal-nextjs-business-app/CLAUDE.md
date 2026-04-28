# App Creator Instructions

This repo is a reusable Next.js internal-tools starter. Keep changes local-first and production-ready.

## Stack

- Next.js App Router, TypeScript strict mode
- Prisma with Postgres
- OIDC SSO in production, dev login locally
- Azure Blob Storage compatible API, Azurite locally
- Server-side AI provider adapter

## Conventions

- Server Components by default. Use `"use client"` only for interactive controls.
- Validate all API request bodies with Zod.
- All protected API routes must call `requireApiUser`.
- All server-rendered protected pages must call `requireUser`.
- Keep Prisma usage inside `src/lib/db` and repository modules. Pages and API routes should call repositories/services.
- Keep provider secrets server-side only.
- Add audit logs for business state changes, file uploads, permission changes, and destructive actions.
- Store relational workflow state in Postgres and private binary/object data in blob storage.
- Prefer narrow, boring models first. Expand once the workflow is proven by users.

## Commands

```bash
npm run doctor
npm run setup
npm run dev
npm run typecheck
npm run lint
npm run build
```

## Deployment Notes

- `npm run dev` is for local setup and uses `prisma db push`.
- Hosted environments should use migrations.
- The Docker image expects `next.config.ts` standalone output.
- `AUTH_MODE=oidc` requires `APP_URL`, `OIDC_ISSUER`, `OIDC_CLIENT_ID`, `OIDC_CLIENT_SECRET`, and `SESSION_SECRET`.
