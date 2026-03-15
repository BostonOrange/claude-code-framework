---
name: merge-resolve
description: AI-powered merge conflict resolution. Reads both features' story docs to understand intent, resolves conflicts per file type, validates merged result. Works for any codebase.
---

# Merge Resolve

Resolve merge conflicts by understanding both features' intent — not just the code diff.

## Usage

```
/merge-resolve TICKET-1234                  # Resolve conflicts on TICKET-1234's PR
/merge-resolve TICKET-1234 --auto           # Resolve, push, and notify automatically
```

## When This Runs

1. **Factory PR can't merge** — base branch has changed since PR was created
2. **CI workflow detects conflict** — auto-merge fails
3. **Developer notices** — PR shows merge conflicts on GitHub

## Why This Is Better Than Manual Resolution

Traditional conflict resolution looks at **code only** — which lines overlap. This skill reads both features' **story documentation** to understand **why** each side made changes, then resolves based on intent:

- Method A was added for "invoice line item validation" (Story US-100)
- Method B was added for "batch processing of work orders" (Story US-200)
- Resolution: keep both methods — they serve different purposes

## Step 1: Identify Conflicts

```bash
git fetch origin {{BASE_BRANCH}}

BRANCH="{TICKET_ID}"
git checkout "$BRANCH"
git merge origin/{{BASE_BRANCH}} --no-commit --no-ff 2>&1 | tee /tmp/merge-status.txt

# List conflicted files
git diff --name-only --diff-filter=U
```

If no conflicts → merge cleanly → done. Skip to Step 5.

## Step 2: Understand Both Features

For each conflicted file, identify which tickets modified it:

```bash
MERGE_BASE=$(git merge-base HEAD origin/{{BASE_BRANCH}})
git log --oneline "$MERGE_BASE..origin/{{BASE_BRANCH}}" -- {conflicted_file}
```

For each ticket involved:
1. Read `docs/stories/{OTHER_TICKET_ID}/story.md` — understand the feature intent
2. Read `docs/stories/{OTHER_TICKET_ID}/solutions-components.md` — understand what was built
3. Read the **current ticket's** equivalent docs

This gives full context on **why** each side made its changes.

## Step 3: Resolve Conflicts

Apply resolution rules based on file type and feature intent:

### Resolution Rules by File Type

| File Type | Strategy | Human Review? |
|-----------|----------|---------------|
| **Source code — different functions/methods** | Keep both | No |
| **Source code — same function modified** | Merge logic based on story intent | Yes, if complex |
| **Source code — imports/dependencies** | Combine both sets | No |
| **Configuration files** | Union of both, deduplicate | No |
| **Permission/access files** | Union of both — never remove | No |
| **Manifest/package files** | Union of components, deduplicate | No |
| **Schema/migration files** | Keep both (may need ordering) | Yes |
| **Flow/workflow files** | Flag for review unless changes are in different elements | Yes |
| **Test files** | Keep both test cases | No |
| **Test data factories/fixtures** | Merge factory methods | No |
| **UI components — same file** | Merge based on feature intent | Yes, if complex |
| **Story docs** | No conflict (different ticket folders) | No |

### General Principles

1. **Both features should work after merge** — don't break either side
2. **When uncertain, keep both sides** and flag for human review
3. **Never silently drop changes** — if you can't merge confidently, ask
4. **Permission/access is additive** — always union, never intersect
5. **Manifest/config is additive** — combine entries, deduplicate

### Language-Specific Patterns

**JavaScript/TypeScript:**
- Both added exports → combine export list
- Both modified same function → check if changes are in different code paths
- Package.json conflicts → take higher version numbers, combine scripts

**Python:**
- Both added imports → combine, sort
- Both added methods to same class → keep both
- requirements.txt → take higher versions

**Java/Kotlin/C#:**
- Both added methods → keep both
- Both modified same method → merge based on story intent
- Annotation conflicts → combine

**XML/JSON config:**
- Element ordering → sort consistently
- Both added entries → deduplicate by key/name

## Step 4: Validate Merged Result

After resolving conflicts:

```bash
git add {resolved_files}
git commit -m "{TICKET_ID}: merge resolve with {{BASE_BRANCH}}"
```

Run validation:
```bash
{{TEST_COMMAND}}
```

If tests fail → the merge resolution introduced an issue. Review and fix before pushing.

## Step 5: Push

```bash
git push origin {TICKET_ID}
```

If CI is configured, the push triggers validation automatically. Errors appear as PR comments.

Report to user:

> **Merge conflicts resolved for TICKET-{id}.**
>
> | Conflicted File | Resolution |
> |----------------|------------|
> | `ServiceHandler.ts` | Merged methods from TICKET-1234 and TICKET-5678 |
> | `permissions.json` | Combined access entries |
>
> Pushed — CI will validate. PR is ready for re-review.

## Step 6: Notify (--auto mode)

In `--auto` mode, post notification for smoke testing:

{{NOTIFY_MERGE_RESOLVE}}

This creates a verification gate — merged result of two features needs human sign-off.

## Integration with Factory Pipeline

### Automatic Detection

When `factory-auto-merge.yml` fails due to conflicts:
1. Post notification: "TICKET-{id} has merge conflicts with {{BASE_BRANCH}}"
2. Suggest running `/merge-resolve TICKET-{id}`

### Overlap Detection

Multiple factory PRs modifying the same files will conflict when the second one tries to merge. The AI reads both stories' docs to understand intent and resolve confidently.

## Edge Cases

| Scenario | Behavior |
|----------|----------|
| No conflicts (clean merge) | Skip to Step 5, push |
| Conflict in file neither story's docs explain | Flag for human review, do not guess |
| More than 2 tickets conflicting | Resolve pairwise — merge with base (which contains all previously merged changes) |
| Schema/migration conflicts | Always flag for human review — ordering matters |
| Deployment config conflicts | Union of all entries, deduplicate |
| Tests fail after resolution | Report failure, suggest human review |
| CI deploy fails after push | Error posted as PR comment — fix and push again |

## Related Skills

- `/factory` — invokes merge-resolve when PR has conflicts
- `/develop` — the implementation pipeline that created the PR
- `/validate` — code standards check on merged result
