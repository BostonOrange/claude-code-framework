import { existsSync } from "node:fs";
import { readFileSync } from "node:fs";
import net from "node:net";
import { join } from "node:path";
import { fileURLToPath } from "node:url";
import { spawnSync } from "node:child_process";

const root = join(fileURLToPath(new URL(".", import.meta.url)), "..");
const localPersistenceKinds = new Set([
  "memory",
  "folder",
  "sqlite",
  "local-postgres",
  "full-stack",
  "review-required",
]);

const installHints = {
  node: [
    "Install Node.js 22 LTS or newer.",
    "macOS: brew install node",
    "Windows: install from https://nodejs.org/",
  ],
  npm: [
    "npm ships with Node.js. Reinstall Node.js if npm is missing.",
  ],
  git: [
    "Install Git.",
    "macOS: brew install git",
    "Windows: install Git for Windows from https://git-scm.com/download/win",
  ],
  docker: [
    "Install and start Docker Desktop.",
    "macOS/Windows: https://www.docker.com/products/docker-desktop/",
  ],
  claude: [
    "Install Claude Code and sign in before asking it to build the tool.",
    "Use your internal install instructions if your company manages Claude Code centrally.",
  ],
  codex: [
    "Install Codex CLI and sign in before asking it to build the tool.",
    "Use your internal install instructions if your company manages Codex centrally.",
  ],
};

let failures = 0;
let warnings = 0;

function output(result, label, detail) {
  process.stdout.write(`${result.padEnd(7)} ${label}${detail ? ` - ${detail}` : ""}\n`);
}

function hint(lines) {
  for (const line of lines) process.stdout.write(`        ${line}\n`);
}

function run(command, args) {
  return spawnSync(command, args, {
    cwd: root,
    encoding: "utf8",
  });
}

function commandOutput(result) {
  return `${result.stdout ?? ""}${result.stderr ?? ""}`.trim().split(/\r?\n/)[0] ?? "";
}

function checkCommand(command, args, { label = command, required = true, hintKey = command, validate } = {}) {
  const result = run(command, args);
  if (result.status !== 0) {
    if (required) {
      failures += 1;
      output("missing", label, "required");
    } else {
      warnings += 1;
      output("warn", label, "optional but recommended");
    }
    hint(installHints[hintKey] ?? []);
    return false;
  }

  const firstLine = commandOutput(result);
  const validation = validate?.(firstLine);
  if (validation?.ok === false) {
    failures += 1;
    output("fail", label, validation.message);
    hint(installHints[hintKey] ?? []);
    return false;
  }

  output("ok", label, firstLine);
  return true;
}

function parseMajor(versionLine) {
  const match = versionLine.match(/v?(\d+)\./);
  return match ? Number(match[1]) : Number.NaN;
}

function checkDockerDaemon() {
  const result = run("docker", ["info"]);
  if (result.status === 0) {
    output("ok", "docker daemon", "running");
    return;
  }

  failures += 1;
  output("fail", "docker daemon", "Docker is installed but not running");
  hint(["Start Docker Desktop, then run npm run doctor again."]);
}

function localPersistenceKind() {
  if (localPersistenceKinds.has(process.env.APP_LOCAL_PERSISTENCE)) {
    return process.env.APP_LOCAL_PERSISTENCE;
  }

  const blueprintPath = join(root, "PROJECT_BLUEPRINT.json");
  if (!existsSync(blueprintPath)) return "full-stack";

  try {
    const parsed = JSON.parse(readFileSync(blueprintPath, "utf8"));
    const kind = parsed?.localPersistenceKind;
    return localPersistenceKinds.has(kind) ? kind : "full-stack";
  } catch {
    return "full-stack";
  }
}

function needsLocalDatabase(kind) {
  return kind === "local-postgres" || kind === "full-stack";
}

function needsBlobStorage(kind) {
  return kind === "full-stack";
}

function checkFile(path, detail) {
  const present = existsSync(join(root, path));
  output(present ? "ok" : "note", path, present ? detail : "will be created or checked later");
}

function checkPortAvailable(port, label) {
  return new Promise((resolve) => {
    const server = net.createServer();

    server.once("error", () => {
      warnings += 1;
      output("warn", label, `port ${port} is already in use`);
      process.stdout.write("        If npm run dev fails, stop the process using this port and retry.\n");
      resolve();
    });

    server.once("listening", () => {
      server.close(() => {
        output("ok", label, `port ${port} is available`);
        resolve();
      });
    });

    server.listen(port, "127.0.0.1");
  });
}

async function main() {
  process.stdout.write("Prerequisite check for the internal app template\n\n");
  const persistenceKind = localPersistenceKind();
  const databaseRequired = needsLocalDatabase(persistenceKind);
  const blobRequired = needsBlobStorage(persistenceKind);
  output("info", "setup mode", persistenceKind);
  process.stdout.write("\n");

  const nodeOk = checkCommand("node", ["--version"], {
    validate: (line) => {
      const major = parseMajor(line);
      return Number.isFinite(major) && major >= 22
        ? { ok: true }
        : { ok: false, message: `found ${line}; Node.js 22+ is required` };
    },
  });

  checkCommand("npm", ["--version"]);
  checkCommand("git", ["--version"]);
  const dockerOk = databaseRequired || blobRequired
    ? checkCommand("docker", ["--version"])
    : checkCommand("docker", ["--version"], { required: false });
  if (databaseRequired || blobRequired) {
    checkCommand("docker", ["compose", "version"], { label: "docker compose", hintKey: "docker" });
  } else {
    checkCommand("docker", ["compose", "version"], {
      label: "docker compose",
      required: false,
      hintKey: "docker",
    });
  }
  process.stdout.write("\nLocal AI coding tool\n");
  const claudeOk = checkCommand("claude", ["--version"], { required: false });
  const codexOk = checkCommand("codex", ["--version"], { required: false });
  if (!claudeOk && !codexOk) {
    warnings += 1;
    output("warn", "Claude Code or Codex CLI", "install at least one before building");
    process.stdout.write("        The downloaded folder does not include an AI subscription or API key.\n");
  }

  if (dockerOk && (databaseRequired || blobRequired)) checkDockerDaemon();

  process.stdout.write("\nProject files\n");
  checkFile("package.json", "present");
  checkFile("docker-compose.yml", databaseRequired || blobRequired ? "present" : "present but not required for this setup mode");
  checkFile("prisma/schema.prisma", databaseRequired ? "present" : "present but not required for this setup mode");
  checkFile(".env.local", "created by npm run setup if missing");

  process.stdout.write("\nLocal ports\n");
  await checkPortAvailable(3000, "Next.js");
  if (databaseRequired) await checkPortAvailable(55432, "Postgres");
  else output("skip", "Postgres", "not required for this setup mode");
  if (blobRequired) await checkPortAvailable(10000, "Azurite");
  else output("skip", "Azurite", "not required for this setup mode");

  process.stdout.write("\nNext commands\n");
  if (failures === 0) {
    process.stdout.write("        npm install\n");
    process.stdout.write("        npm run dev\n");
  } else if (!nodeOk) {
    process.stdout.write("        Install the missing required tools first, then rerun npm run doctor.\n");
  } else {
    process.stdout.write("        Fix the failed required checks, then rerun npm run doctor.\n");
  }

  process.stdout.write(`\nSummary: ${failures} failed, ${warnings} warning(s)\n`);
  if (failures > 0) process.exit(1);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
