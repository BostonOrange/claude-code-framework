# Project Detection — Shared Bash Inventory

Canonical bash blocks for project-state detection. Used by:
- `templates/agents/project-setup-detector.md` — first-run onboarding
- `templates/agents/framework-improver-detector.md` — ongoing evolution (read-only scan)
- `templates/agents/framework-improver-applier.md` — ongoing evolution (apply with skip-list)
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

**Network / registry calls** — the detector and improver are local-only:
- `curl`, `wget`, `nc`, `ssh`, `scp`, `rsync` to remotes
- `npm view`, `npm publish`, `pip search`, `pip download` from remote indexes
- `gh api`, `gh repo`, `gh issue` (any remote `gh` operation)
- `gem list --remote`, `gem fetch`
- `cargo publish`, `cargo search`
- `go get` (network fetch)

**Filesystem reads outside the working tree** — out of scope:
- `cat ~/.aws/credentials`, `cat ~/.aws/config`
- `cat ~/.ssh/id_*`, `cat ~/.ssh/known_hosts`
- `cat /etc/passwd`, `cat /etc/shadow`, `cat /etc/hosts`
- `cat ~/.netrc`, `cat ~/.docker/config.json`, `cat ~/.kube/config`
- Any `find /` or `find ~/` (use the working tree, not the home directory)

**Environment / secrets exfiltration** — never:
- `env | grep -i token`, `env | grep -i secret`, `env | grep -i key`
- `printenv | grep ...`
- `set | grep ...` (shell builtin variant)

**Unbounded scans**:
- `find /` from the filesystem root
- `git log --all` with no path restriction (can dump enormous output for monorepos)
- `tar` / `zip` of arbitrary directories

If your detection logic seems to need any of these, flag it as a recommendation in the proposal — don't just add it. The "no network, no exfil" property is a contract maintained by these instructions, not a sandbox guarantee. Verify in the agent's transcript that none of these ran.

## When to update this file

1. A new common manifest, lockfile, or config emerges (e.g., a new package manager).
2. A detection gap is found in `framework-improver-detector` or `project-setup-detector` output.
3. A network-touching command sneaks into one of the agents — move it here as a "what NOT to run" entry.
