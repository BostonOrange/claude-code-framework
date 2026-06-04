---
name: promote
description: Build a Layer 2 promotion evidence package for the internal Next.js business app template.
---

# Promote

Produce an evidence package for moving an internal Next.js business app from Layer 1 to Layer 2. This is not an approval step and must not update `LAYER.md` to `2`; IT does that after sign-off.

## Usage

```
/promote
/promote --layer 2
```

Only Layer 2 is supported. Layer 3 is a formal project, not a checklist promotion.

## Preconditions

The target repo should be an internal Next.js business app created from this framework:

- `LAYER.md` exists and has no `<<intake:*>>` tokens.
- `package.json`, `prisma/schema.prisma`, `src/lib/auth`, `src/lib/blob/client.ts`, and `src/lib/audit-log/repository.ts` exist.
- `docs/deployment-layers.md` exists in the provisioned repo, or the source template doc is available from the framework.

If `LAYER.md.template` exists or intake tokens remain, stop. The repo has not been provisioned correctly.

## Process

### Phase 1: Mechanical Checks

Run read-only checks first and record the command/result in the report.

Required checks:

1. Confirm the working tree is clean:
   ```bash
   git status --short
   ```
2. Confirm `LAYER.md` exists and `LAYER.md.template` does not:
   ```bash
   test -f LAYER.md && test ! -f LAYER.md.template
   ```
3. Confirm no intake tokens remain in stamped seed files:
   ```bash
   grep -n "<<intake:" LAYER.md README.md CLAUDE.md 2>/dev/null
   ```
   The command should produce no output. Documentation files may still mention token names as examples.
4. Confirm no committed local env files:
   ```bash
   git ls-files | grep -E '(^|/)\.env($|\.|/)' | grep -vE '(^|/)\.env\.example$'
   ```
   `.env.example` is allowed. Any committed `.env`, `.env.local`, `.env.production`, or equivalent is a blocker.
5. Run a focused secret scan over tracked files:
   ```bash
   git grep -n -E 'sk-proj-|sk-org-|AKIA[0-9A-Z]{16}|-----BEGIN .*KEY-----|client_secret|password' -- .
   ```
   Treat findings in examples/docs as warnings unless they contain real-looking values.
6. Confirm Layer 2-relevant app boundaries exist:
   ```bash
   test -f src/lib/auth/oidc.ts
   test -f src/lib/blob/client.ts
   test -f src/lib/audit-log/repository.ts
   test -f prisma/schema.prisma
   ```
7. Run the project validation commands when dependencies are installed:
   ```bash
   npm run typecheck
   npm run lint
   npm run build
   npm audit --audit-level=high
   ```
   If dependencies are missing, record that validation could not run and list the missing prerequisite.

### Phase 2: Specialist Reviews

Run these review agents and include their summaries in the report:

- `security-auditor`
- `observability-reviewer`
- `supply-chain-reviewer`

Ask each reviewer to focus on Layer 2 promotion readiness for an internal, non-business-critical tool. High-severity findings are blockers unless risk-accepted by IT in writing.

### Phase 3: Manual Evidence

Record these as manual checklist items. Do not mark them passed unless the user provides concrete evidence during the session.

- Entra app registration exists with redirect URI matching the hosted `APP_URL`.
- `AUTH_MODE=oidc` is configured in the hosted environment.
- `OIDC_ALLOWED_EMAIL_DOMAINS` restricts access to the intended division/team.
- Production secrets live in the hosting platform secret store or Key Vault, not repo files.
- Hosted Postgres is configured and automated backups are enabled.
- Production audit log table exists and retention is defined.
- Application logs reach a central destination.
- Named owner is confirmed and reachable.

### Phase 4: Report

Write `.claude/state/promotion-l2-report.md`. Create `.claude/state/` if needed.

Use this structure:

```markdown
# Layer 2 Promotion Evidence

Generated: <ISO timestamp>
Repo: <repo name or path>
Commit: <git rev-parse HEAD>
Requested layer: 2
Current layer: <from LAYER.md>
Owner: <from LAYER.md>

## Result

Status: BLOCKED | READY_FOR_IT_REVIEW

## Mechanical Checks

| Check | Result | Evidence |
|---|---|---|
| Clean working tree | PASS/FAIL | <command output summary> |

## Specialist Reviews

### security-auditor
<summary and blockers>

### observability-reviewer
<summary and blockers>

### supply-chain-reviewer
<summary and blockers>

## Manual Evidence Required

| Item | Status | Evidence |
|---|---|---|

## Blockers

- <blocker or "None">

## Notes For IT

- This report is evidence only. It does not approve promotion and did not modify `LAYER.md`.
```

`READY_FOR_IT_REVIEW` means the mechanical checks passed and no unresolved high-severity reviewer findings remain. Manual evidence may still need IT verification.

## Hard Rules

- Do not update `LAYER.md` to `2`.
- Do not create production secrets or Entra registrations.
- Do not deploy the app.
- Do not treat this report as approval.
- Do not proceed for Layer 3; tell the user to open a formal project intake.
