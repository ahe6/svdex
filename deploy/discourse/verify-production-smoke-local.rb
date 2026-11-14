# frozen_string_literal: true
abort "Local verification only" unless GlobalSetting.hostname == "localhost" && SiteSetting.port.to_s == "4080"
source = File.read("/tmp/svdex-production-smoke.rb")
source = source.sub('GlobalSetting.hostname == "svdex.com"', 'GlobalSetting.hostname == "localhost" && SiteSetting.port.to_s == "4080"')
source = source.sub('ENV["SVDEX_PRODUCTION_CHECK"] == "1"', 'true')
source = source.sub('User.find_by_email(ENV.fetch("DISCOURSE_DEVELOPER_EMAILS").split(",").first.strip)', 'User.find_by!(username: "svdex")')
source = source.gsub('app.host! "svdex.com"', 'app.host! "localhost"').sub("  app.https!\n", "")
values = { svdex_interest_enabled: true, svdex_interest_public_totals: true, svdex_bids_enabled: true, backup_with_uploads: true, backup_frequency: 1 }
before = values.keys.to_h { |key| [key, SiteSetting.public_send(key)] }
begin
  values.each { |key, value| SiteSetting.public_send("#{key}=", value) }
  eval(source, binding, "verify-production.rb")
ensure
  before.each { |key, value| SiteSetting.public_send("#{key}=", value) }
end
