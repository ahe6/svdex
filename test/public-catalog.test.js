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
  const product = {...base,facts:{description:"Research instrument details.",status:"launched",company_tag:"research-company"}};
  const security = {...base,tag:null,facts:{description:"Public instrument details.",instrument_type:"debt",interest_rate:"8% per year",topic_id:123}};
  assert.deepEqual(validate([["funds",fund],["people",person],["products",product],["securities",security]]),[true,true,true,true]);
  const bad = [["funds",{...base,facts:{source_url:"javascript:alert(1)"}}],["funds",{...fund,email:"private@example.org"}],["funds",{...fund,facts:{aum_usd:10}}],["people",{...person,facts:{net_worth:"$1M"}}],["products",{...product,facts:{...product.facts,status:"security"}}],["products",{...product,facts:{...product.facts,api_key:"private"}}],["funds",{...fund,id:"../account"}]];
  assert.deepEqual(validate(bad),bad.map(()=>false));
  const invalidSecurityFacts = [{category_id: 4}, {private: true}, {topic_id: "4"}, {topic_id: null}, {instrument_type: "unrecognized"}];
  assert.deepEqual(validate(invalidSecurityFacts.map(fields=>["securities",{...security,facts:{...security.facts,...fields}}])),[false,false,false,false,false]);
});
test("public catalog accepts birth year only with a public HTTPS source", () => {
  const birth_year_source = "https://example.org/biography";
  const facts = [
    { birth_year: 1984, birth_year_source },
    { birth_year: "1980–1984", birth_year_source },
    { birth_year: "1984–1980", birth_year_source },
    { birth_year: 1984 },
    { birth_year_source },
    { birth_year: "1984", birth_year_source },
    { birth_year: 9999, birth_year_source },
    { birth_year: 1984, birth_year_source: "http://example.org/biography" },
  ];
  assert.deepEqual(validate(facts.map(personFacts => ["people", { ...base, facts: personFacts }])),
    [true, true, false, false, false, false, false, false]);
});
test("precise money stays precise while open bands sort by their lower bounds", () => {
  const source = { net_worth_source: "https://example.org/estimate", net_worth_date: "2026-11-19", net_worth_basis: "Public estimate" };
  assert.deepEqual(validate(["$100k+", "$1M+", "$10M+", "$100M+", "$500k+", "$5M+", "$12M", "$8M–$12M", "£1M+"].map(net_worth =>
    ["people", { ...base, facts: { ...source, net_worth } }])), [true, true, true, true, false, false, true, false, false]);

  const inputs = ["$0", "$99,999.99", "$500k+", "USD 500,000", "$5M+", "$8M–$12M", "$10–20M", "$99.99M", "$100M", "$8M–$4M", "£5M", "$12T+"];
  const ruby = `require "json"; require "./deploy/discourse/plugins/discourse-svdex/lib/discourse_svdex/people_directory"; puts JSON.generate(JSON.parse(STDIN.read).map { |input| DiscourseSvdex::PeopleDirectory.net_worth_value(input)&.values_at(:value, :sort_value) })`;
  const result = spawnSync("ruby", ["-e", ruby], { input: JSON.stringify(inputs), encoding: "utf8" });
  assert.equal(result.status, 0, result.stderr);
  assert.deepEqual(JSON.parse(result.stdout), [
    ["$0", 0], ["$99,999.99", 9_999_999], ["$100k+", 10_000_000], ["USD 500,000", 50_000_000],
    ["$1M+", 100_000_000], ["$1M+", 100_000_000], ["$10M+", 1_000_000_000],
    ["$99.99M", 9_999_000_000], ["$100M", 10_000_000_000], null, null, ["$100M+", 10_000_000_000],
  ]);
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
