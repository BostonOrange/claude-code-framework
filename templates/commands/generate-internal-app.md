---
name: generate-internal-app
description: Generate an internal Next.js business app from a blueprint
allowed-tools: Read, Write, Edit, MultiEdit, Glob, Grep, Bash
---

Use the `generate-internal-app` skill.

## Steps

1. Load the blueprint path from the command argument, defaulting to `docs/app-blueprint.json`.
2. Verify the internal app preset files exist.
3. Generate the Prisma, repository, API, UI, seed, test, and docs changes described by the blueprint.
4. Run focused validation commands when dependencies are installed.
5. Report generated files, validation results, and remaining gaps.
