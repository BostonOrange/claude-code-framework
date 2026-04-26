---
id: supply-chain
patterns:
  - "package.json"
  - "package-lock.json"
  - "yarn.lock"
  - "pnpm-lock.yaml"
  - "requirements.txt"
  - "requirements*.in"
  - "poetry.lock"
  - "Pipfile.lock"
  - "go.mod"
  - "go.sum"
  - "Gemfile"
  - "Gemfile.lock"
  - "Cargo.toml"
  - "Cargo.lock"
  - "pom.xml"
  - "build.gradle"
  - "build.gradle.kts"
  - "*.csproj"
  - "Dockerfile"
  - ".github/workflows/*.yml"
  - ".gitlab-ci.yml"
---

# Supply Chain Rules

Citable standards used by the `supply-chain-reviewer` agent. Covers OWASP A06:2021 (Vulnerable & Outdated Components) and A08:2021 (Software & Data Integrity Failures) — the dependency tree, the build pipeline, and what enters production.

The principle: **the code you didn't write runs your application too.** Treat dependencies and pipelines like first-party code: pinned, verified, audited.

## Lockfile Hygiene

**Detect:**
- Lockfile missing for a dependency manifest that supports one (`package.json` without `package-lock.json` / `yarn.lock`, `requirements.txt` without `poetry.lock` or `requirements.txt` pinned)
- Lockfile not committed to the repo
- Dependency added to manifest without lockfile update in the same PR (drift)
- Multiple lockfiles for the same ecosystem (`package-lock.json` AND `yarn.lock` — pick one)
- Dependencies pinned with floating ranges (`^1.2.3`, `~1.2.3`, `>=1.2.0`) without a lockfile

**Fix:**
- Generate and commit lockfile for every ecosystem that supports it
- Lockfile updates in the same PR as manifest updates
- Single tool per ecosystem (one of npm OR yarn OR pnpm)

## Version Pinning Strategy

**Detect:**
- Application dependencies using `*` / `latest` / unpinned versions
- Docker base images with floating tags (`node:latest`, `python:3` instead of digest pinning or specific minor versions)
- CI action versions floating (`uses: actions/checkout@main` instead of `@v4` or `@<sha>`)
- Pre-release / unstable / `0.x` versions in production dependencies without justification

**Fix:**
- Application deps: pin to compatible range with lockfile resolving to exact version
- Library deps: pin loosely (`^1.2.0`) so consumers can resolve
- Docker base images: pin to digest (`node:20.11.0@sha256:...`) for reproducibility, or at minimum to specific patch
- CI actions: pin to tag for trust ecosystem; pin to SHA for unknown publishers
- `0.x` deps: explicit comment in PR justifying

## CVE Reachability

**Detect:**
- High/critical CVEs in production dependency tree
- CVEs in transitive dependencies that ARE reachable from application code (the audit tool says "high" — but is the vulnerable function actually called?)
- CVEs flagged for deps that are dev-only / build-only / test-only (false positives in production-blocking gates)
- Long-unaddressed CVEs accumulating (no policy on age)

**Fix:**
- Distinguish reachable from unreachable: tools like `socket`, `snyk`, GitHub `dependency-review` can analyze
- Block production deploy on reachable critical CVEs
- Auto-bump dev-only deps with critical CVEs (low risk to merge)
- Define an age policy: "no production CVE older than N days"

## Provenance & Signing

**Detect:**
- Packages installed from non-official registries without verification
- Container images pulled by tag without digest pinning
- CI artifacts uploaded without signing
- Production deploys that pull "latest" from a registry at runtime
- Unsigned scripts (`curl ... | bash`) in build / deploy paths

**Fix:**
- Use official registries; mirror through an internal proxy if scale demands
- Digest-pin container images; verify with `cosign verify` for signed images
- Sign your own artifacts (sigstore, cosign, GPG)
- Pull-by-digest in production manifests; resolve tags to digests at deploy time
- Replace `curl | bash` with: download → checksum verify → execute

## Dev-vs-Prod Dependency Separation

**Detect:**
- Test frameworks, linters, build tools listed under runtime dependencies (bloats production attack surface)
- Production dependencies listed under dev (will fail at runtime)
- `package.json`'s `dependencies` containing types/test-only packages
- `requirements.txt` mixing dev and prod (split into `requirements.txt` + `requirements-dev.txt` or use a tool that supports groups)

**Fix:**
- Ecosystems with the distinction: use it (`devDependencies`, `--save-dev`, `[tool.poetry.group.dev]`)
- Production builds install only production deps (`npm ci --omit=dev`, `poetry install --without dev`)

## Insecure Deserialization (A08)

**Detect:**
- Deserialization of untrusted input via dangerous APIs:
  - Python: `pickle.loads`, `yaml.load` (without `Loader=SafeLoader`), `marshal.loads`
  - Java: `ObjectInputStream.readObject` on untrusted data
  - PHP: `unserialize` on untrusted data
  - JS: `eval`, `Function(...)`, `vm.runInThisContext` on input
  - Ruby: `Marshal.load`, `YAML.load`
- Custom binary deserialization with no schema enforcement
- Deserializing into types based on type hints from the payload (gadget chains)

**Fix:**
- Use safe variants: `yaml.safe_load`, `json.loads`, schema-validated deserialization (Zod, Pydantic, protobuf)
- Never deserialize untrusted input with format-native object reconstruction
- For RPC: typed schemas (protobuf, Avro, JSON Schema) with validation

## CI/CD Pipeline Integrity

**Detect:**
- CI scripts that pull and execute remote scripts at runtime (`curl ... | bash`)
- Workflows triggered by untrusted contributors (`pull_request_target` patterns) with access to secrets
- Self-hosted runners exposed to untrusted PRs
- Secrets exposed to step outputs (`echo "$SECRET"` in CI logs)
- Workflows that build and push images to public registries from PR context

**Fix:**
- Use `pull_request` (not `pull_request_target`) for untrusted PRs
- Restrict secret access by job — secrets only available where needed
- Use ephemeral runners for untrusted PR builds
- Mask outputs; never echo secrets
- Separate "build" jobs (run for any PR) from "publish" jobs (require approval)

## Build Reproducibility

**Detect:**
- Build steps that fetch resources from the internet at build time (no caching, no checksum verification)
- Builds that produce different outputs from the same inputs (timestamp embedding, non-deterministic ordering)
- Missing build provenance (which commit, which Dockerfile, which deps versions produced this artifact)

**Fix:**
- Vendor / cache build inputs; verify checksums
- Eliminate non-determinism: pin timestamps to commit time, sort-stable outputs
- Embed build provenance: SLSA-style attestations or at minimum a `build-info` artifact with commit SHA, build time, dep manifest hash

## License Compliance

**Detect:**
- New dependencies with copyleft licenses (GPL, AGPL) in projects that ship proprietary code
- Dependencies with no license / unclear license
- License changes between dep versions (e.g., a dep that was MIT became "source-available")

**Fix:**
- License-allow-list in CI (`license-checker`, `pip-licenses`, `cargo-deny`)
- Document accepted licenses; flag any outside the list for human review

## Dependency Update Cadence

**Detect:**
- Dependencies with no update in many months / years (project unmaintained)
- Update PRs that consistently merge without review
- Lockfile updates that change hundreds of transitive deps without scrutiny

**Fix:**
- Automated update PRs (Dependabot, Renovate) with grouping for safety
- Mandatory human review on major version bumps and security updates
- "Prove the update is safe": tests run; impact on bundle size / startup time noted

## What NOT to Flag

- **Lockfiles in vendored / generated code** — they have their own discipline
- **Internal mirror configurations** — those are infrastructure, not application supply chain
- **CVEs that are clearly false positives for the deployment** (reachability analysis says no)
- **Dev-only deps with low-severity CVEs** — different risk profile
- **Pre-existing supply-chain issues in untouched manifests** — flag changes within the diff
- **Container images / CI configs in test-only branches** — apply rules in main, not WIP
- **Library / SDK projects** that publish loose dep ranges intentionally for consumer flexibility (verify intent first)
