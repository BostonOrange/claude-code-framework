# Applier Pattern — Canonical Spec for Detector/Applier Pairs

Shared spec for the two-agent pattern where a detector produces a proposal and an applier consumes it after a checkpoint. Both pairs in the framework (`project-setup` and `framework-improver`) implement this pattern; new pairs should reference this doc instead of restating the spec.

See `docs/agent-patterns.md` for the high-level pattern catalog and decision rule.

## Detector contract

**Tools:** `Read, Glob, Grep, Bash` (no `Edit`, no `Write`).

**Network policy:** local-only by instruction. Forbidden command list lives in `docs/project-detection.md`. Bash is unconstrained at the harness level — the "no network" property is a contract maintained by the agent's instructions, not a sandbox guarantee.

**Filesystem write capability:** technically the detector CAN write files via `bash -c 'cat > file << EOF'`. This is how the proposal file is written. The honest framing is: *"the only filesystem write the detector performs is the proposal file via Bash redirection; `Edit` and `Write` are removed so the agent cannot perform surgical edits or arbitrary writes via tool use."* Don't claim "read-only by tool restriction" — claim "read-only by tool removal except for the proposal file."

**Proposal file location:** `.claude/state/<name>-proposal.md`.

**Mandatory pre-write actions:**
- Create `.claude/state/` if missing (`mkdir -p`).
- Ensure `.gitignore` contains `.claude/state/` (defense in depth — proposal contents may leak otherwise if the user runs `git add .`).
- Acquire the lockfile (see "Lockfile spec" below).

## Applier contract

**Tools:** `Read, Edit, Write, Bash`.

**Network policy:** same as detector — local-only by instruction.

### Pre-apply gates (template)

Every applier runs gates in this order. Domain-specific gates fit between gate 0 and the final allowlist gate.

| # | Gate | Purpose | Halt condition |
|---|------|---------|----------------|
| 0 | **Lockfile** | Concurrent-invocation guard | Lock present, <1hr old, PID still alive |
| 1 | **Proposal exists + hash** | Records sha256 baseline for TOCTOU re-check | Proposal missing |
| 2 | **Domain validation** | E.g., `## Confirmed by user` populated, or skip-list re-derived | Pair-specific |
| 3 | **Filter + drop-count check** | Defense-in-depth re-validation of detector's filtering | Drop count > 0 (proposal escaped detector filtering) |
| 4 | **Working tree clean** | Prevents clobbering uncommitted user work | Files in apply set have uncommitted changes (unless `Apply on dirty: yes` opt-out) |
| 5 | **Allowlist (two-step)** | Path-traversal prevention | Any path fails string pre-filter or anchored regex |

The path allowlist regex is canonical at `docs/setup-state-schema.md` "Path allowlist" section. Both appliers reference it; never restate the regex inline.

### Process steps

1. **Snapshot.** Create `.claude/state/<name>-backup-<ts>/` with a `manifest.txt`. See "Manifest format" below.
2. **Apply.** Each Edit is preceded by a TOCTOU re-check (recompute proposal sha256, compare to gate-1 baseline). Track applied changes in memory for rollback.
3. **Lock release.** `rm -f .claude/state/<name>.lock` runs as the final action of either successful apply OR auto-rollback. Never leave a lock on disk after the agent exits.
4. **Smoke check.** `grep -r '{{' CLAUDE.md .claude/ 2>/dev/null | grep -vE '\.claude/state/' | head -30` — classify remaining `{{...}}` as intentionally-unfilled or unexpected. Unexpected → auto-rollback.
5. **Defense-in-depth post-write check.** Re-run gate 5 against the actual modified-file list (not the proposal's claimed list). Catches applier bugs that wrote outside the allowlist.
6. **Apply log.** Write `.claude/state/<name>-applied.md` per the schema doc.

### Auto-rollback

Triggered by:
- Any `Edit` failure (placeholder not found, write error, file missing).
- TOCTOU re-check mismatch.
- Smoke check finds unexpected `{{...}}`.
- Defense-in-depth post-write check fails.

Procedure:
1. For each Edit successfully applied so far, walk the manifest in reverse: `EXISTING <path>` → restore from backup; `MISSING <path>` → delete the file the apply created.
2. Halt with a clear error citing the rollback completion.
3. Release the lockfile.
4. Do NOT write the apply log — the proposal stays valid for re-run after fix.

## Manifest format

`.claude/state/<name>-backup-<ts>/manifest.txt`. One line per affected file, in the order they were processed:

```
EXISTING CLAUDE.md
EXISTING .claude/rules/api-routes.md
MISSING .claude/rules/observability.md
```

- `EXISTING <path>` — file was present before apply; the backup directory contains a copy at `<path>` relative to the backup root. Recovery: `cp $BACKUP/$path $path`.
- `MISSING <path>` — file was absent before apply; if apply created it, recovery deletes it. Recovery: `rm -f $path`.

A naive `cp -r` cannot undo additions; the manifest does.

### Snapshot procedure (canonical bash)

Both appliers run this verbatim during Step 1 — substitute `<name>` with `setup` or `improve`. `$AFFECTED_FILES` is the unique set of paths derived from the proposal (the proposal's substitution table for `/setup`, the proposal's `Target` column for `/improve`).

```bash
TS="$(date -u +%Y%m%dT%H%M%SZ)"
BACKUP=".claude/state/<name>-backup-$TS"
mkdir -p "$BACKUP"
MANIFEST="$BACKUP/manifest.txt"

# CLAUDE.md (always snapshot if present — it's the most-edited file)
if [ -f CLAUDE.md ]; then
  cp CLAUDE.md "$BACKUP/CLAUDE.md"
  echo "EXISTING CLAUDE.md" >> "$MANIFEST"
else
  echo "MISSING CLAUDE.md" >> "$MANIFEST"
fi

# Each affected file — preserve relative path inside backup
for f in $AFFECTED_FILES; do
  if [ -f "$f" ]; then
    mkdir -p "$BACKUP/$(dirname "$f")"
    cp "$f" "$BACKUP/$f"
    echo "EXISTING $f" >> "$MANIFEST"
  else
    echo "MISSING $f" >> "$MANIFEST"
  fi
done
```

When changing this snippet, both appliers must be re-tested in the same commit.

### Recovery bash (canonical)

Run from a bash-compatible shell (Git Bash on Windows works; PowerShell does not — use bash or WSL):

```bash
BACKUP=".claude/state/<name>-backup-<timestamp>"
while IFS=' ' read -r status path; do
  case "$status" in
    EXISTING) cp "$BACKUP/$path" "$path" ;;
    MISSING)  rm -f "$path" ;;
  esac
done < "$BACKUP/manifest.txt"
```

Both appliers reference this snippet; the canonical lives here.

## Lockfile spec

**Location:** `.claude/state/<name>.lock`.

**Format:** three lines.

```
<PID>
<ISO 8601 UTC timestamp>
<process info string, e.g., "project-setup-detector">
```

**Acquisition (atomic).** Use `set -C` (noclobber) so the create-if-not-exists check and write are a single syscall, eliminating the TOCTOU race between `[ -f ]` and `printf >`:

```bash
LOCK=".claude/state/<name>.lock"
if ! (set -C; printf '%s\n%s\n%s\n' "$$" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "<process info>" > "$LOCK") 2>/dev/null; then
    # Lock exists — check staleness
    EXISTING_PID=$(head -1 "$LOCK" 2>/dev/null)
    EXISTING_TS=$(sed -n 2p "$LOCK" 2>/dev/null)
    NOW_S=$(date -u +%s)
    LOCK_S=$(date -u -d "$EXISTING_TS" +%s 2>/dev/null || echo "$NOW_S")
    AGE=$(( NOW_S - LOCK_S ))

    # Sanity-check the timestamp — protects against clock skew or corrupted lockfile
    if [ "$AGE" -lt 0 ] || [ "$AGE" -gt 86400 ]; then
        # Negative age (clock skew) or absurd age (>24hr) — treat as corrupt; remove
        rm -f "$LOCK"
    elif [ "$AGE" -lt 3600 ] && kill -0 "$EXISTING_PID" 2>/dev/null; then
        echo "Lock held by PID $EXISTING_PID for ${AGE}s. Halt." >&2
        exit 1
    else
        # Stale (>1hr OR PID dead) — remove
        rm -f "$LOCK"
    fi

    # Retry acquisition
    (set -C; printf '%s\n%s\n%s\n' "$$" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "<process info>" > "$LOCK") || {
        echo "Lock acquisition failed on retry" >&2; exit 1
    }
fi
```

**Why PID + timestamp + atomic create:**
- **PID** lets stale-lock detection check whether the holder process still exists (`kill -0`). Pure timestamp-based detection misses crashed processes.
- **Atomic create via `set -C`** closes the TOCTOU window between "is the lock held?" and "create the lock" that a non-atomic `[ -f "$LOCK" ] || printf > "$LOCK"` would have.
- **Sanity-check on age** handles clock skew (NTP issues, container time drift) so a lock with a future or absurdly old timestamp is treated as corrupt and removed, rather than blocking forever.

**Release.** `rm -f .claude/state/<name>.lock` — runs on success, failure, or auto-rollback. Mandatory.

**Cross-lifecycle coordination.** `framework-improver-applier` checks `.claude/state/setup.lock` at gate 0 in addition to its own `improve.lock`. This prevents `/improve` from racing against an in-progress `/setup` that hasn't yet written `setup-applied.md`. Mutual-exclusion across pairs is the responsibility of whichever pair is "downstream" of the other in the lifecycle.

**Security note.** The lockfile is a **UX coordination mechanism, not a security boundary.** Anyone with write access to `.claude/state/` can delete or forge the lock. The threat model already assumes write access to the working tree; the lock prevents accidental concurrent runs, not malicious tampering.

## Smoke check pattern

```bash
grep -r '{{' CLAUDE.md .claude/ 2>/dev/null | grep -vE '\.claude/state/' | head -30
```

Both appliers run this verbatim. The exclusion `\.claude/state/` skips backup directories and proposal files (which legitimately contain `{{...}}` examples and won't have placeholders to fill). If you change the smoke check, change it here first, then update both appliers in the same commit.

## Schema reference

Proposal and applied state file schemas: `docs/setup-state-schema.md` (covers all four state files for both pairs). Includes:
- Required columns per section
- `Status` value enum
- `Source of decision` value enum
- Path allowlist regex (canonical)
- Layer-to-placeholder mapping (used by skip-list derivation)
- "Additive vs non-additive" canonical definition

When extending the schema, update that doc first; both detectors and appliers reference it.

## When to update this file

1. The pre-apply gate template changes (new gate, removed gate, reordering).
2. The manifest format changes.
3. The lockfile format changes (more fields, different file structure).
4. A new applier-pattern primitive is introduced (e.g., a "dry-run" mode).
