import assert from "node:assert/strict";
import { chmodSync, copyFileSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { spawnSync } from "node:child_process";
import test from "node:test";

function isolatedScript(directory) {
  // These tests stub Docker; they must not inherit a real checkout's active
  // UI watcher or process lock when source checks run during development.
  mkdirSync(join(directory, "scripts"));
  writeFileSync(join(directory, "package.json"), '{"type":"module"}\n');
  for (const name of ["check-discourse-local.sh", "dev-ui.js"]) copyFileSync(`scripts/${name}`, join(directory, "scripts", name));
  return join(directory, "scripts/check-discourse-local.sh");
}

test("native check selection rejects unknown paths before touching Docker", () => {
  const directory = mkdtempSync(join(tmpdir(), "svdex-native-selection-"));
  try {
    const script = isolatedScript(directory);
    const calls = join(directory, "calls");
    const docker = join(directory, "docker");
    writeFileSync(docker, '#!/bin/sh\nprintf "%s\\n" "$*" >> "$DOCKER_CALLS"\n');
    chmodSync(docker, 0o755);
    const env = { ...process.env, PATH: `${directory}:${process.env.PATH}`, DOCKER_CALLS: calls };
    const run = args => spawnSync("bash", [script, ...args], { encoding: "utf8", env });
    const listing = run(["--list"]);
    assert.equal(listing.status, 0, listing.stderr);
    assert.ok(listing.stdout.split("\n").includes("offering-bids"));
    for (const value of ["../private-script", "--unknown", "offering-bids;id"]) {
      const result = run([value]);
      assert.equal(result.status, 2);
      assert.match(result.stderr, /Unknown native check/);
    }
    assert.throws(() => readFileSync(calls), { code: "ENOENT" });
    const focused = run(["offering-bids", "people-facts"]);
    assert.equal(focused.status, 0, focused.stderr);
    const focusedCalls = readFileSync(calls, "utf8");
    assert.match(focusedCalls, /runner --skip-executor \/tmp\/verify-offering-bids-local.rb/);
    assert.match(focusedCalls, /runner --skip-executor \/tmp\/verify-people-facts-local.rb/);
    assert.doesNotMatch(focusedCalls, /runner --skip-executor \/tmp\/verify-private-offerings-local.rb/);
    writeFileSync(calls, "");
    const full = run([]);
    assert.equal(full.status, 0, full.stderr);
    const total = listing.stdout.trim().split("\n").length;
    assert.equal((readFileSync(calls, "utf8").match(/runner --skip-executor/g) || []).length, total);
    assert.ok(total > 30);
  } finally {
    rmSync(directory, { recursive: true, force: true });
  }
});

test("focused checks retain the local-host guard before copying or executing checks", () => {
  const directory = mkdtempSync(join(tmpdir(), "svdex-native-guard-"));
  try {
    const script = isolatedScript(directory);
    const docker = join(directory, "docker");
    const calls = join(directory, "calls");
    writeFileSync(docker, '#!/bin/sh\nprintf "%s\\n" "$*" >> "$DOCKER_CALLS"\nexit 1\n');
    chmodSync(docker, 0o755);
    const result = spawnSync("bash", [script, "offering-bids"], {
      encoding: "utf8", env: { ...process.env, PATH: `${directory}:${process.env.PATH}`, DOCKER_CALLS: calls },
    });
    assert.notEqual(result.status, 0);
    const recorded = readFileSync(calls, "utf8").trim().split("\n");
    assert.equal(recorded.length, 1);
    assert.match(recorded[0], /DISCOURSE_HOSTNAME.*localhost.*DISCOURSE_PORT.*4080/);
  } finally {
    rmSync(directory, { recursive: true, force: true });
  }
});

test("native checks refuse an active UI watcher but read-only selection stays available", () => {
  const directory = mkdtempSync(join(tmpdir(), "svdex-native-ui-lock-"));
  try {
    const script = isolatedScript(directory);
    mkdirSync(join(directory, ".data/ui-dev/lock"), { recursive: true });
    writeFileSync(join(directory, ".data/ui-dev/lock/owner.json"), JSON.stringify({ pid: process.pid }));
    const list = spawnSync("bash", [script, "--list"], { encoding: "utf8" });
    assert.equal(list.status, 0);
    const run = spawnSync("bash", [script, "offering-bids"], { encoding: "utf8" });
    assert.equal(run.status, 1);
    assert.match(run.stderr, /Stop the local UI watcher/);
    assert.doesNotMatch(run.stderr, /Cannot connect to the Docker/);
  } finally { rmSync(directory, { recursive: true, force: true }); }
});
