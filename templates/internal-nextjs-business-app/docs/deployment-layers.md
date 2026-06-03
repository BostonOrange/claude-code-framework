# Deployment Layers

This doc defines the three layers a project built with this framework can sit at, and the controls each layer requires. It is written for IT, security, and framework maintainers — **end users don't need to read it**.

End users see the product as: *"I build a thing for myself. If my team wants it too, I ask, and it gets promoted."* The layer model lives behind that experience.

## The user mental model vs. the framework mental model

| The user says | The framework calls it | Who decides |
|---|---|---|
| "I want to try an idea." | Layer 1 (local personal) | User, immediately |
| "My team should use this." | Promote to Layer 2 (shared internal, non-critical) | IT review + framework checks |
| "The business depends on this" or "customers/field workers use it." | Layer 3 (business-critical or external-facing) | Formal project, not a promotion |

The template's job is to make Layer 1 *automatically* prepared for Layer 2, so promotion is configuration + review, not a rewrite.

Layer 3 is intentionally **not** an automatic graduation — see [Why Layer 3 is different](#why-layer-3-is-different).

---

## Layer 1 — Local personal usage

**Definition.** One person, on their own machine, exploring an idea. No other humans depend on it. No real customer or business data of record.

**Defaults the framework ships with:**

| Concern | Layer 1 default | Where |
|---|---|---|
| Auth | `AUTH_MODE=dev` (fake user, no SSO) | `src/lib/auth/`, `.env.example` |
| Data | Local Postgres via `docker-compose.yml` | `prisma/`, `DATABASE_URL` |
| Blob storage | Azurite (local emulator) | `AZURE_STORAGE_CONNECTION_STRING=UseDevelopmentStorage=true` |
| AI | `AI_PROVIDER=mock` (no external calls) | `src/lib/ai/` |
| Secrets | `.env` on the developer's machine only | `.env.example` |
| Audit log | Schema present, written to local DB | `src/lib/audit-log/`, `prisma/` |
| Hosting | `npm run dev` on localhost | — |
| Review | None required | — |

**The Layer 1 contract:** the user does not need to think about any of the rows above. The defaults work out of the box. If they later want to share, every row has a documented Layer 2 swap that doesn't require touching application code.

---

## Layer 2 — Shared internal tool, non business-critical

**Definition.** A team or division uses the tool. Real internal data may be involved, but the business does not depend on the tool to operate. Users are on-prem Entra identities. Failure is annoying, not damaging.

**What changes from Layer 1:**

| Concern | Layer 2 requirement | How it's satisfied |
|---|---|---|
| Auth | `AUTH_MODE=oidc` against Entra; `OIDC_ALLOWED_EMAIL_DOMAINS` set | Env vars only — code is already wired (`src/lib/auth/oidc.ts`) |
| Data | Hosted Postgres (Vercel/Neon/Supabase/Azure) | Swap `DATABASE_URL`; Prisma migrations apply unchanged |
| Blob storage | Azure Storage-compatible connection string | Swap `AZURE_STORAGE_CONNECTION_STRING`; abstraction is at `src/lib/blob/client.ts` |
| AI | Real provider with org-issued key, OR keep `mock` if AI is optional | Env vars |
| Secrets | Hosting platform secret store (Vercel envs, Azure Key Vault) | No `.env` files in production |
| Audit log | Same schema, hosted DB, retained | No code change |
| Hosting | Vercel / Azure App Service / equivalent | `Dockerfile` + `infra/` provided |
| Review | One pass each from `security-auditor`, `observability-reviewer`, `supply-chain-reviewer` | `/team review` plus those three |
| Backups | Provider-managed Postgres backups enabled | Hosting choice |
| Monitoring | Application logs reach a central destination | Hosting/platform logging configuration; add app-specific logger when needed |

**Promotion checklist (the artifact IT signs off on):**

- [ ] `AUTH_MODE=oidc` and Entra app registration completed (tenant/client IDs, redirect URI)
- [ ] `OIDC_ALLOWED_EMAIL_DOMAINS` restricts access to expected divisions
- [ ] No secrets in the repo or in `.env` files in the deployed environment
- [ ] Database is hosted, has automated backups, and is not the developer's laptop
- [ ] Audit log table exists in production and is being written
- [ ] `/team review` has been run on the current branch and findings are addressed or risk-accepted in writing
- [ ] `security-auditor`, `observability-reviewer`, `supply-chain-reviewer` have run with no unresolved high-severity findings
- [ ] Owner identified (a named human who responds when it breaks)
- [ ] Layer recorded in the project (e.g. `LAYER=2` in repo metadata or a `LAYER.md` file)

**What is explicitly NOT required at Layer 2:** formal threat modelling, penetration testing, change management board review, DR drills, customer-data classification. Those belong to Layer 3.

---

## Layer 3 — Business-critical or external-facing

**Definition.** Either:
- The business cannot operate (or operates degraded) without the tool, **or**
- The tool is used by people outside the on-prem Entra directory — customers, partners, or field workers without corporate identities.

**Why Layer 3 is different.** Layers 1 → 2 is a *graduation*: the same codebase, mostly the same controls, more configuration and a review pass. Layer 3 is a *project*: it requires decisions the framework cannot make for the team.

Examples of decisions Layer 3 forces that Layer 2 does not:

- **Identity model for external users.** Entra B2C? A separate IdP? Magic links? Each has different threat model and lifecycle implications. The framework's current `oidc.ts` is hand-rolled and acceptable for internal-only Entra; an external-facing surface should move to a vetted library (`openid-client`, NextAuth, Auth.js, or an IdP SDK).
- **Data classification and residency.** Where is customer data allowed to live? What is the retention policy? Who is the data controller? These are legal/compliance answers, not framework defaults.
- **Availability and DR targets.** RTO/RPO that satisfies "the business depends on this" requires capacity planning and tested recovery — not just provider-managed backups.
- **Threat model.** External attack surface must be enumerated and reviewed; this is a deliverable, not an agent run.
- **Change management.** Releases that affect business operations need a control gate beyond `/team review`.

**The framework's role at Layer 3:** the same reviewer agents and rules still apply (and are still useful), but they are *inputs to* a Layer 3 project, not the gate. The promotion-by-checklist model is replaced by an explicit project plan signed off by IT, security, legal, and the business owner.

If a team asks to promote from Layer 2 → Layer 3, the answer is: *"That's a project. Open a ticket; we'll scope it together."*

---

## Control matrix at a glance

| Control | Layer 1 | Layer 2 | Layer 3 |
|---|---|---|---|
| Auth | Dev mode | Entra OIDC, domain allowlist | Vetted library, external IdP, MFA enforced |
| Data store | Local Postgres | Hosted Postgres + backups | + Encryption-at-rest review, residency, retention policy |
| Secrets | `.env` on laptop | Platform secret store | + Rotation policy, access logged |
| Audit log | Local DB | Hosted DB, retained | + Tamper evidence, monitored |
| Logging | stdout | Centralised | + Alerting on security events |
| Review | None | `/team review` + 3 specialists | + Threat model + pen test + change board |
| Hosting | localhost | Single hosted region | + Multi-AZ / DR plan |
| Backup | None | Provider-managed | + Tested restore |
| Owner | The builder | Named human | Named team + on-call |
| Approval | None | IT sign-off on checklist | Formal project sign-off |

---

## How Layer 1 stays "Layer 2-ready"

The template keeps this property by making every Layer-2-relevant concern an *adapter* in Layer 1, not a rewrite:

- **Auth.** `AUTH_MODE` switch already exists; OIDC code path is implemented and tested in dev mode. Promotion = set env vars.
- **Data.** Prisma schema is the same locally and hosted. Promotion = swap `DATABASE_URL`.
- **Blob storage.** Code calls `src/lib/blob/client.ts`; the adapter uses the Azure Storage SDK. Azurite works locally and Azure Storage works in hosted environments. Promotion = swap connection string.
- **AI.** `AI_PROVIDER=mock` returns deterministic fake responses; swapping to a real provider is an env change, not a code change.
- **Audit log.** Already written at Layer 1, against a real schema. Promotion = same code, hosted DB.

If you find yourself adding a Layer-2 concern that *isn't* an adapter — e.g., authentication code that hard-codes a provider, or storage code that imports an Azure SDK directly from a route handler — that's a regression in the "Layer 1 is Layer 2-ready" property. Fix it before it propagates.

---

## What this doc is for

| Reader | What they take from this doc |
|---|---|
| End user (business builder) | Nothing — they don't read this. They use the tool, and ask to share when ready. |
| IT / security reviewer | The Layer 2 promotion checklist. The Layer 3 boundary. |
| Framework maintainer | The "Layer 1 stays Layer 2-ready" invariant. New features must respect it. |
| Project sponsor | The Layer 3 definition, so they know when to open a project rather than ask for a promotion. |
