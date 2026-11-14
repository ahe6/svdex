import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { spawnSync } from "node:child_process";
import test from "node:test";

test("fresh development builds use the reviewed engine and Docker pins with loopback-only access", () => {
  const result = spawnSync("ruby", ["-ryaml", "-rjson", "-e", "puts YAML.load_file(ARGV.fetch(0)).to_json", "deploy/discourse/local.yml"], { encoding: "utf8" });
  assert.equal(result.status, 0, result.stderr);
  const local = JSON.parse(result.stdout);
  const production = JSON.parse(readFileSync("deploy/discourse/production.json.example", "utf8"));
  const contracts = JSON.parse(readFileSync("deploy/discourse/upstream-contracts.json", "utf8"));
  assert.match(local.params.version, /^[a-f0-9]{40}$/);
  assert.equal(local.params.version, production.discourse_revision);
  assert.equal(local.params.version, contracts.discourse_revision);
  const script = readFileSync("scripts/discourse-local.sh", "utf8");
  assert.equal(script.match(/^upstream_ref=([a-f0-9]{40})$/m)?.[1], production.docker_revision);
  assert.deepEqual(local.expose, ["127.0.0.1:4080:80"]);
  assert.ok(script.includes("127.0.0.1:4081:8025"));
  assert.equal(local.env.DISCOURSE_SMTP_ADDRESS, "miscdex-discourse-mail");
});
