import { spawnSync } from "node:child_process";

// Read-only: do not install tools, inspect credentials, or start containers.
let failed = false;
function report(ok, name, detail) {
  console.log(`${ok ? "OK" : "MISSING"} ${name}: ${detail}`);
  if (!ok) failed = true;
}
report(Number(process.versions.node.split(".")[0]) >= 24, "Node.js", `${process.versions.node} (24 or later required)`);
for (const [name, command, args, hint] of [
  ["Git", "git", ["--version"], "Install Git."],
  ["Ruby", "ruby", ["--version"], "Install Ruby for source/configuration checks."],
  ["Python", "python3", ["--version"], "Install Python 3 for local tooling."],
  ["Bash", "bash", ["--version"], "Install Bash for the local Docker commands."],
  ["Docker client", "docker", ["--version"], "Install Docker Desktop or Docker Engine."],
  ["Docker engine", "docker", ["info", "--format", "{{.ServerVersion}}"], "Start Docker Desktop/Engine and check that your account can access it."],
]) {
  const result = spawnSync(command, args, { encoding: "utf8", timeout: 15_000 });
  report(!result.error && result.status === 0, name,
    !result.error && result.status === 0 ? (result.stdout || result.stderr).trim().split("\n")[0] : hint);
}
console.log("\nLocal ports: 4080 (forum), 4081 (captured mail). Use an isolated Docker host per checkout.");
console.log(failed ? "Resolve the missing prerequisites, then rerun npm run doctor." : "Ready. Run npm ci, then npm run setup for the first installation.");
process.exitCode = failed ? 1 : 0;
