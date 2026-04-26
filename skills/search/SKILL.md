---
name: search
description: Semantic search across the indexed codebase. Returns top-K matching chunks with file:line + similarity score. Requires `/index` to have been run first. Useful for "where do we handle X?" questions that grep can't answer because there's no exact-string match
---

# Search — Semantic Codebase Query

When you need to find code by *meaning* rather than exact text — "where do we generate invoice numbers?", "what handles rate limiting?", "is there existing logic for tax calculation?" — `/search` queries the vector index built by `/index` and returns the most semantically relevant chunks.

`/search` complements `/impact` and `Grep`:
- **Grep** for exact strings ("find all uses of `requireAuth`")
- **/impact** for precise call-site cascades on a known target
- **/search** for semantic neighborhood ("find code about authentication" without knowing the function names)

## Usage

```
/search "<natural language query>"
/search "<query>" --top-k=20            return top 20 (default 10)
/search "<query>" --include=apex        filter by extension/type
```

Examples:
```
/search "where do we generate unique invoice numbers"
/search "rate limit logic for API endpoints"
/search "session timeout handling" --top-k=5
/search "after-insert trigger handler" --include=apex
```

## Process

### Phase 1: Verify index exists

```bash
bash .claude/hooks/codebase-index.sh stats
```

If no index, halt with: "Run `/index` first to build the codebase index. See `/index` skill for setup."

### Phase 2: Run the search

```bash
bash .claude/hooks/codebase-index.sh search "<query>" [--top-k=N]
```

The script:
1. Embeds the query via the configured provider (must match what `/index` used)
2. Computes cosine similarity against every chunk in the DB
3. Returns top-K results: `<score>\t<file>:<line_start>-<line_end>\t<snippet>`

### Phase 3: Render results

Show the user a ranked table:

```
| # | Score | File:Lines | Snippet |
|---|-------|------------|---------|
| 1 | 0.847 | lib/billing/invoice.ts:23-62 | "function generateInvoiceNumber(account: Account)..." |
| 2 | 0.792 | lib/billing/sequence.ts:8-40 | "// Atomic counter for invoice numbers..." |
```

### Phase 4: Hand-off

After showing results, suggest next steps based on the query type:

- **Exploration** ("where do we handle X?"): "Top hit is `<file>:<line>`. Read that to confirm it's the right entry point."
- **Duplicate check** ("is there existing logic for Y?"): "Found N similar chunks. Highest scoring is `<file>:<line>` — review before adding new logic."
- **Pre-change context** ("rate limit code"): "These chunks are the rate-limiting surface. Run `/impact <file>:<symbol>` on each before modifying."

## State Files

`/search` is stateless — reads `.claude/state/codebase.db` (built by `/index`) and writes nothing.

## When to Use What

| Query type | Tool |
|------------|------|
| Exact string ("`requireAuth`") | `Grep` |
| Symbol cascade ("what calls `requireAuth`?") | `/impact` |
| Semantic neighborhood ("auth-related code") | `/search` |
| Architectural question ("how is auth structured?") | Read `.claude/state/architecture.md` |

## Tradeoffs vs Grep

`/search` returns *semantically similar* code, not exact matches. Implications:

- **Recall is wider**: finds code with synonyms, related concepts, similar shape.
- **Precision is lower than grep**: top-1 may be a near-miss. Always read the snippet.
- **Confidence is approximate**: similarity score is a heuristic. 0.8+ is usually relevant; <0.5 is often noise.
- **Dependent on index freshness**: stale index returns stale results. `/index` runs incrementally on subsequent calls; commit hooks (Phase 2.5) auto-refresh.

## Edge Cases

| Scenario | Behavior |
|----------|----------|
| No index | Halt; tell user to run `/index` |
| Provider mismatch (index built with voyage, search with openai) | Halt; tell user to either re-index with current provider OR switch back |
| Empty results | "No relevant matches above threshold" — suggest broader query or `/index --full` if index is suspected stale |
| Top scores all <0.5 | Warn user that results may not be relevant; suggest grep instead |
| Very specific query (exact symbol name) | Suggest `Grep` instead — it'll be faster and more precise |
| Salesforce-specific query | Use `--include=apex` to filter to Apex chunks only; reduces noise from LWC/HTML |

## Related

- `/index` — must run first to build the index
- `/impact` — for precise per-symbol analysis (grep-based, no vector index needed)
- `.claude/state/architecture.md` — broad architectural map
- `templates/hooks/codebase-index.sh` — the bash engine
