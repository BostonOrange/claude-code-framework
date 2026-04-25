---
id: error-handling
patterns:
  - {{SOURCE_PATTERNS}}
---

# Error Handling Rules

When editing source files, follow these rules:

## Catch Blocks
- Never catch exceptions and silently swallow them — every catch must log or re-throw
- Add context to re-thrown errors (what operation was attempted, what input caused it)
- Distinguish between recoverable errors (retry, fallback) and unrecoverable errors (crash, alert)

## Error Tracking
- Use the project error tracking utility for all caught exceptions:
  `{{ERROR_TRACKING_PATTERN}}`
- Include sufficient context for debugging (operation name, relevant IDs, input parameters)

## User-Facing Errors
- User-facing error messages must not expose stack traces, internal paths, or system details
- Provide actionable guidance when possible ("Please try again" vs "Internal Server Error")
- Use error codes for programmatic error handling by API consumers

## Async Error Handling
- All promises must have rejection handlers — no unhandled promise rejections
- Async functions must have try-catch at the top level or propagate errors to the caller
- Background tasks must have error handlers that log and alert on failure
