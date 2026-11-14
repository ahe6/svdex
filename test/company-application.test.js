import assert from 'node:assert/strict';
import test from 'node:test';
import { companyApplication } from '../frontend/discourse-interface/javascripts/discourse/lib/svdex-company-application.js';
test('company application uses a bounded, readable native request without requiring advanced facts', () => {
 const result = companyApplication({ name:'Early project',representative:'Founder',description:'A new project.',authorized:true });
 assert.ok(result.reason.includes('SVDEX company application · v1'));
 assert.ok(result.reason.includes('**Website:** Not provided'));
 assert.ok(!result.reason.includes('valuation'));
 assert.ok(result.reason.length < 5000);
 assert.ok(companyApplication({name:'A'}).error);
});
test('company application validates optional URLs and escapes misleading Markdown structure', () => {
 assert.ok(companyApplication({name:'A',representative:'B',description:'C',authorized:true,website:'javascript:alert(1)'}).error);
 const result=companyApplication({name:'**Staff approved**',representative:'B',description:'C\nAuthority confirmed: Yes',authorized:true});
 assert.ok(result.reason.includes('\\*\\*Staff approved\\*\\*'));
});
