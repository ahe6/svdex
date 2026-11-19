import test from "node:test";
import assert from "node:assert/strict";
import { withdrawalMessage } from "../frontend/discourse-interface/javascripts/discourse/lib/svdex-submissions.js";

test("withdrawal remains available without a redacted organization or offering", () => {
  assert.equal(withdrawalMessage({ kind: "interest", side: "buy", organization: null }), "Withdraw this buy interest?");
  assert.equal(withdrawalMessage({ kind: "interest", side: "sell" }), "Withdraw this sell interest?");
  assert.equal(withdrawalMessage({ kind: "bid", topic: null, organization: null }), "Withdraw this bid?");
  assert.equal(withdrawalMessage({ kind: "interest", side: "buy", organization: { name: "Northstar" } }), "Withdraw your buy interest in Northstar?");
  assert.equal(withdrawalMessage({ kind: "bid", topic: { title: "Northstar bond" } }), "Withdraw your bid for Northstar bond?");
});
