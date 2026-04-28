---
name: port-vercel
description: Prepare Vercel environment guidance for an internal Next.js business app without forking the stack
allowed-tools: Read, Write, Edit, Glob, Grep
---

Prepare the app for Vercel as an environment and deployment target, not a separate code stack.

## Steps

1. Inspect `docs/setup.md`, `.env.example`, `package.json`, `next.config.ts`, and `src/lib/blob/client.ts`.
2. Update docs/env guidance for:
   - `APP_URL`
   - `AUTH_MODE=oidc`
   - `SESSION_SECRET`
   - `OIDC_*`
   - `DATABASE_URL` from Vercel Marketplace, Neon, Supabase, or another managed Postgres provider
   - Vercel Blob env such as `BLOB_READ_WRITE_TOKEN` when the app template has that adapter
3. Keep Prisma and the storage boundary unchanged unless the blueprint explicitly requires adapter work.
4. Report what changed and what must be configured in the Vercel dashboard.
