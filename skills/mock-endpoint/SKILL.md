---
name: mock-endpoint
description: Create mock definitions for external APIs and services. Generates contract files, test fixtures, mock servers, and integration wrappers so AI can safely develop and test against external dependencies without hitting real services.
---

# Mock Endpoint

Define, mock, and test external API integrations safely. Creates a contract-first development workflow where external dependencies are fully described before any code touches a real service.

## Usage

```
/mock-endpoint sl-transport-api           # Mock an external API from scratch
/mock-endpoint sl-transport-api departures # Mock a specific endpoint group
/mock-endpoint --from-code                # Scan codebase for existing API calls and generate mocks
/mock-endpoint --list                     # List all defined mocks
```

## Why This Exists

When AI implements features that call external APIs:
- It can't test against real services (rate limits, auth, side effects)
- It may guess wrong about request/response shapes
- Tests that hit real endpoints are flaky and slow
- Wiring up incorrectly against production is dangerous

This skill creates a **contract layer** between your code and external services. The AI develops against the contract, tests against mocks, and the real service is only connected after human review.

## Core Concepts

### Contract File

The source of truth for what an external API looks like. Lives in `.claude/skills/mock-endpoint/references/{service-name}.md`.

### Mock Fixture

Static request/response pairs generated from the contract. Used in tests.

### Mock Server (optional)

A lightweight local server that serves mock responses. Used for manual testing and dev server integration.

### Integration Wrapper

A thin abstraction layer around the external API call. In production it hits the real service; in tests it hits the mock.

## Process

### 1. Define the Contract

If user provides docs or a URL, extract the API surface. If the API is already called in the codebase, scan for it.

#### Via Context7 (for known libraries/SDKs)

If the external service has an official SDK or client library, fetch documentation using the `/fetch-docs` skill pattern (resolve-library-id then get-library-docs) for endpoint signatures, auth patterns, and response shapes. Use fetched docs to populate the contract accurately instead of guessing.

#### Scanning existing code

```bash
# Find all external HTTP calls
grep -rn 'axios\.\|fetch(' src/ --include='*.ts' --include='*.tsx' | grep -v node_modules | grep -v '.test.'
```

Group by base URL / service. For each unique external service found, create a contract.

#### Contract Format

Write to: `.claude/skills/mock-endpoint/references/{service-name}.md`

```markdown
# {Service Name} API Contract

> Base URL: {base_url}
> Auth: {auth method — API key, Bearer token, none}
> Rate Limits: {if known}
> Source: {documentation URL or "scanned from codebase"}
> Last Updated: {YYYY-MM-DD}

## Endpoints

### {METHOD} {path}

**Purpose:** {what this endpoint does}

**Request:**

| Parameter | Location | Type | Required | Description |
|-----------|----------|------|----------|-------------|
| `param` | query/path/header/body | string | yes/no | What it is |

**Response (200):**

```json
{
  "field": "type — description"
}
```

**Response (error):**

```json
{
  "error": "string — error message"
}
```

**Example:**

```bash
curl -s "https://api.example.com/endpoint?param=value" -H "Authorization: Bearer $TOKEN"
```

**Used in codebase:**
- `src/lib/api/client.ts:42` — fetchDepartures()
- `src/app/api/v1/departures/route.ts:15` — GET handler
```

### 2. Generate Mock Fixtures

For each endpoint in the contract, create realistic test fixtures.

Write to: `__mocks__/{service-name}/{endpoint-name}.json` (or project's test fixture convention)

```json
{
  "request": {
    "method": "GET",
    "url": "/v1/sites/1002/departures",
    "params": { "transport": "METRO", "forecast": 120 }
  },
  "response": {
    "status": 200,
    "body": {
      // Realistic mock data matching the contract schema
      // Use Swedish station names, real line numbers, plausible times
    }
  }
}
```

#### Fixture rules

- **Realistic data** — use actual entity names, plausible values, correct types. Never use "foo", "bar", "test123"
- **Edge cases** — include fixtures for: empty results, error responses, rate limit responses, malformed data
- **Multiple scenarios** — at least 3 fixtures per endpoint: happy path, empty result, error
- **Deterministic** — no random values, no timestamps that change. Tests must be reproducible

### 3. Generate Integration Wrapper

> **Language note:** Adapt examples to your project's language and test framework. The patterns below use TypeScript/Jest as examples — substitute your project's equivalents (e.g., pytest for Python, go test for Go, JUnit for Java).

Create a thin wrapper that abstracts the external call. This is the **only place** in the codebase that knows about the real URL.

```typescript
// src/lib/services/{service-name}.ts

const BASE_URL = process.env.{SERVICE}_API_URL || '{default_base_url}';

export async function fetchDepartures(siteId: number, transport: string) {
  const response = await fetch(
    `${BASE_URL}/v1/sites/${siteId}/departures?transport=${transport}&forecast=120`
  );
  if (!response.ok) throw new ServiceError('departures', response.status);
  return response.json();
}
```

#### Wrapper rules

- **One file per external service** — all endpoints for that service in one module
- **Base URL from env var** — never hardcode production URLs
- **Typed responses** — define TypeScript interfaces matching the contract
- **Error wrapping** — throw typed errors, never expose raw HTTP details to callers
- **No business logic** — the wrapper only fetches and returns. Transform elsewhere

#### Language alternatives

**Python (requests):**
```python
# src/services/departures.py
BASE_URL = os.environ.get("SL_API_URL", "https://api.example.com")

def fetch_departures(site_id: int, transport: str) -> dict:
    resp = requests.get(f"{BASE_URL}/v1/sites/{site_id}/departures", params={"transport": transport})
    resp.raise_for_status()
    return resp.json()
```

**Go (net/http):**
```go
// services/departures.go
func FetchDepartures(siteID int, transport string) (*DeparturesResponse, error) {
    url := fmt.Sprintf("%s/v1/sites/%d/departures?transport=%s", baseURL, siteID, transport)
    resp, err := http.Get(url)
    // ... error handling, json.Decode into typed struct
}
```

### 4. Generate Test Helpers

Create test utilities that load fixtures and mock the wrapper.

```typescript
// __mocks__/{service-name}/index.ts

import happyPath from './{endpoint}-happy.json';
import empty from './{endpoint}-empty.json';
import error from './{endpoint}-error.json';

export const mockDepartures = {
  happy: happyPath,
  empty: empty,
  error: error,
};

// Helper to mock the service wrapper
export function mockDeparturesService(scenario: 'happy' | 'empty' | 'error' = 'happy') {
  const fixture = mockDepartures[scenario];
  jest.spyOn(departuresService, 'fetchDepartures')
    .mockResolvedValue(fixture.response.body);
}
```

### 5. Generate Tests

Write integration tests that use the mocks:

```typescript
describe('Departures API', () => {
  it('returns departures for a station', async () => {
    mockDeparturesService('happy');
    const result = await fetchDepartures(1002, 'METRO');
    expect(result.departures).toHaveLength(expectedCount);
    expect(result.departures[0]).toHaveProperty('destination');
  });

  it('handles empty station', async () => {
    mockDeparturesService('empty');
    const result = await fetchDepartures(9999, 'METRO');
    expect(result.departures).toHaveLength(0);
  });

  it('handles API error', async () => {
    mockDeparturesService('error');
    await expect(fetchDepartures(1002, 'METRO')).rejects.toThrow(ServiceError);
  });
});
```

#### Language alternatives

**Python (pytest + unittest.mock):**
```python
# tests/test_departures.py
from unittest.mock import patch

@patch("services.departures.fetch_departures")
def test_returns_departures(mock_fetch):
    mock_fetch.return_value = load_fixture("departures-happy.json")
    result = fetch_departures(1002, "METRO")
    assert len(result["departures"]) > 0
```

**Go (httptest):**
```go
// services/departures_test.go
func TestFetchDepartures(t *testing.T) {
    srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        json.NewEncoder(w).Encode(loadFixture("departures-happy.json"))
    }))
    defer srv.Close()
    result, err := FetchDepartures(srv.URL, 1002, "METRO")
    // ... assertions
}
```

### 6. Update Index

After creating mocks, update the index:

`.claude/skills/mock-endpoint/references/INDEX.md`

```markdown
# External API Mocks Index

| Service | Contract | Endpoints Mocked | Fixtures | Last Updated |
|---------|----------|-----------------|----------|--------------|
| sl-transport-api | sl-transport-api.md | departures, journeys, deviations | 9 | 2026-03-15 |
```

## Integration with Other Skills

### How `/develop` uses mocks

When `/develop` implements a feature that calls an external API:

1. **Check the mock index** — does a contract exist for this service?
2. **If yes** — import the wrapper, write tests using mock fixtures. Never call the real API
3. **If no** — ask the user: "This feature calls {service}. Should I create a mock contract first?" If yes, invoke `/mock-endpoint {service}`
4. **In the PR** — note which external services are mocked and need real credentials for staging

### How `/validate` uses mocks

- **Check for direct API calls** — flag any `fetch()` or `axios.get()` that hits an external URL directly instead of going through a wrapper
- **Check test coverage** — flag any wrapper function that lacks corresponding mock fixtures

### How `/factory` uses mocks

- Factory mode always uses mocks — never hits real external services
- CI validation runs against mock fixtures
- Real service connection is only tested in staging (post-merge)

## Mock Server (Optional)

For manual testing during development, generate a lightweight mock server:

```typescript
// scripts/mock-server.ts
import { createServer } from 'http';
import fixtures from '../__mocks__/{service}/index';

const server = createServer((req, res) => {
  // Match request to fixture, return mock response
});

server.listen(4000, () => console.log('Mock server on :4000'));
```

Add to package.json:
```json
"scripts": {
  "mock-server": "npx tsx scripts/mock-server.ts"
}
```

This lets you run `npm run dev` + `npm run mock-server` and develop the full integration locally without credentials.

## Edge Cases

| Scenario | Behavior |
|----------|----------|
| API already has a wrapper | Generate contract + fixtures only, skip wrapper |
| Multiple auth methods | Document all in contract, mock the primary one |
| WebSocket/streaming API | Note in contract as unsupported for mocking, provide snapshot fixtures |
| GraphQL API | Generate query/mutation contracts, mock the GraphQL client |
| API has pagination | Include fixtures for page 1, page 2, and last page |
| API returns different shapes per param | Separate fixtures per variant |
| Rate-limited API | Include 429 fixture, test backoff behavior |
| User provides OpenAPI/Swagger spec | Parse and generate contract automatically |

## Related Skills

- `/develop` — checks mock index before implementing external integrations
- `/validate` — flags direct API calls that bypass wrappers
- `/fetch-docs` — persists API documentation that feeds into contract creation
- `/add-reference` — stores domain knowledge about external services
