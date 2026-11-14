# frozen_string_literal: true
abort "Local setup only" unless GlobalSetting.hostname == "localhost" && SiteSetting.port.to_s == "4080"
# Preserve manually entered figures. Import only already-recorded company-wide
# funding; a SAFE cap or proposed round must not become a last valuation.
{ "svdex-company" => "finance", "northstar" => "hardware" }.each do |username, sector|
  user = User.find_by!(username: username)
  next unless DiscourseSvdex::CompanyDirectory.company?(user)
  field = "svdex_company_total_funding_usd"
  if user.custom_fields[field].nil? && user.custom_fields["svdex_total_funding"].present?
    value = user.custom_fields["svdex_total_funding"]
    raise "Unrecognized existing funding" unless value.match?(/\AUSD [0-9,]+\z/)
    user.custom_fields[field] = value.delete_prefix("USD ").delete(",").to_i
  end
  user.custom_fields["svdex_company_sector_tag_id"] ||= Tag.find_by!(name: sector).id
  user.save_custom_fields
  puts "Company facts retained: #{user.name}"
end
