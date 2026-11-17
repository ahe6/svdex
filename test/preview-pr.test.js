import test from "node:test";
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";

test("staging PR resolution rejects drafts, stale source and incomplete required checks", () => {
  const result = spawnSync("python3", ["-c", `
import runpy
validate=runpy.run_path('scripts/resolve-preview-pr.py')['validate']
pr=dict(state='open',draft=False,base=dict(ref='main'),head=dict(sha='a'*40))
checks=[dict(name='check',state='SUCCESS'),dict(name='native',state='SUCCESS')]
assert validate(pr,checks,dict(status='ahead'))=='a'*40
for p,c,comparison in [
    (dict(pr,draft=True),checks,dict(status='ahead')),
    (dict(pr,state='closed'),checks,dict(status='ahead')),
    (dict(pr,base=dict(ref='staging')),checks,dict(status='ahead')),
    (pr,checks,dict(status='diverged')),
    (pr,checks,dict(status='behind')),
    (pr,checks[:1],dict(status='ahead')),
    (pr,[*checks,dict(name='native',state='FAILURE')],dict(status='ahead')),
    (pr,[dict(name='check',state='SUCCESS'),dict(name='native',state='SKIPPED')],dict(status='ahead')),
]:
    try: validate(p,c,comparison)
    except ValueError: pass
    else: raise RuntimeError('Unreviewed or stale candidate accepted')
`], { encoding: "utf8" });
  assert.equal(result.status, 0, result.stderr);
});
