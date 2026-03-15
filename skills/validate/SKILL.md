---
name: validate
description: Validate built code against project standards and conventions. Checks coding standards, test quality, naming, formatting, and configuration. Use after implementation to catch issues before committing.
---

# Validate

Validate code against project standards and conventions. Runs all checks and produces a report.

## Usage

```
/validate TICKET-1234          # Validate files for a specific ticket
/validate                      # Validate all uncommitted changes
```

## Process

1. **Identify changed files** — scope to ticket or all uncommitted changes
2. **Load domain references** — based on what's touched
3. **Run all checks** — see check matrix below
4. **Output report** — checklist with ERROR/WARN/PASSED counts

## Identifying Changed Files

**Ticket-scoped** (ID provided):
```bash
git diff --name-only origin/{{BASE_BRANCH}}...HEAD
```
Filter to files matching the ticket. Also check `docs/stories/{TICKET_ID}/`.

**All uncommitted** (no ID):
```bash
git diff --name-only HEAD
git diff --name-only --cached
```

## Check Matrix

Checks are split into two tiers:
- **Universal checks** — active by default, work for any language/framework.
- **Language-specific checks** — examples you enable per-project by uncommenting or adding to your project CLAUDE.md.

---

### Universal Checks (Active by Default)

#### Secrets & Credentials (ERROR)

Grep changed files for patterns that indicate leaked secrets. Flag any match as ERROR.

| Pattern | Example Match |
|---------|---------------|
| `(?i)(api[_-]?key\|secret[_-]?key\|access[_-]?token\|auth[_-]?token)\s*[:=]` | `API_KEY = "sk-abc123"` |
| `(?i)(password\|passwd\|pwd)\s*[:=]\s*["'][^"']+["']` | `password = "hunter2"` |
| `(?i)bearer\s+[A-Za-z0-9\-._~+/]+=*` | `Authorization: Bearer eyJhbG...` |
| `(?i)(aws_secret_access_key\|AKIA[0-9A-Z]{16})` | AWS access key IDs |
| Private key headers: `-----BEGIN (RSA\|EC\|DSA\|OPENSSH) PRIVATE KEY-----` | Embedded private keys |
| Connection strings with credentials: `://[^:]+:[^@]+@` | `postgres://user:pass@host` |

**How to run:**
```bash
# Grep each changed file against the patterns above
grep -rEn '(?i)(api[_-]?key|secret[_-]?key|access[_-]?token)\s*[:=]' <changed_files>
grep -rEn '(?i)(password|passwd|pwd)\s*[:=]\s*["'"'"'][^"'"'"']+["'"'"']' <changed_files>
grep -rEn '-----BEGIN (RSA|EC|DSA|OPENSSH) PRIVATE KEY-----' <changed_files>
grep -rEn '://[^:]+:[^@]+@' <changed_files>
```

Ignore matches inside test fixtures, mocks, `.example` files, or documentation.

#### Hardcoded Production URLs (WARN)

Flag URLs that point to production or live environments. These should be in config/env vars.

| Pattern | Why |
|---------|-----|
| `https?://([a-z0-9-]+\.)?prod(uction)?\.` | Direct production domain references |
| `https?://api\.(company\|service)\.com` | Hardcoded API base URLs (should come from env) |
| Hostnames containing `prod`, `live`, `release` in non-config files | Environment-specific values belong in config |

Ignore matches in config files, `.env.example`, and documentation.

#### Unresolved TODOs / FIXMEs / HACKs (WARN)

```bash
grep -rEn '\b(TODO|FIXME|HACK|XXX|TEMP|WORKAROUND)\b' <changed_files>
```

Report each match with file and line number. These indicate incomplete work that should be resolved or tracked as a separate ticket before merging.

#### Large Files (WARN)

Flag any changed file exceeding 500 lines. Large files often indicate a need to split into smaller, focused modules.

```bash
wc -l <changed_files> | awk '$1 > 500 { print "WARN: " $2 " has " $1 " lines" }'
```

#### Debug / Console Output in Non-Test Files (ERROR)

Flag debug output left in source files. Only check non-test files (exclude `*test*`, `*spec*`, `*_test.*`, `*.test.*`).

| Language | Patterns to Flag |
|----------|-----------------|
| JavaScript/TypeScript | `console.log`, `console.debug`, `console.warn` (but not `console.error`) |
| Python | `print(`, `pdb.set_trace()`, `breakpoint()`, `import pdb` |
| Go | `fmt.Println`, `fmt.Printf` (in non-main, non-test files) |
| Java/Kotlin | `System.out.print`, `e.printStackTrace()` |
| Ruby | `puts `, `pp `, `binding.pry`, `byebug` |
| Rust | `dbg!`, `println!` (in library code) |
| C# | `Console.WriteLine` (in non-program entry files) |

**How to run:** Filter changed files to exclude test files, then grep for the relevant patterns based on file extension.

#### Commented-Out Code (WARN)

Look for blocks of commented-out code (3+ consecutive commented lines that appear to be code, not documentation). Heuristic:

```bash
# Look for consecutive comment lines containing code-like patterns (assignments, function calls, braces)
grep -n '^\s*//.*[=;{()}]' <changed_files>   # C-style
grep -n '^\s*#.*[=;{()}]' <changed_files>     # Python/Ruby/Shell
```

Flag clusters of 3+ consecutive matches as WARN.

#### Constants Over Magic Values (WARN)

Flag repeated string or number literals (same literal appearing 3+ times across changed files). Candidates for extraction into named constants.

Ignore: `0`, `1`, `-1`, `""`, `true`, `false`, `null`, `nil`, `undefined`, `None`.

---

### Direct External API Calls (ERROR)

Flag any HTTP call in non-test source files that hits an external URL directly instead of going through a service wrapper.

```bash
# Find fetch/axios calls with hardcoded external URLs in source files
grep -rEn '(fetch|axios\.(get|post|put|delete|patch))\s*\(\s*[`"'"'"']https?://' <changed_source_files>
```

Ignore:
- Test files (`*.test.*`, `*.spec.*`)
- Files inside `__mocks__/` or `fixtures/`
- Service wrapper files (`src/lib/services/*`)
- Calls to `localhost` or relative URLs

If a direct external call is found, check `.claude/skills/mock-endpoint/references/INDEX.md` — if a wrapper exists for that service, flag as ERROR with a fix suggestion to use the wrapper.

### Test Quality (ERROR)

| Check | How to Detect | Severity |
|-------|---------------|----------|
| Adequate assertions | Test functions/methods must contain at least one assertion (`assert`, `expect`, `should`, `Equal`, `Contains`, etc.) | ERROR |
| No production data in tests | Grep for `SeeAllData`, real email addresses, or production hostnames in test files | ERROR |
| Test file naming | Test files must follow project conventions (e.g., `*.test.ts`, `*_test.go`, `test_*.py`) | WARN |
| External API mock coverage | Service wrappers in `src/lib/services/` must have corresponding mock fixtures | WARN |

### Naming Conventions (WARN)

| Check | How to Detect | Severity |
|-------|---------------|----------|
| Files follow naming pattern | Check against project conventions (kebab-case, PascalCase, snake_case as configured) | WARN |
| Variables follow style guide | Check casing conventions per language defaults | WARN |

### Formatting (ERROR)

```bash
{{FORMAT_VERIFY_COMMAND}}
```

If this fails, list which files need formatting. Do NOT auto-fix — report only.

### Configuration / Manifest (ERROR)

| Check | How to Detect | Severity |
|-------|---------------|----------|
| Ticket manifest exists | Check for ticket-specific config/manifest | ERROR |
| Main manifest updated | Verify new components in main config | ERROR |
| Version/API consistency | Check version numbers match project standard | ERROR |

---

## Language-Specific Checks (Enable Per-Project)

> These checks are **not active by default**. Enable them by adding the relevant section to your project's `CLAUDE.md` or by uncommenting them here after copying to your project.

### Node.js / TypeScript

| Check | How to Detect | Severity |
|-------|---------------|----------|
| No `console.log` in `src/` | `grep -rn 'console\.log' src/ --include='*.ts' --include='*.js'` (exclude test dirs) | ERROR |
| No `any` type in TypeScript | `grep -rn ': any\b' src/ --include='*.ts'` — each use weakens type safety | WARN |
| Missing error handling in async | Grep for `async` functions that lack `try/catch` or `.catch()` — unhandled rejections crash Node | ERROR |
| No `require()` in ES module projects | `grep -rn 'require(' src/ --include='*.ts'` — should use `import` | WARN |
| No `@ts-ignore` / `@ts-nocheck` | `grep -rn '@ts-ignore\|@ts-nocheck' src/` — suppresses real type errors | WARN |

### Python

| Check | How to Detect | Severity |
|-------|---------------|----------|
| No `print()` in `src/` | `grep -rn 'print(' src/ --include='*.py'` (exclude test dirs) | ERROR |
| No bare `except:` | `grep -rn 'except:' src/ --include='*.py'` — catches everything including `KeyboardInterrupt` | ERROR |
| Missing type hints on public functions | Parse function defs in `src/` — public functions (no `_` prefix) should have return type annotations | WARN |
| No `import *` | `grep -rn 'from .* import \*' src/ --include='*.py'` — pollutes namespace | WARN |
| No mutable default arguments | `grep -rn 'def .*=\s*\[\]\|def .*=\s*{}' src/ --include='*.py'` — classic Python gotcha | ERROR |

### Go

| Check | How to Detect | Severity |
|-------|---------------|----------|
| No `fmt.Println` in non-test code | `grep -rn 'fmt\.Print' --include='*.go' --exclude='*_test.go'` (exclude `main.go`) | ERROR |
| Unchecked errors | Look for function calls that return `error` where the error is assigned to `_` or ignored | ERROR |
| No unused imports | `go vet ./...` or grep for imports not referenced in file body | ERROR |
| No `panic()` in library code | `grep -rn 'panic(' --include='*.go' --exclude='*_test.go'` — libraries should return errors | WARN |
| Errors should wrap context | `grep -rn 'return err$' --include='*.go'` — prefer `fmt.Errorf("context: %w", err)` | WARN |

---

## Domain Reference Loading

Based on changed files, load relevant domain skill references:

| Files Touched | Load References |
|---------------|-----------------|
| {domain-specific patterns} | `.claude/skills/{domain}/references/` |

Cross-check built components against reference inventories.

## Output Report

```
## Validation Report — {TICKET_ID}

### Summary
- ERRORS: {count}
- WARNINGS: {count}
- PASSED: {count}

### Secrets & Credentials
- [x] PASSED — No secrets or credentials detected

### Production URLs
- [x] PASSED — No hardcoded production URLs

### Debug Output
- [ ] ERROR — console.log found in src/utils/api.ts:42
- [ ] ERROR — print() found in src/helpers/parse.py:18

### Unresolved TODOs
- [ ] WARN — TODO found in src/service.ts:99: "TODO: handle timeout"

### Large Files
- [ ] WARN — src/models/user.ts has 612 lines

### Code Standards
- [x] PASSED — No commented-out code blocks
- [x] PASSED — No magic values detected

### Test Quality
- [x] PASSED — All tests have assertions
- [x] PASSED — No production data in tests

### Naming
- [x] PASSED — All conventions followed

### Formatting
- [x] PASSED — Formatter check clean

### Configuration
- [x] PASSED — Manifests correct
```

## Integration with /develop

This skill is called by `/develop` Phase 5 as a parallel task alongside deployment validation.

## Related Skills

- `/develop` - Full dev cycle (calls `/validate` in Phase 5)
- Domain skills - Project-specific references
