# Start Here

This repo is a local-first internal tool starter. Start by reading the project-specific instructions, then ask Claude Code or Codex CLI to shape it into your tool.

Fastest path:

- macOS: double-click `RUN_ME_FIRST.command`
- Windows: double-click `RUN_ME_FIRST.cmd`

Or run this from a terminal:

```bash
npm run start-here
```

## Before You Start

You need:

- Claude Code or Codex CLI, signed in with your own subscription
- Node.js 22 or newer
- Docker Desktop only when `SETUP_MODE.md` says this project uses local Postgres or the full local stack
- Git

Check your machine:

```bash
npm run doctor
```

If the doctor reports missing required tools, install those first and run it again. It is normal for `.env.local` to be missing before the first setup; `npm run dev` creates it.

## First Run

If you prefer manual commands, run these from this folder:

```bash
npm run doctor
npm install
npm run dev
```

Open `http://localhost:3000`, then sign in with the demo admin.

`npm run dev` reads `PROJECT_BLUEPRINT.json` and `SETUP_MODE.md`. Memory, folder, and SQLite-style projects skip Docker. Local Postgres and full-stack projects start the needed Docker services.

## Ask Claude Code

Open Claude Code or Codex CLI in this folder. It should read `CLAUDE.md` or `AGENTS.md` automatically. If it asks what to do, use the prompt from:

```bash
npm run start-here
```

Good fallback prompts:

Good first prompts:

```text
Read NEXT_STEPS.md, PROJECT_BRIEF.md, PROJECT_BLUEPRINT.json, LOCAL_BASELINE.md, SETUP_MODE.md, LAYER.md, AGENTS.md, and docs/design-system.md. Then help me build the first useful version of this tool with mock data first.
```

```text
Help me model the first business object for this tool. Keep it local-first, auditable, and small enough to test today.
```

```text
Generate a first feature from my description, then tell me exactly how to test it locally.
```

## Pilot Rules

- Keep this at Layer 1 until IT approves sharing it with a team.
- Do not paste customer data, regulated data, secrets, or production exports into the app or into Claude.
- Follow `docs/design-system.md` for UI work.
- Use mock data before connecting real systems.
- Commit small changes with clear messages.
- If you want your team to use the app, ask for a Layer 2 review instead of sending people your local link.

## Useful Commands

```bash
npm run doctor
npm run dev
npm run typecheck
npm run lint
npm run build
```

For setup details, see `README.md`. For the Layer 1/2/3 model, see `docs/deployment-layers.md`.
