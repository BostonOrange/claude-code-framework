import { existsSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { fileURLToPath } from "node:url";

const root = join(fileURLToPath(new URL(".", import.meta.url)), "..");

function readJson(path) {
  if (!existsSync(path)) return null;
  return JSON.parse(readFileSync(path, "utf8"));
}

function readText(path) {
  return existsSync(path) ? readFileSync(path, "utf8") : "";
}

function firstNonEmptyLine(markdown) {
  return markdown
    .split(/\r?\n/)
    .map((line) => line.trim())
    .find((line) => line && !line.startsWith("#")) ?? "";
}

const manifest = readJson(join(root, ".claude", "project-manifest.json"));
const blueprint = readJson(join(root, "PROJECT_BLUEPRINT.json")) ?? manifest?.setupBlueprint;
const brief = readText(join(root, "PROJECT_BRIEF.md"));
const project = manifest?.project ?? {};
const owner = manifest?.owner ?? {};
const name = project.name ?? "this local tool";
const layer = project.layer ?? blueprint?.targetLayer ?? "1";
const persistence = blueprint?.localPersistenceKind ?? "not set";
const description = project.description ?? firstNonEmptyLine(brief) ?? "No project brief found yet.";

const prompt = blueprint?.firstAgentPrompt ?? [
  "Read PROJECT_BRIEF.md, PROJECT_BLUEPRINT.json, LOCAL_BASELINE.md, SETUP_MODE.md, LAYER.md, AGENTS.md, NEXT_STEPS.md, and docs/design-system.md.",
  `Then help me build the first useful version of ${name}.`,
  `Keep it Layer ${layer} and use the configured local persistence mode: ${persistence}.`,
  "Start by proposing the smallest workflow I can test today, then make the first code change.",
].join(" ");

process.stdout.write("\nInternal tools starter\n");
process.stdout.write("========================\n\n");
process.stdout.write(`Project: ${name}\n`);
if (owner.displayName) process.stdout.write(`Owner:   ${owner.displayName} <${owner.email ?? "no email"}>\n`);
process.stdout.write(`Layer:   ${layer}\n`);
process.stdout.write(`Setup:   ${persistence}${blueprint?.localPersistence ? ` (${blueprint.localPersistence})` : ""}\n\n`);
process.stdout.write(`${description}\n\n`);

process.stdout.write("Do this first:\n\n");
process.stdout.write("  Easiest:\n");
process.stdout.write("    macOS:   double-click RUN_ME_FIRST.command\n");
process.stdout.write("    Windows: double-click RUN_ME_FIRST.cmd\n\n");
process.stdout.write("  Manual terminal commands:\n");
process.stdout.write("    1. npm run doctor\n");
process.stdout.write("    2. npm install\n");
process.stdout.write("    3. npm run dev\n");
process.stdout.write("    4. Open http://localhost:3000\n\n");

process.stdout.write("Then open Claude Code or Codex CLI in this folder. It should read CLAUDE.md or AGENTS.md automatically.\n");
process.stdout.write("If it asks what to do, paste:\n\n");
process.stdout.write(prompt);
process.stdout.write("\n\n");

process.stdout.write("Important files:\n\n");
process.stdout.write("  - NEXT_STEPS.md       Friendly owner checklist\n");
process.stdout.write("  - PROJECT_BRIEF.md    Who / what / why\n");
process.stdout.write("  - LOCAL_BASELINE.md   Local infra, mock data, first-screen, and design plan\n");
process.stdout.write("  - SETUP_MODE.md       Local setup constraints\n");
process.stdout.write("  - docs/design-system.md  UI and component standards\n");
process.stdout.write("  - INFRA_HANDOFF.md    What infra needs if this becomes shared\n\n");

if (layer === "1") {
  process.stdout.write("Keep this local. Do not add shared hosting, SSO, or hosted databases unless you ask for Layer 2 promotion.\n");
}
