---
id: tests
patterns:
  - {{TEST_PATTERNS}}
---

# Test Rules

When editing test files, follow these rules:

## Test Data
- Use test data factories or fixtures — never construct test data inline
- No production data references (real emails, phone numbers, IDs, names)
- Use deterministic test data — avoid random values unless testing randomness
- Clean up test data after each test (or use transactions/rollback)

## Test Structure
- Each test should have a descriptive name explaining the behavior being tested
- Follow Arrange-Act-Assert (or Given-When-Then) structure
- One assertion concept per test (multiple assertions for the same concept is fine)
- Tests must be independent — no shared mutable state between tests

## Reliability
- No `sleep` or fixed-time waits — use polling, retries, or async utilities
- No tests that depend on execution order
- No tests that depend on external services (mock them)
- Tests must pass consistently — flaky tests must be fixed or quarantined

## Coverage Intent
- Test behavior, not implementation details
- Cover happy path, error conditions, and edge cases
- New public functions/methods must have corresponding tests
- Removed tests must be justified by removed code
