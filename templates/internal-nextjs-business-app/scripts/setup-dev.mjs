import { createHash, randomBytes } from "node:crypto";
import { existsSync, readFileSync, writeFileSync } from "node:fs";
import net from "node:net";
import { basename, join } from "node:path";
import { fileURLToPath } from "node:url";
import { spawn } from "node:child_process";

const root = join(fileURLToPath(new URL(".", import.meta.url)), "..");
const noDocker = process.argv.includes("--no-docker");
const noSeed = process.argv.includes("--no-seed");

function log(message) {
  process.stdout.write(`${message}\n`);
}

function commandName(name) {
  return process.platform === "win32" ? `${name}.cmd` : name;
}

function run(command, args, options = {}) {
  return new Promise((resolve, reject) => {
    const child = spawn(commandName(command), args, {
      cwd: root,
      stdio: "inherit",
      shell: false,
      ...options,
    });

    child.on("exit", (code) => {
      if (code === 0) resolve();
      else reject(new Error(`${command} ${args.join(" ")} exited with ${code}`));
    });
  });
}

function runQuiet(command, args) {
  return new Promise((resolve) => {
    const child = spawn(commandName(command), args, {
      cwd: root,
      stdio: "ignore",
      shell: false,
    });
    child.on("exit", (code) => resolve(code === 0));
    child.on("error", () => resolve(false));
  });
}

async function ensureCommand(command, installHint) {
  const ok = await runQuiet(command, ["--version"]);
  if (!ok) {
    throw new Error(`${command} is required. ${installHint}`);
  }
}

function ensureEnvFile() {
  const envPath = join(root, ".env.local");
  if (existsSync(envPath)) return;

  const example = readFileSync(join(root, ".env.example"), "utf8");
  const secret = randomBytes(48).toString("base64url");
  const env = example.replace(
    "SESSION_SECRET=replace-by-running-npm-run-setup",
    `SESSION_SECRET=${secret}`,
  );
  writeFileSync(envPath, env);
  log("Created .env.local with a generated SESSION_SECRET.");
}

function loadEnvFile() {
  const envPath = join(root, ".env.local");
  if (!existsSync(envPath)) return;

  const content = readFileSync(envPath, "utf8");
  for (const line of content.split(/\r?\n/)) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith("#")) continue;

    const equals = trimmed.indexOf("=");
    if (equals === -1) continue;

    const key = trimmed.slice(0, equals).trim();
    const value = trimmed.slice(equals + 1).trim().replace(/^["']|["']$/g, "");
    if (key && !process.env[key]) process.env[key] = value;
  }
}

function waitForPort(port, host = "127.0.0.1", timeoutMs = 30_000) {
  const start = Date.now();
  return new Promise((resolve, reject) => {
    function attempt() {
      const socket = net.createConnection({ host, port });
      socket.once("connect", () => {
        socket.end();
        resolve();
      });
      socket.once("error", () => {
        socket.destroy();
        if (Date.now() - start > timeoutMs) {
          reject(new Error(`Timed out waiting for ${host}:${port}`));
        } else {
          setTimeout(attempt, 500);
        }
      });
    }
    attempt();
  });
}

function databasePort() {
  const url = process.env.DATABASE_URL;
  if (!url) return 55432;

  try {
    const parsed = new URL(url);
    return Number(parsed.port || 5432);
  } catch {
    return 55432;
  }
}

function packageManager() {
  const execPath = process.env.npm_execpath ? basename(process.env.npm_execpath) : "";
  if (execPath.includes("pnpm")) return "pnpm";
  if (execPath.includes("yarn")) return "yarn";
  return "npm";
}

async function execPackageBin(bin, args) {
  const pm = packageManager();
  if (pm === "pnpm") return run("pnpm", ["exec", bin, ...args]);
  if (pm === "yarn") return run("yarn", [bin, ...args]);
  return run("npx", [bin, ...args]);
}

function envFingerprint() {
  const envPath = join(root, ".env.local");
  const content = existsSync(envPath) ? readFileSync(envPath, "utf8") : "";
  return createHash("sha256").update(content).digest("hex").slice(0, 8);
}

async function main() {
  ensureEnvFile();
  loadEnvFile();
  log(`Using local env ${envFingerprint()}.`);

  if (!noDocker) {
    await ensureCommand("docker", "Install Docker Desktop or rerun with --no-docker.");
    log("Starting Postgres and Azurite.");
    await run("docker", ["compose", "up", "-d", "postgres", "azurite"]);
    await waitForPort(databasePort());
    await waitForPort(10000);
  }

  log("Generating Prisma client.");
  await execPackageBin("prisma", ["generate"]);

  log("Syncing database schema.");
  await execPackageBin("prisma", ["db", "push"]);

  if (!noSeed) {
    log("Seeding demo data.");
    await execPackageBin("tsx", ["prisma/seed.ts"]);
  }

  log("Local stack is ready.");
}

main().catch((error) => {
  console.error(error.message);
  process.exit(1);
});
