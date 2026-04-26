---
name: index
description: Build or refresh a vector index of the codebase at `.claude/state/codebase.db` for semantic search via `/search`. Opt-in for large codebases (>50k LOC); small projects get sufficient awareness from `.claude/state/architecture.md` + Grep
---

# Index — Build the Codebase Vector Index

For codebases where Grep + `architecture.md` aren't enough — typically >50k LOC — `/index` builds a SQLite + sqlite-vec index that powers `/search`. The index is gitignored, lives at `.claude/state/codebase.db`, and updates incrementally on subsequent runs.

## Usage

```
/index                              full build (only files not yet indexed; subsequent runs are incremental)
/index --full                       force re-embed every file (use after changing chunking config)
/index --include='\.cls$|\.trigger$' index only Apex files (Salesforce)
/index --provider=local             use Ollama local embeddings instead of Voyage/OpenAI
/index stats                        show index size, file count, age
/index purge                        delete the index entirely
```

## Setup

The index requires an embedding provider. Pick one before first run:

| Provider | Setup | Cost (1M LOC) | Quality | Privacy |
|----------|-------|--------------|---------|---------|
| **voyage** (default) | `export VOYAGE_API_KEY=...` ([signup](https://www.voyageai.com)) | ~$2.50 one-time, $0.05/incremental commit | Best for code | API |
| **openai** | `export OPENAI_API_KEY=...` | ~$0.50 one-time | Good | API |
| **local** | `ollama pull nomic-embed-text && ollama serve` | Free, ~6hr initial on Mac | Lower | All local |

Configure via env vars (typically in `.env` or shell profile):

```bash
export CLAUDE_FRAMEWORK_EMBED_PROVIDER=voyage   # or openai, local
export VOYAGE_API_KEY=<your-key>
```

## Process

### Phase 1: Verify provider config

Run `bash .claude/hooks/codebase-index.sh stats` first. If no index, check `$CLAUDE_FRAMEWORK_EMBED_PROVIDER` and the corresponding API key. If unset, prompt the user to configure before proceeding.

### Phase 2: Run the index command

```bash
bash .claude/hooks/codebase-index.sh index [args]
```

The script:
1. Walks the working tree via `git ls-files` (respects `.gitignore`)
2. Filters by include globs (defaults to common code extensions; configurable via `--include`)
3. For each file: computes git SHA, skips if already indexed at that SHA (incremental)
4. Chunks the file into 40-line windows with 8-line overlap
5. Embeds each chunk via the configured provider
6. Stores `(file_path, line_start, line_end, content, sha, embedding)` in SQLite

Streaming progress to stderr: `indexing: <path>` per file.

### Phase 3: Report

After completion, surface to the user:
- Files indexed (count)
- Chunks created (count)
- DB size
- Time elapsed
- Cost estimate (if cloud provider)

### Phase 4: Suggest next action

- **First-time index**: "Run `/search 'natural language query'` to test the index. Try queries you'd otherwise grep for but can't ('where do we handle invoice numbers?')."
- **Incremental refresh**: "Re-indexed N changed files in <time>. Index is current."

## State Files

| File | Purpose | Lifecycle |
|------|---------|-----------|
| `.claude/state/codebase.db` | SQLite index with chunks + embeddings | Built by `/index`; incremental on subsequent runs; purge with `/index purge` |

Gitignored under `.claude/state/`.

## When `/index` Earns Its Place

| Project size | Recommendation |
|--------------|----------------|
| <10k LOC | Skip. Grep + `architecture.md` is sufficient. |
| 10-50k LOC | Optional. `/search` becomes useful for "where do we…" queries. |
| 50k-500k LOC | Recommended. Grep alone misses semantic neighbors. |
| 500k-5M LOC | Strongly recommended. The framework was extended for this scale specifically. |
| >5M LOC | Required. Plus consider GitNexus or similar for precise call graphs. |

## Salesforce-Specific Notes

For a Salesforce org indexed via SFDX:

```bash
/index --include='\.cls$|\.trigger$|\.cmp$|\.html$|\.js$|\.flow-meta\.xml$'
```

Tags Apex / LWC / Flow content distinctly (the chunk's `file_path` carries the metadata type via extension). Searches can filter:

```
/search "rate limit logic" --include=apex
```

Initial index of a 1M-line org takes ~2-4 hours via Voyage; subsequent commits are seconds. **Plan for "kick it off, walk away."**

## Edge Cases

| Scenario | Behavior |
|----------|----------|
| First run with no provider configured | Halt; tell user to set `CLAUDE_FRAMEWORK_EMBED_PROVIDER` and API key |
| API key unset for selected provider | Halt with the exact env var name |
| `git ls-files` returns empty | Halt with "not in a git repo or no tracked files" |
| Chunking config changed | Pass `--full` to force re-embed |
| Network failure mid-index | Resume on re-run (incremental skip catches already-indexed files) |
| Hitting rate limits | Add `sleep` between API calls; configurable via `CLAUDE_FRAMEWORK_INDEX_RATE_LIMIT` (future) |
| Salesforce 1M+ LOC | Plan for hours; run in background (`nohup ... &`); check progress with `/index stats` |

## Related

- `/search` — query the index built by this skill
- `.claude/state/architecture.md` — broad map (refreshed by `/improve`); complements semantic search
- `/impact` — precise per-symbol cascade analysis (uses Grep, not the vector index)
- `templates/hooks/codebase-index.sh` — the bash engine
