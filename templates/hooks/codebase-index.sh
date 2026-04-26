#!/bin/bash
# codebase-index.sh — vector indexing engine for Claude Code Framework
#
# Builds and queries a SQLite + sqlite-vec index of the working tree.
# Embedding provider configurable via CLAUDE_FRAMEWORK_EMBED_PROVIDER:
#   - voyage      (default; requires VOYAGE_API_KEY)
#   - openai      (requires OPENAI_API_KEY)
#   - local       (requires `ollama` running with `nomic-embed-text` or similar)
#
# Subcommands:
#   index [--full] [--include=<glob>]  Build/refresh index. --full forces re-embed of every file.
#   search "<query>" [--top-k=N]       Return top-K matching chunks
#   stats                              Report index size, file count, age
#   purge                              Delete the index
#
# Usage from skills:
#   bash .claude/hooks/codebase-index.sh index
#   bash .claude/hooks/codebase-index.sh search "where do we handle invoice number generation"

set -euo pipefail

# ── Config ─────────────────────────────────────────────────────────────────────

DB="${CLAUDE_FRAMEWORK_INDEX_DB:-.claude/state/codebase.db}"
PROVIDER="${CLAUDE_FRAMEWORK_EMBED_PROVIDER:-voyage}"
CHUNK_LINES="${CLAUDE_FRAMEWORK_CHUNK_LINES:-40}"
CHUNK_OVERLAP="${CLAUDE_FRAMEWORK_CHUNK_OVERLAP:-8}"
TOP_K_DEFAULT=10

# Default include globs by language family — adjust for project type
INCLUDE_GLOBS_DEFAULT="*.ts *.tsx *.js *.jsx *.py *.go *.rs *.java *.cs *.rb *.php *.cls *.trigger *.cmp *.html *.md"
EXCLUDE_DIRS="node_modules vendor dist build .next .git __pycache__ target"

# ── Provider abstraction ──────────────────────────────────────────────────────

embed_voyage() {
    local text="$1"
    local payload
    payload=$(jq -n --arg input "$text" --arg model "voyage-code-3" \
        '{input: [$input], model: $model, input_type: "document"}')
    curl -fsS https://api.voyageai.com/v1/embeddings \
        -H "Authorization: Bearer ${VOYAGE_API_KEY:?VOYAGE_API_KEY required}" \
        -H "Content-Type: application/json" \
        -d "$payload" \
        | jq -r '.data[0].embedding | @csv' \
        | tr -d '"'
}

embed_openai() {
    local text="$1"
    local payload
    payload=$(jq -n --arg input "$text" --arg model "text-embedding-3-small" \
        '{input: $input, model: $model}')
    curl -fsS https://api.openai.com/v1/embeddings \
        -H "Authorization: Bearer ${OPENAI_API_KEY:?OPENAI_API_KEY required}" \
        -H "Content-Type: application/json" \
        -d "$payload" \
        | jq -r '.data[0].embedding | @csv' \
        | tr -d '"'
}

embed_local() {
    local text="$1"
    local payload
    payload=$(jq -n --arg prompt "$text" --arg model "${CLAUDE_FRAMEWORK_LOCAL_MODEL:-nomic-embed-text}" \
        '{prompt: $prompt, model: $model}')
    curl -fsS http://localhost:11434/api/embeddings \
        -H "Content-Type: application/json" \
        -d "$payload" \
        | jq -r '.embedding | @csv' \
        | tr -d '"'
}

embed() {
    case "$PROVIDER" in
        voyage) embed_voyage "$1" ;;
        openai) embed_openai "$1" ;;
        local)  embed_local "$1" ;;
        *) echo "Unknown provider: $PROVIDER" >&2; exit 1 ;;
    esac
}

# ── Schema ────────────────────────────────────────────────────────────────────

ensure_schema() {
    mkdir -p "$(dirname "$DB")"
    sqlite3 "$DB" <<'SQL'
CREATE TABLE IF NOT EXISTS files (
    path TEXT PRIMARY KEY,
    sha TEXT NOT NULL,
    indexed_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS chunks (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    file_path TEXT NOT NULL,
    line_start INTEGER NOT NULL,
    line_end INTEGER NOT NULL,
    content TEXT NOT NULL,
    content_sha TEXT NOT NULL,
    embedding BLOB,
    FOREIGN KEY (file_path) REFERENCES files(path) ON DELETE CASCADE
);
CREATE INDEX IF NOT EXISTS idx_chunks_file ON chunks(file_path);
CREATE INDEX IF NOT EXISTS idx_chunks_sha ON chunks(content_sha);
SQL
}

# ── Indexing ──────────────────────────────────────────────────────────────────

# List candidate files via git ls-files (respects .gitignore by default)
list_files() {
    local include_pattern="${1:-}"
    if [ -n "$include_pattern" ]; then
        git ls-files | grep -E "$include_pattern" || true
    else
        git ls-files
    fi
}

# Chunk a file: emit `<line_start>\t<line_end>\t<content>` per chunk to stdout
chunk_file() {
    local file="$1"
    local total
    total=$(wc -l < "$file" | tr -d ' ')
    local start=1
    while [ "$start" -le "$total" ]; do
        local end=$(( start + CHUNK_LINES - 1 ))
        if [ "$end" -gt "$total" ]; then end=$total; fi
        local content
        content=$(sed -n "${start},${end}p" "$file")
        # NUL-byte separator between fields to allow newlines in content
        printf '%d\t%d\t%s\0' "$start" "$end" "$content"
        if [ "$end" -ge "$total" ]; then break; fi
        start=$(( end + 1 - CHUNK_OVERLAP ))
        [ "$start" -lt 1 ] && start=1
    done
}

index_file() {
    local file="$1"
    local force="${2:-0}"

    # Skip if file unchanged since last index (unless --full)
    local current_sha
    current_sha=$(git hash-object "$file" 2>/dev/null || sha256sum "$file" | cut -d' ' -f1)
    local cached_sha
    cached_sha=$(sqlite3 "$DB" "SELECT sha FROM files WHERE path = '$file';" 2>/dev/null || echo "")
    if [ "$force" = "0" ] && [ "$cached_sha" = "$current_sha" ]; then
        return 0
    fi

    # Delete existing chunks for this file (cascade via FK ON DELETE)
    sqlite3 "$DB" "DELETE FROM files WHERE path = '$file';"

    # Re-chunk and embed
    chunk_file "$file" | while IFS=$'\t' read -r -d '' start end content; do
        local content_sha
        content_sha=$(printf '%s' "$content" | sha256sum | cut -d' ' -f1)
        local embedding_csv
        embedding_csv=$(embed "$content")
        # Store embedding as JSON array string for sqlite-vec compatibility
        local embedding_json
        embedding_json="[${embedding_csv}]"
        sqlite3 "$DB" <<SQL
INSERT INTO chunks (file_path, line_start, line_end, content, content_sha, embedding)
VALUES ('$file', $start, $end,
        $(printf '%s' "$content" | jq -Rs .),
        '$content_sha',
        $(printf '%s' "$embedding_json" | jq -Rs .));
SQL
    done

    # Record file SHA for incremental skip
    sqlite3 "$DB" "INSERT INTO files (path, sha, indexed_at) VALUES ('$file', '$current_sha', '$(date -u +%Y-%m-%dT%H:%M:%SZ)');"
}

cmd_index() {
    local force=0
    local include_pattern=""
    for arg in "$@"; do
        case "$arg" in
            --full) force=1 ;;
            --include=*) include_pattern="${arg#--include=}" ;;
        esac
    done

    ensure_schema

    local count=0
    local skipped=0
    while IFS= read -r file; do
        [ -z "$file" ] && continue
        [ -f "$file" ] || continue
        # Apply default include filter if no pattern given
        if [ -z "$include_pattern" ]; then
            local matched=0
            for ext in $INCLUDE_GLOBS_DEFAULT; do
                if [[ "$file" == $ext ]]; then matched=1; break; fi
            done
            [ "$matched" = "0" ] && { skipped=$((skipped+1)); continue; }
        fi
        # Skip excluded directories
        local skip=0
        for dir in $EXCLUDE_DIRS; do
            if [[ "$file" == */$dir/* || "$file" == $dir/* ]]; then skip=1; break; fi
        done
        [ "$skip" = "1" ] && { skipped=$((skipped+1)); continue; }

        printf 'indexing: %s\n' "$file" >&2
        index_file "$file" "$force"
        count=$((count+1))
    done < <(list_files "$include_pattern")

    echo "indexed: $count files, skipped: $skipped" >&2
}

# ── Search ────────────────────────────────────────────────────────────────────

cmd_search() {
    local query="$1"
    local top_k="${TOP_K_DEFAULT}"
    shift || true
    for arg in "$@"; do
        case "$arg" in
            --top-k=*) top_k="${arg#--top-k=}" ;;
        esac
    done

    if [ ! -f "$DB" ]; then
        echo "Index not built. Run /index first." >&2
        exit 1
    fi

    # Embed the query
    local query_embedding_csv
    query_embedding_csv=$(embed "$query")
    local query_embedding_json="[${query_embedding_csv}]"

    # Cosine similarity via sqlite + jq fallback (sqlite-vec preferred if loaded)
    # Naive implementation: load all embeddings, compute cosine in awk, sort
    sqlite3 "$DB" "SELECT id, file_path, line_start, line_end, embedding, content FROM chunks WHERE embedding IS NOT NULL;" \
        | python3 - "$query_embedding_json" "$top_k" <<'PY'
import sys, json, math, sqlite3
query_emb = json.loads(sys.argv[1])
top_k = int(sys.argv[2])

def cos(a, b):
    dot = sum(x*y for x,y in zip(a,b))
    na = math.sqrt(sum(x*x for x in a))
    nb = math.sqrt(sum(x*x for x in b))
    return dot / (na * nb) if na and nb else 0.0

results = []
for line in sys.stdin:
    parts = line.rstrip('\n').split('|')
    if len(parts) < 6: continue
    chunk_id, file_path, line_start, line_end, embedding_json, content = parts[0], parts[1], parts[2], parts[3], parts[4], '|'.join(parts[5:])
    try:
        emb = json.loads(embedding_json)
    except Exception:
        continue
    score = cos(query_emb, emb)
    results.append((score, file_path, line_start, line_end, content))

results.sort(reverse=True, key=lambda r: r[0])
for score, file_path, line_start, line_end, content in results[:top_k]:
    snippet = content[:200].replace('\n', ' ')
    print(f"{score:.4f}\t{file_path}:{line_start}-{line_end}\t{snippet}")
PY
}

# ── Stats / purge ─────────────────────────────────────────────────────────────

cmd_stats() {
    if [ ! -f "$DB" ]; then echo "No index."; exit 0; fi
    local file_count chunk_count db_size
    file_count=$(sqlite3 "$DB" "SELECT COUNT(*) FROM files;")
    chunk_count=$(sqlite3 "$DB" "SELECT COUNT(*) FROM chunks;")
    db_size=$(du -h "$DB" | cut -f1)
    cat <<EOF
Index: $DB
  Files indexed:  $file_count
  Chunks:         $chunk_count
  Provider:       $PROVIDER
  DB size:        $db_size
EOF
}

cmd_purge() {
    rm -f "$DB"
    echo "Index purged: $DB"
}

# ── Dispatch ──────────────────────────────────────────────────────────────────

cmd="${1:-}"
shift || true
case "$cmd" in
    index)  cmd_index "$@" ;;
    search) cmd_search "$@" ;;
    stats)  cmd_stats ;;
    purge)  cmd_purge ;;
    *)
        cat <<EOF
Usage: $0 <subcommand> [args]

Subcommands:
  index [--full] [--include=<regex>]    Build/refresh the codebase index
  search "<query>" [--top-k=N]          Return top-K matching chunks
  stats                                 Report index size and file count
  purge                                 Delete the index

Environment:
  CLAUDE_FRAMEWORK_INDEX_DB        Path to the SQLite database (default: .claude/state/codebase.db)
  CLAUDE_FRAMEWORK_EMBED_PROVIDER  voyage | openai | local (default: voyage)
  CLAUDE_FRAMEWORK_CHUNK_LINES     Lines per chunk (default: 40)
  CLAUDE_FRAMEWORK_CHUNK_OVERLAP   Lines of overlap between chunks (default: 8)
  CLAUDE_FRAMEWORK_LOCAL_MODEL     Ollama model name for local provider (default: nomic-embed-text)
  VOYAGE_API_KEY / OPENAI_API_KEY  API keys for cloud providers
EOF
        exit 1 ;;
esac
