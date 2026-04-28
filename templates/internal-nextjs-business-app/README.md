# App Creator

AI-enabled Next.js boilerplate for internal tools. It starts with the plumbing most business apps need before the business model is known: local dev automation, Postgres, private blob storage, SSO-ready auth, health checks, secure defaults, and a server-side AI adapter.

## What You Get

- Next.js App Router with TypeScript strict mode
- One-command local stack: Next.js, Postgres, Azurite blob storage, Prisma schema sync, seed data
- Local dev login by default, OIDC/SSO for hosted environments
- Signed httpOnly session cookies
- Prisma/Postgres models hidden behind repository modules for users, tasks, private files, and audit logs
- Private blob upload route backed by Azurite locally or Azure Blob in production
- AI route with a mock provider by default and OpenAI-compatible provider when configured
- Health endpoint and security headers
- Dockerfile, Docker Compose, GitHub Actions CI, and Azure Bicep starter infra

## Quick Start

```bash
npm install
npm run dev
```

`npm run dev` does the setup work before starting Next.js:

1. Creates `.env.local` with a generated `SESSION_SECRET` if missing.
2. Starts Postgres and Azurite with Docker Compose.
3. Generates the Prisma client.
4. Pushes the schema to Postgres.
5. Seeds a demo admin and starter tasks.
6. Starts Next.js on `http://localhost:3000`.

Then open `http://localhost:3000` and sign in as the demo admin.

## Core Commands

```bash
npm run doctor       # Check local prerequisites
npm run setup        # Start services, sync schema, seed data
npm run dev          # Setup + Next.js dev server
npm run db:generate  # Generate Prisma client
npm run db:push      # Push schema to local Postgres
npm run db:seed      # Seed demo data
npm run typecheck
npm run lint
npm run build
```

## Environment

Copy `.env.example` to `.env.local` or let `npm run setup` create it.

Local defaults:

```env
AUTH_MODE=dev
DATABASE_URL=postgresql://app:app@localhost:55432/app_creator?schema=public
AZURE_STORAGE_CONNECTION_STRING=UseDevelopmentStorage=true
AI_PROVIDER=mock
```

Hosted SSO:

```env
AUTH_MODE=oidc
APP_URL=https://your-app.example.com
OIDC_ISSUER=https://login.microsoftonline.com/<tenant-id>/v2.0
OIDC_CLIENT_ID=<app-registration-client-id>
OIDC_CLIENT_SECRET=<app-registration-secret>
OIDC_ALLOWED_EMAIL_DOMAINS=example.com
SESSION_SECRET=<long-random-secret>
```

AI provider:

```env
AI_PROVIDER=openai
OPENAI_API_KEY=<server-side-api-key>
OPENAI_MODEL=<model-name>
```

The model is intentionally configured through env so the starter does not bake a model choice into application code.

## Where To Customize First

- `prisma/schema.prisma`: replace `Task` with the first real business object.
- `src/lib/tasks/repository.ts`: replace the demo task repository with the first real business repository.
- `src/app/dashboard/page.tsx`: replace the demo task board with the operator workflow.
- `src/app/api/tasks/route.ts`: use as the pattern for authenticated, validated API routes that call repositories.
- `src/lib/ai/provider.ts`: tune the server-side AI instructions for the domain.
- `src/lib/auth/oidc.ts`: keep the protocol code, adjust claims and role mapping if your IdP differs.
- `infra/main.bicep`: adapt naming, networking, SKUs, and secret wiring to your Azure standards.

## Data Access Pattern

Prisma is the database tool, but it should stay inside repository modules and `src/lib/db`. Pages and API routes should call domain repositories such as:

- `src/lib/users/repository.ts`
- `src/lib/tasks/repository.ts`
- `src/lib/files/repository.ts`
- `src/lib/audit-log/repository.ts`

This keeps the app close to the mature Hemfrid backend pattern: routes handle HTTP/auth/validation, repositories own persistence, and services can hold workflow logic as the app grows.

## Security Defaults

- All app API routes check the signed session.
- Input payloads use Zod validation.
- Sessions are httpOnly, sameSite=lax, and secure in production.
- OIDC uses authorization-code flow with PKCE, state, and nonce checks.
- File uploads are private and capped at 10 MB.
- AI provider keys never reach the browser.
- Health checks avoid leaking secret values.

## Production Checklist

- Set `AUTH_MODE=oidc`.
- Provision an Entra ID app registration with callback `${APP_URL}/api/auth/callback`.
- Replace local Postgres with managed Postgres.
- Replace Azurite with Azure Blob Storage.
- Store `SESSION_SECRET`, database URL, storage connection string, and OIDC secret in Key Vault or your platform secret store.
- Run Prisma migrations through CI/CD instead of `db push`.
- Review CSP additions for any third-party services you add.
