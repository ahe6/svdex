import assert from "node:assert/strict";
import { mkdtempSync, writeFileSync, readFileSync, mkdirSync, statSync, rmSync, existsSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { spawnSync } from "node:child_process";
import { createHash } from "node:crypto";
import test from "node:test";

test("production package preserves plugin bytes, TLS and closed access without exposing mail credentials", () => {
  const temp = mkdtempSync(join(tmpdir(), "svdex-package-"));
  try {
    const input = join(temp, "config.json");
    const output = join(temp, "release");
    const config = JSON.parse(readFileSync("deploy/discourse/production.json.example", "utf8"));
    Object.assign(config, {
      admin_email: "owner@svdex.test", notification_email: "notifications@svdex.test",
      smtp_address: "smtp.svdex.test", smtp_user_name: "sender", smtp_password: "private'#$value\"",
    });
    writeFileSync(input, JSON.stringify(config), { mode: 0o600 });
    const result = spawnSync("ruby", ["scripts/prepare-discourse-production.rb", input, output], { encoding: "utf8" });
    assert.equal(result.status, 0, result.stderr);
    assert.ok(!(result.stdout + result.stderr).includes(config.smtp_password));
    assert.equal(statSync(output).mode & 0o777, 0o700);
    assert.equal(statSync(join(output, "app.yml")).mode & 0o777, 0o600);
    const parsed = spawnSync("ruby", ["-ryaml", "-rjson", "-e", "puts YAML.load_file(ARGV.fetch(0)).to_json", join(output, "app.yml")], { encoding: "utf8" });
    assert.equal(parsed.status, 0, parsed.stderr);
    const app = JSON.parse(parsed.stdout);
    assert.equal(app.env.DISCOURSE_SMTP_PASSWORD, config.smtp_password);
    assert.equal(app.env.DISCOURSE_FORCE_HTTPS, true);
    assert.equal(app.env.DISCOURSE_SMTP_OPENSSL_VERIFY_MODE, "peer");
    assert.equal(app.env.DISCOURSE_ALLOW_NEW_REGISTRATIONS, false);
    assert.equal(app.env.DISCOURSE_LOGIN_REQUIRED, true);
    assert.ok(app.templates.includes("templates/web.letsencrypt.ssl.template.yml"));
    assert.ok(!JSON.stringify(app).includes("legacy/marketplace"));
    assert.equal(readFileSync(join(output, "configure-production.rb"), "utf8"), readFileSync("deploy/discourse/configure-production.rb", "utf8"));
    const archive = join(temp, "plugin.tar.gz");
    writeFileSync(archive, Buffer.from(app.hooks.after_code[0].file.contents, "base64"));
    const recovered = join(temp, "recovered");
    mkdirSync(recovered);
    assert.equal(spawnSync("tar", ["-xzf", archive, "-C", recovered]).status, 0);
    const manifest = JSON.parse(readFileSync(join(output, "manifest.json"), "utf8"));
    const sidebar = join(temp, "sidebar");
    mkdirSync(sidebar);
    assert.equal(spawnSync("tar", ["-xzf", join(output, "svdex-sidebar.tar.gz"), "-C", sidebar]).status, 0);
    const ui = join(temp, "interface");
    mkdirSync(ui);
    assert.equal(spawnSync("tar", ["-xzf", join(output, "svdex-interface.tar.gz"), "-C", ui]).status, 0);
    const mappings = [
      ["deploy/discourse/plugins/", recovered],
      ["frontend/discourse-sidebar/", sidebar],
      ["frontend/discourse-interface/", ui],
      ["frontend/discourse-appearance/", join(output, "appearance")],
      ["assets/brand/", join(output, "brand")],
      ["deploy/discourse/aws/", join(output, "aws")],
      ["deploy/discourse/", output],
    ];
    for (const [path, hash] of Object.entries(manifest.files)) {
      const [prefix, directory] = mappings.find(([prefix]) => path.startsWith(prefix));
      const bytes = readFileSync(join(directory, path.slice(prefix.length)));
      assert.equal(createHash("sha256").update(bytes).digest("hex"), hash, path);
    }
    config.discourse_revision = "latest";
    writeFileSync(input, JSON.stringify(config));
    const rejected = spawnSync("ruby", ["scripts/prepare-discourse-production.rb", input, join(temp, "rejected")], { encoding: "utf8" });
    assert.notEqual(rejected.status, 0);
    assert.equal(existsSync(join(temp, "rejected")), false);
  } finally {
    rmSync(temp, { recursive: true, force: true });
  }
});
