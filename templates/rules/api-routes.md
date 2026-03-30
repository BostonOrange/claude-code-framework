---
patterns:
  - {{API_ROUTE_PATTERNS}}
---

# API Route Rules

When editing API route files, follow these rules:

## Input Validation
- Validate ALL request input at the handler boundary before any business logic
- Use the project's validation library (Zod, Pydantic, struct tags, etc.)
- Never trust client-provided data — validate types, ranges, and formats

## Authentication & Authorization
- Every endpoint must have an authentication check unless explicitly documented as public
- Check authorization (permissions) after authentication, before data access
- Never rely solely on client-side auth checks

## Response Format
- Return structured error responses with appropriate HTTP status codes
- Never return raw exception messages or stack traces to clients
- Use consistent response envelope format across all endpoints

## Logging
- Log request metadata (method, path, status code, duration)
- Never log request/response bodies containing PII or credentials
- Include correlation/request IDs in log entries

## Rate Limiting
- Public endpoints must have rate limiting configured
- Document rate limit expectations in endpoint comments
