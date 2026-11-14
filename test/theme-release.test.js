import assert from "node:assert/strict";
import { mkdtempSync, mkdirSync, writeFileSync, readFileSync, existsSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { spawnSync } from "node:child_process";
import test from "node:test";

test("theme upgrade removes retired modules, keeps source rollback and leaves site data alone", () => {
  const root = mkdtempSync(join(tmpdir(), "svdex-theme-release-"));
  try {
    const release = join(root, "release"), shared = join(root, "shared");
    mkdirSync(release); mkdirSync(shared);
    writeFileSync(join(shared, "site-record"), "keep this");
    for (const name of ["sidebar", "interface"]) {
      const source = join(root, name), target = join(shared, name);
      mkdirSync(source); mkdirSync(target);
      writeFileSync(join(source, "about.json"), JSON.stringify({ name }));
      writeFileSync(join(source, "current.gjs"), "new implementation");
      writeFileSync(join(target, "retired.gjs"), "old implementation");
      assert.equal(spawnSync("tar", ["-czf", join(release, `svdex-${name}.tar.gz`), "-C", source, "."]).status, 0);
    }
    const result = spawnSync("bash", ["deploy/discourse/aws/replace-theme-sources.sh", release, shared], { encoding: "utf8" });
    assert.equal(result.status, 0, result.stderr);
    for (const name of ["sidebar", "interface"]) {
      assert.equal(existsSync(join(shared, name, "retired.gjs")), false);
      assert.equal(readFileSync(join(shared, name, "current.gjs"), "utf8"), "new implementation");
      assert.equal(readFileSync(join(release, `previous-${name}-sources`, "retired.gjs"), "utf8"), "old implementation");
    }
    assert.equal(readFileSync(join(shared, "site-record"), "utf8"), "keep this");
  } finally { rmSync(root, { recursive: true, force: true }); }
});
