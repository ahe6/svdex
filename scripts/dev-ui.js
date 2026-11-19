import { spawn, spawnSync } from "node:child_process";
import { createHash } from "node:crypto";
import { existsSync, mkdirSync, readFileSync, readdirSync, rmSync, writeFileSync } from "node:fs";
import { dirname, join, relative, resolve } from "node:path";
import { createInterface } from "node:readline";
import { fileURLToPath } from "node:url";

const root = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const container = "miscdex-forum";
const stateDirectory = join(root, ".data/ui-dev");
const lockDirectory = join(stateDirectory, "lock");
const ownerFile = join(lockDirectory, "owner.json");
const stopFile = join(lockDirectory, "stop");
const definitions = {
  sidebar: ["frontend/discourse-sidebar", "/tmp/miscdex-sidebar"],
  interface: ["frontend/discourse-interface", "/tmp/miscdex-interface"],
  styles: ["frontend/discourse-appearance", "/tmp/miscdex-appearance"],
};

export function sourceGroup(path) {
  const normalized = path.replaceAll("\\", "/");
  if (/^frontend\/discourse-(interface|sidebar)\//.test(normalized) && /\.(?:gjs|js|hbs|scss|html|json|ya?ml|svg|png|jpg|webp|woff2?)$/.test(normalized)) {
    return normalized.startsWith("frontend/discourse-interface/") ? "interface" : "sidebar";
  }
  if (/^frontend\/discourse-appearance\/(?:styles\/[a-z0-9-]+\.scss|styles\.json)$/.test(normalized)) return "styles";
  return null;
}

export function changedGroups(before, after) {
  return [...new Set([...new Set([...Object.keys(before), ...Object.keys(after)])]
    .filter(path => before[path] !== after[path]).map(sourceGroup).filter(Boolean))].sort();
}

function fingerprint() {
  const result = {};
  function visit(directory) {
    for (const entry of readdirSync(directory, { withFileTypes: true })) {
      if (entry.name.startsWith(".") || entry.name === "node_modules") continue;
      const path = join(directory, entry.name);
      if (entry.isDirectory()) visit(path);
      else if (entry.isFile() && sourceGroup(relative(root, path))) {
        result[relative(root, path)] = createHash("sha256").update(readFileSync(path)).digest("hex");
      }
    }
  }
  for (const [directory] of Object.values(definitions)) visit(join(root, directory));
  return result;
}

function run(args) {
  const result = spawnSync(args[0], args.slice(1), { cwd: root, encoding: "utf8" });
  if (result.error || result.status !== 0) throw new Error(result.error?.message || result.stderr?.trim() || `${args[0]} failed`);
}

function processAlive(pid) {
  if (!Number.isInteger(pid) || pid < 1) return false;
  try { process.kill(pid, 0); return true; } catch { return false; }
}

function currentOwner() {
  try { return JSON.parse(readFileSync(ownerFile, "utf8")); } catch { return null; }
}

export async function main(args = process.argv.slice(2)) {
  if (args.some(arg => !["--stop", "--status", "--once", "--themes", "--styles", "--assert-stopped"].includes(arg))) throw new Error("Use npm run dev, npm run dev:stop, or npm run dev:status. This tool has no remote target option.");
  const owner = currentOwner();
  if (args.includes("--assert-stopped")) {
    if (owner && processAlive(owner.pid)) throw new Error("Stop the local UI watcher with npm run dev:stop before configuration imports or native checks.");
    return;
  }
  if (args.includes("--status")) {
    console.log(owner && processAlive(owner.pid) ? `Local UI watcher running (pid ${owner.pid}).` : "Local UI watcher is stopped.");
    return;
  }
  if (args.includes("--stop")) {
    if (owner && processAlive(owner.pid)) {
      writeFileSync(stopFile, "stop\n", { mode: 0o600 });
      console.log("Requested a graceful stop of this checkout’s local UI watcher.");
    } else console.log("Local UI watcher is stopped.");
    return;
  }
  if (owner && processAlive(owner.pid)) throw new Error("This checkout already has a UI watcher. Use npm run dev:stop before manual imports or native checks.");
  mkdirSync(stateDirectory, { recursive: true, mode: 0o700 });
  if (existsSync(lockDirectory) && owner && !processAlive(owner.pid)) rmSync(lockDirectory, { recursive: true });
  try { mkdirSync(lockDirectory, { mode: 0o700 }); } catch { throw new Error("Another watcher is starting or its lock is incomplete. Check npm run dev:status before removing .data/ui-dev/lock."); }
  writeFileSync(ownerFile, JSON.stringify({ pid: process.pid, started_at: new Date().toISOString() }), { mode: 0o600 });
  let child;
  let poll;
  let stopPoll;
  let stopped = false;
  let busy = false;
  let pending = {};
  let requestId = 0;
  function cleanup() {
    clearInterval(poll);
    clearInterval(stopPoll);
    if (currentOwner()?.pid === process.pid) rmSync(lockDirectory, { recursive: true, force: true });
  }
  function stop() {
    if (stopped) return;
    stopped = true;
    clearInterval(poll);
    child?.stdin.end(JSON.stringify({ command: "stop" }) + "\n");
    if (!child) cleanup();
  }
  process.once("SIGINT", stop);
  process.once("SIGTERM", stop);
  process.once("exit", cleanup);
  try {
    // The Ruby worker repeats this guard against actual Rails settings. Never
    // inherit a configurable deployment host, credentials, URL or API key.
    run(["docker", "exec", container, "bash", "-lc", 'test "$(printenv DISCOURSE_HOSTNAME)" = localhost && test "$(printenv DISCOURSE_PORT)" = 4080']);
    run(["docker", "cp", join(root, "scripts/dev-ui-import.rb"), `${container}:/tmp/svdex-ui-dev-import.rb`]);
    console.log("Starting local UI development at http://localhost:4080 (one backend startup)…");
    child = spawn("docker", ["exec", "-i", "-u", "discourse", container, "bash", "-lc", "cd /var/www/discourse && bundle exec rails runner --skip-executor /tmp/svdex-ui-dev-import.rb"], { cwd: root, stdio: ["pipe", "pipe", "inherit"] });
    child.stdin.on("error", error => { if (error.code !== "EPIPE") console.error(error.message); });
    child.on("error", error => { console.error(error.message); process.exitCode = 1; cleanup(); });
    const lines = createInterface({ input: child.stdout });
    let readyResolve, readyReject;
    const ready = new Promise((resolveReady, rejectReady) => { readyResolve = resolveReady; readyReject = rejectReady; });
    child.on("exit", code => {
      const expected = stopped;
      readyReject(new Error("Local UI worker stopped before it was ready."));
      for (const waiter of Object.values(pending)) waiter.reject(new Error("Local UI worker stopped."));
      pending = {};
      stopped = true;
      cleanup();
      if (!expected) {
        console.error("Local UI worker stopped. Restart npm run dev after checking Docker.");
        process.exitCode = code || 1;
      } else if (code && !process.exitCode) process.exitCode = code;
    });
    lines.on("line", line => {
      if (!line.startsWith("SVDEX_UI_JSON ")) return;
      const data = JSON.parse(line.slice("SVDEX_UI_JSON ".length));
      if (data.type === "ready") readyResolve();
      const waiter = pending[data.id];
      if (!waiter) return;
      delete pending[data.id];
      if (data.type === "error") waiter.reject(new Error(data.message));
      else waiter.resolve(data);
    });
    stopPoll = setInterval(() => { if (existsSync(stopFile)) stop(); }, 300);
    await ready;
    if (stopped) return;

    async function sync(groups) {
      const started = performance.now();
      if (groups.includes("styles")) run([process.execPath, "scripts/build-styles.js"]);
      for (const group of groups) {
        const [source, destination] = definitions[group];
        run(["docker", "exec", container, "rm", "-rf", destination]);
        run(["docker", "cp", join(root, source), `${container}:${destination}`]);
      }
      const id = ++requestId;
      const result = await new Promise((resolveResult, rejectResult) => {
        pending[id] = { resolve: resolveResult, reject: rejectResult };
        child.stdin.write(JSON.stringify({ id, groups }) + "\n");
      });
      console.log(`Updated ${groups.join(", ")} in ${((performance.now() - started) / 1000).toFixed(2)}s (native import ${result.seconds}s). Browser refresh requested.`);
    }
    let previous = fingerprint();
    const initial = args.includes("--themes") ? ["sidebar", "interface"] : args.includes("--styles") ? ["styles"] : ["sidebar", "interface", "styles"];
    try { await sync(initial); } catch (error) {
      if (args.includes("--once")) throw error;
      console.error(`Initial UI update failed: ${error.message}\nFix the source and save; the watcher remains running.`);
    }
    if (args.includes("--once")) { stop(); return; }
    console.log("Watching theme modules, templates and style sources. Save to preview. No tests, app rebuilds or fixture resets run on save.");
    poll = setInterval(async () => {
      if (busy || stopped) return;
      busy = true;
      try {
        const next = fingerprint();
        const groups = changedGroups(previous, next);
        if (groups.length) {
          // Set the baseline before importing, so edits during an import are
          // detected by the next pass. Content hashes handle atomic saves and
          // deletions, without platform-specific filesystem watcher behavior.
          previous = next;
          await sync(groups);
        }
      } catch (error) {
        console.error(`UI update failed: ${error.message}\nFix the source and save again; the watcher remains running.`);
      } finally { busy = false; }
    }, 500);
  } catch (error) {
    stop();
    throw error;
  }
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  main().catch(error => { console.error(error.message); process.exitCode = 1; });
}
