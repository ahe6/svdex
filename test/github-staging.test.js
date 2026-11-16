import test from "node:test";
import assert from "node:assert/strict";
import { mkdtempSync, readFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { spawnSync } from "node:child_process";

test("staging packages are distinct, credential-free and retain the exact source tree", () => {
  const temp = mkdtempSync(join(tmpdir(), "svdex-staging-"));
  try {
    const result = spawnSync("ruby", ["scripts/prepare-discourse-production.rb", "--staging", join(temp, "release")], { encoding: "utf8" });
    assert.equal(result.status, 0, result.stderr);
    const manifest = JSON.parse(readFileSync(join(temp, "release/manifest.json")));
    assert.equal(manifest.hostname, "staging.svdex.com");
    assert.equal(manifest.release_kind, "staging");
    assert.equal(manifest.source_tree, spawnSync("git", ["rev-parse", "HEAD^{tree}"], {encoding:"utf8"}).stdout.trim());
    assert.doesNotMatch(readFileSync(join(temp, "release/app.yml"), "utf8"), /SMTP|PASSWORD|DEVELOPER_EMAILS/);
    assert.ok(readFileSync(join(temp, "release/staging-plugin.b64"), "utf8").length > 100);
  } finally { rmSync(temp, {recursive:true, force:true}); }
});

test("production refuses absent, failed, wrong-host and mismatched staging proof", () => {
  const result = spawnSync("python3", ["-c", `
import runpy
verify=runpy.run_path('scripts/verify-staging.py')['verify']
tree='a'*40
good=dict(hostname='staging.svdex.com',status='success',phase='complete',source_tree=tree)
verify(good,tree)
for bad in [{},dict(good,status='failed'),dict(good,hostname='svdex.com'),dict(good,source_tree='b'*40)]:
    try: verify(bad,tree)
    except ValueError: pass
    else: raise RuntimeError('Unsafe production promotion accepted')
`], {encoding:"utf8"});
  assert.equal(result.status, 0, result.stderr);
});

test("staging infrastructure has no production storage, credentials or administration permissions", () => {
  const template = JSON.parse(readFileSync("deploy/discourse/aws/staging-host.json"));
  const hostPolicies = template.Resources.HostRole.Properties.Policies;
  const deployPolicies = template.Resources.StageDeployRole.Properties.Policies;
  // SSM's managed agent policy otherwise permits reading unrelated parameters.
  const deny = hostPolicies[0].PolicyDocument.Statement.find(rule => rule.Effect === "Deny");
  assert.deepEqual(deny.Action, ["ssm:GetParameter", "ssm:GetParameters", "ssm:GetParametersByPath"]);
  assert.ok(JSON.stringify(deny.NotResource).endsWith('/svdex/staging/admin-password"}'));
  const policies = JSON.stringify([hostPolicies, deployPolicies]);
  assert.doesNotMatch(policies, /svdex-discourse|AdministratorAccess|s3:\*|ssm:\*/);
  assert.ok(policies.includes("/svdex/staging/admin-password"));
  assert.ok(JSON.stringify(template.Resources.BackupBucket.Properties.BucketName).includes("svdex-staging-"));
  const hostScript = readFileSync("deploy/discourse/aws/deploy-staging-release.sh", "utf8");
  assert.match(hostScript, /DISCOURSE_DISABLE_EMAILS':'yes'/);
  assert.match(hostScript, /DISCOURSE_LOGIN_REQUIRED':True/);
  assert.match(hostScript, /DISCOURSE_ALLOW_NEW_REGISTRATIONS':False/);
  assert.doesNotMatch(hostScript, /SMTP_PASSWORD|OAUTH2_CLIENT_SECRET/);
});

test("staging entry point rejects injected parameters before touching host configuration", () => {
  const result = spawnSync("bash", ["deploy/discourse/aws/deploy-staging-release.sh", "a".repeat(40), "b".repeat(64), "1-1;id"], {encoding:"utf8"});
  assert.equal(result.status, 2);
  assert.doesNotMatch(result.stderr, /staging-host|svdex-aws.env/);
});
