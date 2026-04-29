---
id: auth-security
patterns:
  - {{SOURCE_PATTERNS}}
---

# Authentication and Security Rules

When editing authentication, authorization, session, or API route files, enforce these security patterns. These prevent auth bypass, privilege escalation, and common web vulnerabilities.

## Fail-Closed Authentication

- **Authentication must NEVER default to open.** If auth configuration is missing (env vars unset, DB unavailable, provider unreachable), the application must DENY access — not grant it.
- Dev-mode auth bypass must require an explicit opt-in flag (e.g., `DEV_MODE=true` or `AUTH_BYPASS=true`), never be triggered by the absence of configuration.
- The application must refuse to start in production without required auth configuration. Add a startup check that crashes with a clear error message.
- If you find patterns like `if (!authConfig) { next(); return; }` or `if (!pool) return true;`, flag them — these are fail-open patterns.

## Session Security

- **Session secrets must not have insecure defaults.** No `"dev-only-insecure-key"` or similar fallback values. The application must crash if the session secret is not explicitly configured in production.
- Session cookies in production must have: `Secure=true` (HTTPS only), `HttpOnly=true` (no JavaScript access), `SameSite=Strict` or `Lax` (never `None` without CSRF protection).
- Prefer server-side session storage over client-side cookies for applications handling sensitive data — client-side sessions cannot be revoked.
- Session duration must be bounded (e.g., 8 hours) with explicit expiry handling.

## CSRF Protection

- **All state-changing endpoints (POST, PUT, PATCH, DELETE) in form-based applications must have CSRF protection.** This includes:
  - CSRF token in every HTML form (hidden field)
  - Token validation on the server for every state-changing request
  - `SameSite=Strict` cookies as defense-in-depth
- API-only applications using Bearer tokens are inherently CSRF-safe (tokens are not auto-sent by browsers), but form-based apps with cookie auth are vulnerable.
- If the application uses HTMX, ensure CSRF tokens are included in HTMX request headers or form data.

## Role-Based Access Control

- **If roles exist in the data model, they MUST be enforced in route handlers.** Roles defined in the database but not checked in code are security theater.
- Every state-changing endpoint must verify the user has the required role BEFORE performing the action.
- Read-only roles must not be able to access write endpoints. Export endpoints that return PII must require appropriate roles.
- The reviewer/approver identity must come from the authenticated session — never accept it from client-supplied form data or request bodies. This prevents audit trail manipulation.

## Redirect Validation

- **All redirect URLs must be validated before use.** Never redirect to a URL taken from user input, query parameters, or session storage without validation.
- Redirect targets must be relative paths (start with `/`, not `//` or `http`). Reject absolute URLs.
- If redirect-after-login is needed, store only the path (not the full URL with host) and validate it is a known application route.

## Security Headers

- All web applications must set baseline security headers: `Strict-Transport-Security`, `X-Content-Type-Options: nosniff`, `X-Frame-Options: DENY`, `Referrer-Policy`.
- CSP (Content-Security-Policy) should be configured but requires per-application tuning.
- External scripts and stylesheets loaded from CDNs must include Subresource Integrity (SRI) hashes.

## Build Safety

- **Never set `ignoreBuildErrors: true`** (Next.js) or equivalent flags that suppress type/compilation errors during production builds. Type errors that could indicate security bugs (incorrect casts, missing null checks) must fail the build.
- If pre-existing type errors block the build, fix them with targeted suppressions (`@ts-expect-error`, `# type: ignore`) rather than disabling the entire type checker.

## Rate Limiting

- Authentication endpoints (login, token refresh) must have rate limiting to prevent brute force.
- Endpoints that trigger expensive operations (AI calls, file processing, bulk exports) must have per-user or per-IP rate limiting.
- The rate limit key must be derived from the authenticated session or IP address — never from client-supplied headers.

## Input Validation at Boundaries

- All user input entering the system (API request bodies, form data, URL parameters, file uploads) must be validated against a schema before processing.
- Use a validation library (Zod, Pydantic, Joi, etc.) rather than manual `if` checks — validation libraries are harder to get wrong and produce consistent error messages.
- File uploads must validate: file type (MIME + magic bytes), file size, and filename characters. Filenames must be sanitized (strip path separators, reject `..` sequences) or replaced with UUIDs to prevent path traversal.

## CORS Configuration

- **Never use `Access-Control-Allow-Origin: *` with `Access-Control-Allow-Credentials: true`.** This allows any website to make authenticated cross-origin requests.
- If CORS is needed, use an explicit allow-list of trusted origins — never reflect the `Origin` header without validation.
- Preflight responses (`OPTIONS`) should be cached (`Access-Control-Max-Age`) to reduce overhead.

## Outbound Request Validation (SSRF Prevention)

- **Never fetch URLs directly from user input** (webhooks, image proxies, URL previews, import-from-URL features) without validation.
- Validate that user-supplied URLs resolve to public IP addresses — block private/internal ranges (`10.x`, `172.16-31.x`, `192.168.x`, `127.x`, `169.254.x`, `::1`, `fc00::/7`).
- Use an allow-list of permitted schemes (`https://` only where possible) and domains when the set of valid targets is known.
- If the application must fetch arbitrary URLs, use a dedicated outbound proxy with network-level restrictions.
