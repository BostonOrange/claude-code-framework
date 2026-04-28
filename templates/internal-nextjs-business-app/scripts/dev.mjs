import { join } from "node:path";
import { fileURLToPath } from "node:url";
import { spawn } from "node:child_process";

const root = join(fileURLToPath(new URL(".", import.meta.url)), "..");

function commandName(name) {
  return process.platform === "win32" ? `${name}.cmd` : name;
}

function run(command, args) {
  return new Promise((resolve, reject) => {
    const child = spawn(commandName(command), args, {
      cwd: root,
      stdio: "inherit",
      shell: false,
    });
    child.on("exit", (code) => {
      if (code === 0) resolve();
      else reject(new Error(`${command} ${args.join(" ")} exited with ${code}`));
    });
  });
}

function packageManager() {
  const execPath = process.env.npm_execpath ?? "";
  if (execPath.includes("pnpm")) return "pnpm";
  if (execPath.includes("yarn")) return "yarn";
  return "npm";
}

async function setup() {
  const pm = packageManager();
  if (pm === "pnpm") return run("pnpm", ["run", "setup"]);
  if (pm === "yarn") return run("yarn", ["setup"]);
  return run("npm", ["run", "setup"]);
}

async function startNext() {
  const port = process.env.PORT ?? "3000";
  const pm = packageManager();
  const args = pm === "pnpm" ? ["exec", "next", "dev", "-p", port] : pm === "yarn" ? ["next", "dev", "-p", port] : ["next", "dev", "-p", port];
  return run(pm === "pnpm" ? "pnpm" : pm === "yarn" ? "yarn" : "npx", args);
}

setup()
  .then(startNext)
  .catch((error) => {
    console.error(error.message);
    process.exit(1);
  });
