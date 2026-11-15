import test from "node:test";
import assert from "node:assert/strict";
import { mkdtempSync, mkdirSync, writeFileSync, copyFileSync, readFileSync, rmSync, existsSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { spawnSync } from "node:child_process";

test("source archives include only committed files, exclude ignored secrets and reject dirty sources", () => {
  const temp = mkdtempSync(join(tmpdir(), "svdex-source-"));
  try {
    const repo = join(temp, "repo");
    mkdirSync(join(repo, "scripts"), { recursive: true });
    copyFileSync(resolve("scripts/package-source.js"), join(repo, "scripts/package-source.js"));
    writeFileSync(join(repo, "package.json"), '{"type":"module"}');
    writeFileSync(join(repo, "README.md"), "Public source\n");
    writeFileSync(join(repo, ".gitignore"), ".data/\n.env\n");
    const git = (...args) => {
      const r = spawnSync("git", args, { cwd: repo, encoding: "utf8" });
      assert.equal(r.status, 0, r.stderr);
      return r.stdout.trim();
    };
    git("init", "-q");
    git("add", ".");
    git("-c", "user.name=Source Check", "-c", "user.email=source@example.invalid", "-c", "commit.gpgsign=false", "commit", "-qm", "Source");
    mkdirSync(join(repo, ".data"));
    writeFileSync(join(repo, ".data/private-config.json"), "private material");
    writeFileSync(join(repo, ".env"), "private material");
    const output = join(temp, "source.tar.gz");
    const run = path => spawnSync(process.execPath, ["scripts/package-source.js", path], { cwd: repo, encoding: "utf8" });
    assert.equal(run(output).status, 0);
    const entries = spawnSync("tar", ["-tzf", output], { encoding: "utf8" }).stdout;
    assert.match(entries, /svdex\/README.md/);
    assert.doesNotMatch(entries, /\.data|\.env|\.git\//);
    const metadata = JSON.parse(readFileSync(`${output}.json`));
    assert.equal(metadata.source_commit, git("rev-parse", "HEAD"));
    assert.match(metadata.sha256, /^[0-9a-f]{64}$/);
    for (const file of ["README.md", "untracked.txt"]) {
      writeFileSync(join(repo, file), "Uncommitted change");
      const rejected = join(temp, `${file}.tar.gz`);
      assert.notEqual(run(rejected).status, 0);
      assert.equal(existsSync(rejected), false);
      git("checkout", "--", "README.md");
    }
  } finally {
    rmSync(temp, { recursive: true, force: true });
  }
});
