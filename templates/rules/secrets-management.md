---
id: secrets-management
patterns:
  - {{SOURCE_PATTERNS}}
---

# Secrets Management Rules

Citable standards. No dedicated reviewer agent — `security-auditor` covers secrets findings and cites this rule.

The principle: **secrets are values that must not appear in any artifact that lives longer than the secret itself**. Source code, container images, log lines, support tickets — all live longer than the secret should.

## Storage

**Detect:**
- Secrets hardcoded in source code (passwords, API keys, tokens, certs, connection strings)
- Secrets in `.env` files committed to the repo (even `.env.example` with real values)
- Secrets in `Dockerfile` `ENV` or `ARG` instructions baked into image layers
- Secrets in CI workflow YAML (use the CI's secret store)
- Secrets in K8s manifests as plain `env` (use `Secret` resources or external secret operator)
- Secrets in client-side code (`NEXT_PUBLIC_*`, `VITE_*`, `REACT_APP_*` — these are exposed to every visitor)
- Secrets in code comments or commit messages
- Secrets in test fixtures committed to git

**Fix:**
- Production secrets: dedicated secrets manager (AWS Secrets Manager, HashiCorp Vault, GCP Secret Manager, Azure Key Vault, 1Password Connect)
- Local dev: `.env` file gitignored; loaded via `dotenv` or equivalent
- `.env.example`: placeholders only, no real values
- CI: use the CI platform's secret store, not workflow YAML
- Client-side: never. Move the operation behind a backend that holds the secret

## Loading

**Detect:**
- Secrets read at every request instead of once at startup (perf + audit-log noise)
- Secrets cached in memory indefinitely without rotation hooks
- Secrets logged when loaded ("Loaded API key: sk-..." appearing in startup logs)
- Failures to load secrets that fall through to defaults (fail-open — overlap with `auth-security`)
- Secrets passed via command-line arguments (visible in `ps`, may be logged by shell history)

**Fix:**
- Load at startup; cache in memory; reload via SIGHUP or rotation event
- Crash on missing secret in production (fail-closed); never default
- Pass via env var or stdin to subprocesses, not argv
- Redact in any log output (logger config + a "secret-aware" pretty-printer)

## Rotation

**Detect:**
- Secrets without a documented rotation cadence
- No way to rotate without redeploying (the secret is baked into the build)
- Old secret revoked before new one is rolled out → downtime
- Long-lived API keys when short-lived tokens are available
- Personal access tokens used in service-to-service calls (rotate when the person leaves; should be a service account)

**Fix:**
- Document rotation cadence per secret (e.g., 90d for API keys, 30d for DB passwords, immediate for compromise)
- Hot-reload from secrets manager, not redeploy
- Dual-key window: roll out new, deprecate old over a window
- Use short-lived OIDC tokens / IAM role assumption where the platform supports it
- Service accounts for service-to-service; never personal credentials

## Rotation Hygiene Hooks

When this rule's reviewer / `security-auditor` finds:
- A leaked secret (in git history, log line, support ticket): rotate immediately, even if not "exploited yet". Assume compromised.
- An expired or near-expiry secret: rotate before expiry; don't wait for the outage.

## Secret Scanning

**Detect:**
- No pre-commit secret-scan hook
- No CI secret-scan step
- No git-history scan ever performed (secrets that leaked years ago and are still valid)
- Secret-scan rules excluded broadly without justification

**Fix:**
- Pre-commit hook: `gitleaks`, `trufflehog`, or framework's `pre-commit.sh` (already wired)
- CI step running secret scan on every PR + nightly on main
- Initial git-history scan once; rotate everything found
- Allowlist must be specific (path + rule ID), not blanket disable

## In-Code Discipline

**Detect:**
- Secret values printed in error messages: `throw new Error("Auth failed with key " + apiKey)`
- Secrets included in HTTP headers logged by middleware
- Secrets in URL query strings (logged by every reverse proxy / CDN / browser history)
- Secrets in form GET parameters
- Secrets passed in webhook payloads without TLS + signing
- Secrets included in stack traces / panic dumps / crash reports

**Fix:**
- Auth-failure messages: generic ("Authentication failed"); detailed only in server logs (never the value)
- Logger configured to redact common secret-shaped patterns
- Auth headers, never URL params (`Authorization: Bearer <token>`, not `?token=...`)
- POST / signed webhook bodies, never GET query strings
- Crash reporters (Sentry etc.) configured to scrub secret-shaped data

## Service Identity

**Detect:**
- Multiple services sharing one set of credentials (can't audit which service did what; can't rotate one)
- Long-lived static credentials where workload identity is available (IAM role, service account, OIDC)
- Service-to-service auth via shared bearer token (no key rotation, no revocation)

**Fix:**
- One credential per service per environment
- Workload identity where the platform supports it (no static credentials needed)
- Service-to-service: mutual TLS or short-lived tokens minted per call

## Test Discipline

**Detect:**
- Real secrets in test fixtures committed to git
- Tests that connect to production with read-only credentials (still: production exposure)
- Local dev seeded with realistic-looking secrets that get reused as actual secrets

**Fix:**
- Test secrets: synthetic, clearly fake, and gitignored if they're not all-zero placeholders
- Tests run against test environments with their own credential set
- Documented "this is a test secret, never reuse" markers (e.g., `test_test_test_...`)

## Incident Response

If a secret is found leaked:
1. **Rotate immediately** — assume compromised
2. Audit access logs for the leaked secret's value
3. Determine blast radius (what could the secret access?)
4. File an incident; document scope and remediation
5. Add a regression: scan rule that catches the leak pattern in the future

## What NOT to Flag

- **Placeholder values in `.env.example`** that are obviously not real (`YOUR_API_KEY_HERE`, `change-me`, `sk-test-...`)
- **Test fixtures with synthetic secrets** clearly marked as test data
- **Documentation showing example values** that are obviously not real
- **Vendored / generated config** with placeholder secrets that the deployment process replaces
- **Pre-existing secrets in code being deleted** — flag in the audit, don't block the PR that removes them
- **Secrets hashes used for testing the hashing logic** (if a test bcrypt-hashes a known input to verify the function, that's the test, not a secret leak)
