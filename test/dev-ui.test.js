import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import test from "node:test";
import { changedGroups, sourceGroup } from "../scripts/dev-ui.js";

test("UI watch scopes source changes, ignores generated CSS and never observes backend/private files", () => {
  assert.equal(sourceGroup("frontend/discourse-interface/javascripts/discourse/components/example.gjs"), "interface");
  assert.equal(sourceGroup("frontend/discourse-sidebar/common/header.html"), "sidebar");
  assert.equal(sourceGroup("frontend/discourse-appearance/styles/01-topic-and-search.scss"), "styles");
  assert.equal(sourceGroup("frontend/discourse-appearance/styles.json"), "styles");
  for (const path of ["frontend/discourse-appearance/common.scss", ".data/admin.json", "deploy/discourse/plugins/plugin.rb", "frontend/discourse-interface/README.md"]) assert.equal(sourceGroup(path), null);
});

test("UI watch notices removals and coalesces changes without regenerating unrelated components", () => {
  const file = "frontend/discourse-interface/javascripts/example.gjs";
  const style = "frontend/discourse-appearance/styles/01-topic-and-search.scss";
  assert.deepEqual(changedGroups({ [file]: "old" }, {}), ["interface"]);
  assert.deepEqual(changedGroups({ [file]: "same", [style]: "old" }, { [file]: "same", [style]: "new" }), ["styles"]);
  assert.deepEqual(changedGroups({ [file]: "same" }, { [file]: "same" }), []);
});

test("UI development refuses a remote target before touching Docker", () => {
  const result = spawnSync(process.execPath, ["scripts/dev-ui.js", "--site=https://svdex.com"], { encoding: "utf8" });
  assert.equal(result.status, 1);
  assert.match(result.stderr, /no remote target option/);
});

test("warm importer refuses a production hostname before accessing theme records", () => {
  const result = spawnSync("ruby", ["-e", 'GlobalSetting = Struct.new(:hostname).new("svdex.com"); SiteSetting = Struct.new(:port).new(4080); load "scripts/dev-ui-import.rb"'], { encoding: "utf8" });
  assert.equal(result.status, 1);
  assert.match(result.stderr, /only for localhost:4080/);
});

test("warm importer rejects unknown groups and request keys before invoking Rails", () => {
  const setup = 'GlobalSetting = Struct.new(:hostname).new("localhost"); SiteSetting = Struct.new(:port, :polling_interval, :anon_polling_interval, :background_polling_interval).new(4080, 3000, 25000, 60000); Theme = Object.new; def Theme.exists?(**args); true; end; load "scripts/dev-ui-import.rb"';
  const input = [{ id: 1, groups: ["production"] }, { id: 2, groups: ["styles"], code: "unsafe" }, { command: "stop" }].map(value => JSON.stringify(value)).join("\n") + "\n";
  const result = spawnSync("ruby", ["-e", setup + '; raise "Polling was not restored" unless SiteSetting.anon_polling_interval == 25000 && SiteSetting.background_polling_interval == 60000 && SiteSetting.polling_interval == 3000'], { encoding: "utf8", input });
  assert.equal(result.status, 0);
  const responses = result.stdout.trim().split("\n").map(line => JSON.parse(line.replace("SVDEX_UI_JSON ", "")));
  assert.equal(responses[0].type, "ready");
  assert.deepEqual(responses.slice(1).map(row => [row.id, row.type, row.message]), [[1, "error", "Invalid UI import request"], [2, "error", "Invalid UI import request"]]);
});
