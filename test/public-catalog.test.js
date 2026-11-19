import test from "node:test";
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
function validate(values) {
  const ruby = `require './deploy/discourse/plugins/discourse-svdex/lib/discourse_svdex/prototypes/public_catalog_document'; puts JSON.generate(JSON.parse(STDIN.read).map { |kind, doc| begin; DiscourseSvdex::Prototypes::PublicCatalogDocument.validate!(kind,doc); true; rescue StandardError; false; end })`;
  const result = spawnSync("ruby", ["-e", ruby], {input:JSON.stringify(values),encoding:"utf8"});
  assert.equal(result.status,0,result.stderr); return JSON.parse(result.stdout);
}
const base = {schema_version:1,id:"research-fund",name:"Research Fund",summary:"Research infrastructure.",tag:"research-fund",sector:null,location:"United States",sources:[{url:"https://example.org/research",note:"Public source"}]};
test("public catalog accepts sourced typed facts and rejects private or unsupported fields", () => {
  const fund = {...base,facts:{aum_usd:12000000,facts_as_of:"2026-11-19",source_url:"https://example.org/research"}};
  const person = {...base,facts:{role:"Partner"}};
  const product = {...base,facts:{description:"Research instrument details.",status:"launched"}};
  assert.deepEqual(validate([["funds",fund],["people",person],["products",product]]),[true,true,true]);
  const bad = [["funds",{...base,facts:{source_url:"javascript:alert(1)"}}],["funds",{...fund,email:"private@example.org"}],["funds",{...fund,facts:{aum_usd:10}}],["people",{...person,facts:{net_worth:"$1M"}}],["products",{...product,facts:{...product.facts,status:"security"}}],["products",{...product,facts:{...product.facts,api_key:"private"}}],["funds",{...fund,id:"../account"}]];
  assert.deepEqual(validate(bad),bad.map(()=>false));
});
test("content publishing requires a current main PR and an authorized review or owner merge", () => {
  const script = `import importlib.util, os, json
s=importlib.util.spec_from_file_location('review','scripts/check-catalog-review.py'); m=importlib.util.module_from_spec(s); s.loader.exec_module(m)
os.environ.update(GITHUB_REPOSITORY='ahe6/svdex', GITHUB_SHA='a'*40, GITHUB_REF='refs/heads/main')
results=[]
for mode in ['owner','direct','stale','outsider','reviewed']:
 def gh(path):
  if path.endswith('/git/ref/heads/main'): return {'object':{'sha': ('b' if mode=='stale' else 'a')*40}}
  if path.endswith('/pulls'):
   return [] if mode=='direct' else [{'number':1,'merged_at':'now','draft':False,'base':{'ref':'main'},'merge_commit_sha':'a'*40}]
  if path.endswith('/reviews'): return [{'user':{'login':'reviewer'},'state':'APPROVED'},{'user':{'login':'reviewer'},'state':'COMMENTED'}]
  if path.endswith('/pulls/1'): return {'merged_by':{'login':'ahe6' if mode=='owner' else 'merge-bot'}}
  if path.endswith('/permission'): return {'permission':'write' if mode=='reviewed' else 'read'}
  raise Exception(path)
 m.gh=gh
 try: m.main(); results.append(True)
 except ValueError: results.append(False)
print(json.dumps(results))`;
  const result = spawnSync("python3", ["-c",script],{encoding:"utf8"});
  assert.equal(result.status,0,result.stderr);
  assert.deepEqual(JSON.parse(result.stdout),[true,false,false,false,true]);
});
