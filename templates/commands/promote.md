---
name: promote
description: Build a Layer 2 promotion evidence report for an internal Next.js business app
allowed-tools: Read, Write, Edit, Glob, Grep, Bash, Task
---

Use the `promote` skill.

## Steps

1. Confirm the target is a provisioned internal Next.js business app with `LAYER.md`.
2. Run the Layer 2 mechanical checks and validation commands from the skill.
3. Run `security-auditor`, `observability-reviewer`, and `supply-chain-reviewer`.
4. Write `.claude/state/promotion-l2-report.md`.
5. Report whether the project is blocked or ready for IT review. Do not update `LAYER.md`.
