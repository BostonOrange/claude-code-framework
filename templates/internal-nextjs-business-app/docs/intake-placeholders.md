# Intake Placeholders

This template expects a **provisioning system** (e.g. an internal portal with SSO + intake form) to stamp project-specific values into seed files at repo-creation time. This file is the contract between this template and any such provisioner.

The portal/provisioning system itself is **not part of this framework** — it is a separate product. This file only documents what the template needs from it.

## Placeholder convention

Tokens use the form `<<intake:field_name>>`. They are deliberately distinct from the framework's double-brace `setup.sh` developer-facing placeholders, so the two substitution stages don't collide.

A freshly cloned, **unprovisioned** seed file will contain literal `<<intake:...>>` tokens. That is intentional — it makes it obvious when stamping has not happened. Documentation files may mention token names as examples and are not considered unresolved seed files.

## Tokens

| Token | Source | Example | Notes |
|---|---|---|---|
| `<<intake:owner_email>>` | SSO | `jordan.lee@example.com` | Used as audit-log identity and repo admin |
| `<<intake:owner_display>>` | SSO | `Jordan Lee` | Display name |
| `<<intake:division>>` | SSO group claim | `Finance` | Drives hub views; defaults to `Unknown` if no group claim |
| `<<intake:project_name>>` | Form | `Field Trip Approval Tracker` | Human-readable |
| `<<intake:project_slug>>` | Form | `finance-field-trips` | Repo name; kebab-case; division-prefixed by convention |
| `<<intake:project_description>>` | Form (AI-assisted, user-confirmed) | One paragraph | The user reviews the AI output before submit |
| `<<intake:project_who>>` | Form | One sentence | Who uses the tool |
| `<<intake:project_why>>` | Form | One sentence | Business problem |
| `<<intake:expected_users>>` | Form enum | `my team (≤ 20)` | Hint for promotion timing |
| `<<intake:layer>>` | Always `1` at provisioning | `1` | Promotion to higher layers happens via review, not intake |
| `<<intake:template_version>>` | Provisioning system | `v1.3.0` | The audited template release tag the repo was created from. Never mutable `main`. |
| `<<intake:provisioned_at>>` | Provisioning system | ISO 8601 | UTC timestamp |

## Files containing tokens

| File | Stamping rule |
|---|---|
| `LAYER.md.template` | Stamp tokens; **rename to `LAYER.md`** after stamping. The `.template` suffix is the marker that stamping is required. |

When new files with intake tokens are added to this template, list them above and update the provisioner's stamp step.

## Rules for the provisioning system

1. **Provision from a tagged release of the template repo, never from mutable `main`.** Record the exact tag in `<<intake:template_version>>`. IT audits a tag, not a moving target.
2. **Stamp is a single atomic commit** authored by the portal's bot identity, with a message naming the requesting user (`Initialize project from intake by <owner_email>`).
3. **Verify zero `<<intake:*>>` tokens remain in stamped seed files** before handing the repo to the user. Today that means `LAYER.md`, plus any future files listed in [Files containing tokens](#files-containing-tokens). Documentation files may still mention token names as examples.
4. **Never edit application source as part of stamping.** The current stamping contract only requires `LAYER.md.template` -> `LAYER.md`. A provisioner may also prepend generated owner/project metadata to docs such as `README.md` or `CLAUDE.md`, but it must not edit application code.
5. **The portal owns its own audit log** (who/what/why text, who, when, template version, blocked requests, promotion state). GitHub topics are useful for hub views but are not a sufficient audit substrate.

## Out of scope for this template

These belong to the provisioning system, not this template:
- The intake form UI and AI assistant prompt wording
- SSO integration with Entra
- The hub view that lists what's been provisioned
- The `/promote` workflow and Layer 2 review tooling (that lives at the framework level; see `templates/internal-nextjs-business-app/docs/deployment-layers.md` for the checklist it packages as evidence)
- Local prerequisite checks on the user's laptop (Claude Code, Node, Docker, Git). A "first 10 minutes" doctor flow is the portal team's responsibility because it is delivered alongside the download/clone instructions.
