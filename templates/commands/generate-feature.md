---
name: generate-feature
description: Generate one feature slice from an existing internal app blueprint
allowed-tools: Read, Write, Edit, MultiEdit, Glob, Grep, Bash
---

Generate one bounded feature for an internal Next.js business app.

## Steps

1. Read `docs/app-blueprint.json` unless the command argument points to another blueprint.
2. Identify the requested entity, workflow, dashboard, or AI assist point.
3. Use the `generate-internal-app` skill in feature mode.
4. Keep edits scoped to the requested feature slice.
5. Run `npm run typecheck` and any focused tests when dependencies are installed.
6. Report files changed, validation results, and any blueprint updates needed.
