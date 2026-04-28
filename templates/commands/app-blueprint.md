---
name: app-blueprint
description: Convert business intent into docs/app-blueprint.json for the internal app generator
allowed-tools: Read, Write, Glob, Grep
---

Use the `app-blueprint` skill.

## Steps

1. Read the user's business intent and any referenced files.
2. Produce a valid internal app blueprint JSON.
3. Write it to `docs/app-blueprint.json` unless the user gave another path.
4. Report the blueprint path and any open questions that block generation.
