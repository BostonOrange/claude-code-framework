import { existsSync } from "node:fs";
import { join } from "node:path";
import { fileURLToPath } from "node:url";
import { spawnSync } from "node:child_process";

const root = join(fileURLToPath(new URL(".", import.meta.url)), "..");

const checks = [
  ["node", ["--version"], "Node.js 22+ is recommended."],
  ["docker", ["--version"], "Docker Desktop is required for the one-command local stack."],
];

let failed = false;

for (const [command, args, hint] of checks) {
  const result = spawnSync(command, args, { cwd: root, encoding: "utf8" });
  if (result.status === 0) {
    process.stdout.write(`ok ${command}: ${result.stdout.trim()}\n`);
  } else {
    failed = true;
    process.stdout.write(`missing ${command}: ${hint}\n`);
  }
}

for (const file of [".env.local", "docker-compose.yml", "prisma/schema.prisma"]) {
  const path = join(root, file);
  process.stdout.write(`${existsSync(path) ? "ok" : "missing"} ${file}\n`);
}

if (failed) process.exit(1);
