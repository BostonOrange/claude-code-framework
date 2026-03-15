---
name: fetch-docs
description: Fetch library/framework documentation via context7 or web search and persist it to the knowledge base. Automatically invoked when documentation is needed for implementation tasks.
---

# Fetch Docs

Retrieve up-to-date documentation for any library or framework and save it to the project knowledge base. Future conversations can read cached docs instead of re-fetching.

## Usage

```
/fetch-docs next.js app-router          # Fetch Next.js App Router docs
/fetch-docs capacitor geolocation       # Fetch Capacitor Geolocation plugin docs
/fetch-docs leaflet markers             # Fetch Leaflet marker docs
/fetch-docs zustand persist-middleware  # Fetch Zustand persist docs
```

## Auto-Trigger Rules

**This skill's persistence behavior applies ANY TIME documentation enters the conversation**, not just when explicitly invoked. This includes:

1. **AI-fetched:** Context7 lookups, WebFetch, WebSearch for API references or guides
2. **User-provided:** User pastes documentation, API specs, READMEs, or guides into chat
3. **User-linked:** User shares a URL to docs — fetch it and persist
4. **User-shared files:** User asks you to read a doc/PDF/spec file — extract and persist
5. **Error solutions:** When investigating errors leads to documentation or patterns worth keeping
6. **Offline/unreachable docs:** User provides docs because the AI can't reach them — these are especially valuable to persist since they can't be re-fetched

You MUST save the useful portions to the knowledge base before continuing with the task.

### Handling user-provided documentation

When a user pastes or shares documentation that Claude cannot normally access (internal APIs, paywalled docs, private specs):

1. **Acknowledge** that this is being saved to the knowledge base
2. **Structure** it into the standard reference format (tables, code examples, key notes)
3. **Tag** it with `<!-- user-provided, not auto-fetchable -->` so future updates know to ask the user rather than trying to fetch
4. **Thank briefly** — the user is investing time to improve the knowledge base

## Process

### 1. Check Cache First

Before fetching, check if docs already exist:

```
.claude/skills/fetch-docs/references/{library-name}.md
```

- If file exists and the topic is covered → **use cached version**, skip fetch
- If file exists but topic is missing → fetch and **merge** into existing file
- If file doesn't exist → fetch and **create** new file

### 2. Fetch Documentation

#### Via Context7 (preferred for libraries)

1. Call `resolve-library-id` with the library name
2. Call `query-docs` with the resolved ID and specific topic
3. Extract the relevant code examples and API details

#### Via Web Search (fallback)

1. Search for `{library} {topic} documentation`
2. Fetch the most authoritative source (official docs preferred)
3. Extract structured information

### 3. Persist to Knowledge Base

Write to: `.claude/skills/fetch-docs/references/{library-name}.md`

Use this format:

```markdown
# {Library Name} Documentation

> Last updated: {YYYY-MM-DD}
> Source: {context7 | URL}

## {Topic 1}

### Overview
{Brief description of the API/feature}

### API Reference

| Method/Prop | Type | Description |
|-------------|------|-------------|
| `name` | `type` | What it does |

### Code Examples

```{language}
// Example from docs
```

### Key Notes
- {Important gotcha or best practice}

## {Topic 2}
...
```

### 4. Format Rules

- **Tables** for API surfaces (methods, props, config options)
- **Code blocks** for examples (always include language tag)
- **Key Notes** section for gotchas, version-specific behavior, or best practices
- **One file per library** — multiple topics as `##` sections within the file
- Keep examples concise — extract the most relevant pattern, not the entire page
- Include the `Last updated` date so staleness is visible
- **Never store** full page content verbatim — summarize and structure it

### 5. Update Index (MANDATORY)

Every persist operation MUST update `.claude/skills/fetch-docs/references/INDEX.md`. This is the lookup table that prevents redundant fetches as the knowledge base grows.

**Before fetching:** Read `INDEX.md` first. Search the tables for the library or topic. If found, read the referenced file instead.

**After persisting:** Add or update the row in the appropriate table:

- **Libraries** table: for npm packages, frameworks, SDKs
- **Project Patterns** table: for project-specific patterns, gotchas, conventions discovered during work
- **External APIs** table: for third-party API documentation (SL Transport API, GraphHopper, etc.)

**Row format:**

```markdown
| {name} | {filename}.md | {comma-separated topics} | {YYYY-MM-DD} | {context7 / url / user-provided} |
```

**Example:**

```markdown
| next.js | next-js.md | app-router, server-actions, middleware | 2026-03-15 | context7 |
| capacitor | capacitor.md | geolocation, preferences, splash-screen | 2026-03-15 | user-provided |
| sl-transport-api | sl-transport-api.md | departures, journeys, stop-deviations | 2026-03-15 | https://transport.integration.sl.se |
```

**Why this matters:** Without the index, the knowledge base becomes a pile of files that requires scanning every file to know what's cached. The index makes lookups O(1) — read one file, know everything that's available.

## Knowledge Evolution Over Time

The knowledge base is a living system that improves with every conversation.

### Incremental enrichment
Each conversation may add new topics to an existing library file. When you use a library and discover undocumented patterns, edge cases, or gotchas — **add them** under a `## Project Patterns` section in that library's reference file. These are the most valuable entries because they capture real usage, not just API surfaces.

### Staleness detection
When reading a cached reference file:
- Check the `Last updated` date in the header
- If older than 30 days AND the topic is being actively used → re-fetch and merge
- Always preserve `<!-- project-specific -->` and `<!-- user-provided -->` tagged sections
- Add a `## Changelog` section at the bottom noting what was updated and when

### Version tracking
When the project upgrades a dependency:
- Update the library reference header with the new version
- Re-fetch docs for any topics that may have breaking changes
- Note migration details under `## Migration Notes`

## Edge Cases

| Scenario | Behavior |
|----------|----------|
| Context7 returns no results | Fall back to web search |
| Web search returns no results | Note the gap, ask user for docs URL |
| Cached docs are older than 30 days | Re-fetch and merge, preserving manual notes |
| Very large API surface | Split into logical sections, link between them |
| Library version mismatch | Note version in the doc header, fetch for correct version |
| Docs contain project-specific notes | Tag with `<!-- project-specific -->` so merges preserve it |
| User-provided docs (not fetchable) | Tag with `<!-- user-provided, not auto-fetchable -->` |
| Conflicting info (cached vs new) | Keep both with dates, flag for user review |

## Related Skills

- `/add-reference` — for domain knowledge and codebase inventories
- `/develop` — triggers auto-save when docs are fetched during implementation
