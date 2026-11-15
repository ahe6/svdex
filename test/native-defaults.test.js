import test from "node:test";
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";

test("shared native defaults never write permissions, signup, intake or credentials; unknown groups fail before writes", () => {
  const result = spawnSync("ruby", ["-rjson", "-e", `
    module SiteSetting
      @writes = {}
      def self.method_missing(name, *args)
        allowed = %w[nested_replies_enabled= nested_replies_default= discourse_events_enabled= discourse_post_event_enabled= enable_improved_event_reminders= sidebar_show_upcoming_events=]
        raise "Unexpected security-sensitive default: #{name}" unless allowed.include?(name.to_s)
        @writes[name] = args.first
      end
      def self.writes; @writes; end
    end
    require File.expand_path("deploy/discourse/native-defaults.rb")
    begin
      SvdexNativeDefaults.apply!(:events, :unknown)
      raise "Unknown group accepted"
    rescue KeyError
      raise "Partial settings applied" unless SiteSetting.writes.empty?
    end
    SvdexNativeDefaults.apply!(:navigation, :events)
    puts SiteSetting.writes.to_json
  `], { encoding: "utf8" });
  assert.equal(result.status, 0, result.stderr);
  const values = JSON.parse(result.stdout);
  assert.equal(values["nested_replies_default="], true);
  assert.equal(values["sidebar_show_upcoming_events="], false);
});
