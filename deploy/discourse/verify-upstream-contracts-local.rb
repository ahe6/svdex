# frozen_string_literal: true
# These intentionally strict checks make an upstream upgrade require a review
# of the native implementation we extend, instead of silently trusting it.
abort "Local verification only" unless GlobalSetting.hostname == "localhost" && SiteSetting.port.to_s == "4080"
require "json"
require "digest"
contracts = JSON.parse(File.read("/tmp/svdex-upstream-contracts.json"))
contracts.fetch("files").each do |entry|
  path = Rails.root.join(entry.fetch("path"))
  unless path.file? && Digest::SHA256.file(path).hexdigest == entry.fetch("sha256")
    raise "Upstream changed: #{entry.fetch('path')} (#{entry.fetch('integration')}). Review the integration and its tests before updating upstream-contracts.json."
  end
  puts "PASS reviewed upstream contract: #{entry.fetch('integration')}"
end
normalize = ->(text) do
  text.lines.reject { |line| line.strip.start_with?("//") || line.include?('import DiscussionChatNavigation from') || line.strip == "<DiscussionChatNavigation />" }.join.gsub(/\s+/, "")
end
native = Rails.root.join("plugins/chat/assets/javascripts/discourse/templates/chat.gjs").read
ours = File.read("/tmp/miscdex-interface/javascripts/discourse/templates/svdex-chat.gjs")
raise "Chat shell diverges beyond the reviewed Discussions toolbar insertion" unless normalize.call(native) == normalize.call(ours)
puts "PASS custom Chat shell matches native shell except the Discussions toolbar"
