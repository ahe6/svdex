// Package reviewed source only. Production configuration and deployment are
// deliberately a different, maintainer-only workflow.
import { execFileSync } from "node:child_process";
import { createHash } from "node:crypto";
import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const root = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const git = (...args) => execFileSync("git", args, { cwd: root, encoding: "utf8" }).trim();
if (process.argv.length !== 3) throw new Error("Usage: node scripts/package-source.js OUTPUT.tar.gz");
if (git("status", "--porcelain")) throw new Error("Commit or set aside all source changes before packaging");
const output = resolve(process.argv[2]);
if (!output.endsWith(".tar.gz")) throw new Error("Expected a .tar.gz output path");
const commit = git("rev-parse", "HEAD");
mkdirSync(dirname(output), { recursive: true });
git("archive", "--format=tar.gz", "--prefix=svdex/", `--output=${output}`, commit);
const sha256 = createHash("sha256").update(readFileSync(output)).digest("hex");
writeFileSync(`${output}.json`, JSON.stringify({ source_commit: commit, sha256, contents: "tracked source only; not a configured production release" }, null, 2) + "\n");
console.log(`Packaged source revision ${commit}`);
