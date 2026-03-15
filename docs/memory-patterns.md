# Memory-Aware Skill Patterns

How skills should read and leverage persistent memory for smarter behavior.

## Memory Types Recap

| Type | What It Stores | Skill Usage |
|------|---------------|-------------|
| `user` | Role, expertise, preferences | Tailor explanations, skip obvious context |
| `feedback` | Corrections from user | Avoid repeating mistakes |
| `project` | Ongoing work, decisions, deadlines | Inform suggestions, flag conflicts |
| `reference` | External system pointers | Know where to look for info |

## Pattern 1: Worktree Preference

**Skill:** `/develop` Phase 3 (branch setup), `/ai-update`, `/factory`

**Memory reads:**
```markdown
Check memory for user's worktree workflow:
- Do they keep a dedicated worktree for the base branch?
- Do they create feature branches as worktrees?
- What naming convention do they use?
```

**How it changes behavior:**

| Memory Says | Skill Does |
|-------------|------------|
| "Always uses worktrees" | Skip the worktree/main-repo prompt, create worktree |
| "Dedicated develop worktree at ../Project-develop" | Never checkout base branch in main repo |
| No memory | Ask user for preference |

**When to save:** After user answers the worktree prompt for the first time.

## Pattern 2: Environment Aliases

**Skill:** `/develop` Phase 5 (validation), `/deploy`, `/error-analyze`

**Memory reads:**
```markdown
Check memory for known environment aliases:
- What's the shared dev environment alias?
- What's the UAT/staging alias?
- Which environments are CI-only?
```

**How it changes behavior:**

| Memory Says | Skill Does |
|-------------|------------|
| "Shared dev environment is dev-01" | Pre-select for deployment |
| "CI environments: ci-1, ci-2, dryrun-1, dryrun-2" | Skip these when listing user options |
| "Production environment is prod" | Add confirmation gate before any prod operation |

**When to save:** After user confirms which environment to deploy to.

## Pattern 3: Recurring Build Fixes

**Skill:** `/develop` Phase 6 (fix failures), `/validate`

**Memory reads:**
```markdown
Check memory for known build issues:
- Required fields in access configuration files (deployment will fail)
- Pre-deploy schema ordering
- Field references that don't exist in all environments
- Test data factory quirks
```

**How it changes behavior:**

| Memory Says | Skill Does |
|-------------|------------|
| "Required fields cause access config deploy failure" | Don't add required fields to access configuration files |
| "New schema must pre-deploy before workflows" | Create pre-deploy manifest automatically |
| "LegalEntity.cin field doesn't exist in all environments" | Exclude from package or pre-deploy |

**When to save:** After a build failure that required a non-obvious fix.

## Pattern 4: Team Preferences

**Skill:** `/develop` Phase 7 (PR), `/ai-update`, `/deploy`

**Memory reads:**
```markdown
Check memory for team conventions:
- PR title format
- PR review process (CODEOWNERS? self-assign?)
- Commit message style
- Formatting approach (pre-commit hooks vs manual)
```

**How it changes behavior:**

| Memory Says | Skill Does |
|-------------|------------|
| "PR title: {TICKET-ID}: {exact story title}" | Use exact format |
| "No CODEOWNERS, team picks up PRs" | Don't add reviewers |
| "Pre-commit hooks handle formatting" | Don't run prettier/formatter manually |

**When to save:** When user corrects a PR format or process assumption.

## Pattern 5: User Role Adaptation

**Skill:** All skills, especially explanations and suggestions

**Memory reads:**
```markdown
Check memory for user's role and expertise:
- Are they a senior dev or learning?
- Do they have deep backend experience but are new to frontend?
- Are they an architect who doesn't code?
```

**How it changes behavior:**

| Memory Says | Skill Does |
|-------------|------------|
| "Senior Go dev, first time touching React" | Frame frontend explanations using backend analogues |
| "Solutions architect, doesn't code" | Focus on design decisions, skip implementation details |
| "Junior dev" | Explain reasoning, suggest learning resources |

**When to save:** When user reveals their role or experience level.

## Pattern 6: Feedback-Driven Behavior

**Skill:** Any skill the user has corrected before

**Memory reads:**
```markdown
Check memory for past corrections:
- "Don't summarize what you did after each response"
- "Don't mock the database in integration tests"
- "Always use the full package manifest for validation"
```

**How it changes behavior:**

These memories are **the most important** — they prevent the AI from repeating mistakes. A single feedback memory can save hours of frustration across dozens of conversations.

| Memory Says | Skill Does |
|-------------|------------|
| "Don't summarize after each response" | Terse output, no trailing summaries |
| "Don't mock DB in integration tests" | Use real test database, even if slower |
| "Always validate with full manifest" | Don't use story-specific package for validation |

**When to save:** Immediately when user corrects you. Include the **why** so future conversations understand the reasoning.

## Implementing Memory Awareness in Skills

### Reading Memory

In your SKILL.md, add memory checkpoints at decision points:

```markdown
### Phase 3: Branch Setup

**Check memory** for worktree preference before prompting:
- If memory says "always worktree" → create worktree without asking
- If memory says "main repo" → checkout branch without asking
- If no memory → ask user, then save their preference

**Check memory** for base branch name:
- If memory has the base branch → use it
- If not → use {{BASE_BRANCH}} from CLAUDE.md
```

### Writing Memory

Skills should save memory when they learn something new:

```markdown
After user selects deployment target:
**Save to memory:** "User deploys to {alias} for validation. CI environments are {list}."

After a non-obvious build fix:
**Save to memory:** "Build fix: {description of the issue and the non-obvious solution}"
```

### Memory in Factory Mode

Factory mode (`--factory`) should still **read** memory but typically **not write** new memories, since factory runs are automated and may not reflect user preferences.

Exception: build fixes discovered during factory runs SHOULD be saved — they help future runs.

## Memory File Examples

### user_role.md
```markdown
---
name: user_role
description: Senior developer, deep backend expertise, new to frontend frameworks
type: user
---

Senior backend developer with 5+ years of server-side experience. New to React — explain frontend patterns in terms of backend analogues where possible. Prefers terse communication, no summaries.
```

### feedback_no_mock_db.md
```markdown
---
name: feedback_no_mock_db
description: Integration tests must hit real database, not mocks
type: feedback
---

Integration tests must use real database connections, not mocks.

**Why:** Last quarter, mocked tests passed but the production migration failed because mock/prod diverged on schema changes.

**How to apply:** When writing test classes that involve database operations, always use test data factories with real database writes. Never mock the database layer.
```

### project_merge_freeze.md
```markdown
---
name: project_merge_freeze
description: Merge freeze starts 2026-03-05 for mobile release branch cut
type: project
---

Merge freeze on non-critical PRs begins 2026-03-05 (Thursday). Mobile team is cutting a release branch.

**Why:** Release branch stability — no unrelated changes during release prep.

**How to apply:** Flag any non-critical PR work scheduled after March 5. Critical fixes can still merge with team lead approval.
```
