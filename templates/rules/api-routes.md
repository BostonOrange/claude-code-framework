---
patterns:
  - {{API_ROUTE_PATTERNS}}
---

# API Route Rules

When editing API route files, follow these rules:

## Endpoint Design
- Every endpoint must have a clear, single purpose
- Use RESTful resource naming: plural nouns for collections, nested paths for relationships
- Use appropriate HTTP methods: GET (read), POST (create), PUT (replace), PATCH (update), DELETE (remove)
- Validate ALL request input at the handler boundary before any business logic
- Use the project's validation library (Zod, Pydantic, struct tags, etc.)

## Versioning
- Include API version in the URL path (e.g., `/api/v1/`) or via headers — pick one convention and enforce it project-wide
- Never remove or rename fields in a published API version — add new fields, deprecate old ones

## Response Format
- Return structured error responses with appropriate HTTP status codes
- Never return raw exception messages or stack traces to clients
- Use consistent response envelope format across all endpoints

## Error Responses
- Use standard HTTP status codes: 400 (bad input), 401 (unauthenticated), 403 (unauthorized), 404 (not found), 409 (conflict), 422 (validation), 429 (rate limited), 500 (server error)
- Include a machine-readable error code and a human-readable message in every error response
- Never expose internal implementation details (stack traces, SQL errors, file paths) in error responses

## Logging
- Log request metadata (method, path, status code, duration)
- Include correlation/request IDs in log entries
