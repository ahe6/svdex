import test from "node:test";
import assert from "node:assert/strict";
import { mkdtempSync, mkdirSync, writeFileSync, readFileSync, chmodSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { spawnSync } from "node:child_process";

const yaml = path => {
  const result = spawnSync("ruby", ["-ryaml", "-rjson", "-e", "puts JSON.generate(YAML.load_file(ARGV[0]))", path], { encoding: "utf8" });
  assert.equal(result.status, 0, result.stderr);
  return JSON.parse(result.stdout);
};

test("code-only upgrades contain no installation credentials or environment resets", () => {
  const temp = mkdtempSync(join(tmpdir(), "svdex-upgrade-"));
  try {
    const output = join(temp, "release");
    const result = spawnSync("ruby", ["scripts/prepare-discourse-production.rb", "--upgrade", output], { encoding: "utf8" });
    assert.equal(result.status, 0, result.stderr);
    const app = yaml(join(output, "app.yml"));
    assert.deepEqual(Object.keys(app).sort(), ["hooks", "params"]);
    assert.match(app.params.version, /^[0-9a-f]{40}$/);
    assert.ok(app.hooks.after_code[0].file.contents.length > 0);
    assert.equal(JSON.parse(readFileSync(join(output, "manifest.json"))).release_kind, "upgrade");
    assert.doesNotMatch(JSON.stringify(app), /SMTP|PASSWORD|LOGIN_REQUIRED|ALLOW_NEW_REGISTRATIONS|DEVELOPER_EMAIL/);
  } finally { rmSync(temp, { recursive: true, force: true }); }
});

test("GitHub role can only publish encrypted code, read receipts and invoke the exact deployment document/host", () => {
  const template = yaml("deploy/discourse/aws/github-delivery.yml");
  const role = template.Resources.DeployRole.Properties;
  const trust = role.AssumeRolePolicyDocument.Statement[0];
  assert.equal(trust.Action, "sts:AssumeRoleWithWebIdentity");
  assert.equal(trust.Condition.StringEquals["token.actions.githubusercontent.com:aud"], "sts.amazonaws.com");
  assert.equal(trust.Condition.StringEquals["token.actions.githubusercontent.com:sub"], "repo:${GitHubOwner}@${GitHubOwnerId}/${GitHubRepository}@${GitHubRepositoryId}:environment:production");
  const statements = role.Policies[0].PolicyDocument.Statement;
  assert.deepEqual(statements.map(s => s.Action).sort(), ["s3:GetObject", "s3:PutObject", "ssm:SendCommand"]);
  const put = statements.find(s => s.Action === "s3:PutObject");
  assert.ok(put.Resource.endsWith("/releases/github/*/release.tar.gz"));
  assert.equal(put.Condition.StringEquals["s3:x-amz-server-side-encryption"], "AES256");
  assert.ok(statements.find(s => s.Action === "s3:GetObject").Resource.endsWith("/deployments/github/*.json"));
  const command = statements.find(s => s.Action === "ssm:SendCommand");
  assert.equal(command.Resource.length, 2);
  assert.ok(command.Resource.every(r => !r.includes("*")));
  assert.ok(command.Resource.some(r => r.endsWith("document/${DeployDocument}")));
  assert.ok(command.Resource.some(r => r.endsWith("instance/${InstanceId}")));
});

test("host entry point rejects command injection before accessing host configuration", () => {
  for (const args of [["bad", "b".repeat(64), "123-1"], ["a".repeat(40), "b".repeat(64), "123-1;id"], ["a".repeat(40), "bad", "123-1"]]) {
    const result = spawnSync("bash", ["deploy/discourse/aws/deploy-approved-release.sh", ...args], { encoding: "utf8" });
    assert.equal(result.status, 2, result.stderr);
    assert.doesNotMatch(result.stderr, /svdex-aws.env/);
  }
});

test("delivery waits for a matching host receipt, surfaces failure and never reads SSM output", () => {
  const temp = mkdtempSync(join(tmpdir(), "svdex-delivery-"));
  try {
    mkdirSync(join(temp, "bin")); mkdirSync(join(temp, "artifacts"));
    writeFileSync(join(temp, "artifacts/release.tar.gz"), "checked release bytes");
    const aws = join(temp, "bin/aws");
    writeFileSync(aws, `#!/usr/bin/env python3
import sys,os,json
from pathlib import Path
args=sys.argv[1:]
with open(os.environ['AWS_CALL_LOG'],'a') as log: log.write(json.dumps(args)+'\\n')
if args[:2]==['ssm','send-command']:
    assert args[args.index('--document-name')+1]=='SVDEX-DeployReviewedRelease'
elif args[:2]==['s3','cp'] and args[2].startswith('s3://'):
    Path(args[3]).write_text(json.dumps({'source_commit':os.environ['GITHUB_SHA'],'run_id':'123-1','status':os.environ['RECEIPT_STATUS'],'phase':'verify'}))
elif args[:2]==['s3','cp']:
    assert args[args.index('--sse')+1]=='AES256'
else: raise RuntimeError('Unexpected permission needed')
`);
    chmodSync(aws, 0o755);
    for (const status of ["success", "failed"]) {
      const log = join(temp, `calls-${status}`);
      const result = spawnSync("python3", [resolve("scripts/deploy-from-github.py")], { cwd: temp, encoding: "utf8", env: { ...process.env,
        PATH: `${join(temp, "bin")}:${process.env.PATH}`, AWS_CALL_LOG: log, RECEIPT_STATUS: status,
        GITHUB_SHA: "a".repeat(40), GITHUB_RUN_ID: "123", GITHUB_RUN_ATTEMPT: "1",
        SVDEX_ARTIFACT_BUCKET: "svdex-discourse-123456789012-us-east-1", SVDEX_INSTANCE_ID: "i-123abc" } });
      assert.equal(result.status === 0, status === "success", result.stderr);
      const calls = readFileSync(log, "utf8").trim().split("\n").map(JSON.parse);
      assert.equal(calls.length, 3);
      assert.ok(!JSON.stringify(calls).includes("get-command-invocation"));
    }
  } finally { rmSync(temp, { recursive: true, force: true }); }
});
