# Project Detection — Shared Bash Inventory

Canonical bash blocks for project-state detection. Used by:
- `templates/agents/project-setup-detector.md` — first-run onboarding
- `templates/agents/framework-improver.md` — ongoing evolution
- `skills/improve/SKILL.md` — manual `/improve` invocation

When you find yourself listing manifests / lockfiles / configs in another agent or skill, **add it here and reference this file** instead of duplicating. Drift between these lists has caused gaps before (e.g., missing `Pipfile`, `*.csproj`, `mix.exs`).

## MANIFEST_INVENTORY

```bash
ls package.json pyproject.toml requirements.txt setup.py Pipfile poetry.lock \
   Cargo.toml go.mod pom.xml build.gradle build.gradle.kts \
   Gemfile composer.json sfdx-project.json *.csproj \
   mix.exs 2>/dev/null
```

Covers: Node, Python (pip/poetry/pipenv/setup.py), Rust, Go, Java/Kotlin (maven + gradle), Ruby, PHP, Salesforce, .NET (C#), Elixir.

> Swift (`Package.swift`) and F# (`*.fsproj`) are not currently wired through to the Layer 1 detection logic in `project-setup-detector.md`. If your project needs them, add the manifest pattern here AND extend the language options in `project-setup-detector.md`'s Layer 1 row. Don't add aspirational coverage that the layer table doesn't act on.

## LOCKFILE_INVENTORY

```bash
ls package-lock.json yarn.lock pnpm-lock.yaml bun.lockb \
   poetry.lock Pipfile.lock Cargo.lock go.sum \
   Gemfile.lock composer.lock 2>/dev/null
```

Lockfile presence is the strongest signal for build-tool selection.

## CONFIG_INVENTORY

```bash
ls tsconfig.json jsconfig.json mypy.ini pyrightconfig.json \
   .eslintrc* eslint.config.* .prettierrc* prettier.config.* \
   .rubocop.yml .golangci.yml ruff.toml \
   Dockerfile docker-compose.* vercel.json netlify.toml \
   Procfile fly.toml railway.toml serverless.yml \
   .github .gitlab-ci.yml .circleci Jenkinsfile \
   nx.json turbo.json lerna.json pnpm-workspace.yaml rush.json \
   BUILD.bazel WORKSPACE 2>/dev/null
```

Covers: type checkers, linters, formatters, container/serverless/PaaS configs, CI platforms, monorepo tooling.

## FRAMEWORK_SIGNALS (glob)

Run via `Glob`, not `ls`:
- `next.config.*`, `vite.config.*`, `angular.json`, `nuxt.config.*`
- `svelte.config.*`, `astro.config.*`, `remix.config.*`
- `tailwind.config.*`, `phoenix.exs`
- `*.csproj` for .NET, `Package.swift` for Swift packages

## FILE_EXTENSION_CENSUS

Top 20 extensions, excluding common noise:

```bash
find . -type f \
  -not -path "*/.git/*" \
  -not -path "*/node_modules/*" \
  -not -path "*/__pycache__/*" \
  -not -path "*/vendor/*" \
  -not -path "*/.next/*" \
  -not -path "*/dist/*" \
  -not -path "*/build/*" \
  | sed 's/.*\.//' | sort | uniq -c | sort -rn | head -20
```

## GIT_STATE

```bash
git remote -v 2>/dev/null | sed -E 's|://[^@/]*@|://REDACTED@|g'
git config --get init.defaultBranch 2>/dev/null
git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null
```

The `sed` redaction strips embedded credential tokens (`https://x-access-token:GHP_xxx@github.com/...`) before the URL ever lands in any state file. **Always pipe `git remote -v` through this redactor** before writing it to disk.

## What NOT to run

- `npm view`, `pip search`, `gh api`, `gem list --remote` — network calls; the detector and improver are local-only.
- `cat ~/.aws/credentials`, `cat ~/.ssh/*` — outside the working directory.
- `find /` or any unbounded recursive scan from the filesystem root.

## When to update this file

1. A new common manifest, lockfile, or config emerges (e.g., a new package manager).
2. A detection gap is found in `framework-improver` or `project-setup-detector` output.
3. A network-touching command sneaks into one of the agents — move it here as a "what NOT to run" entry.
