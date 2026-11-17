# frozen_string_literal: true
# Local product/pricing fixtures only. Never package as production content.
abort "Local fixtures only" unless GlobalSetting.hostname == "localhost" && SiteSetting.port.to_s == "4080"
category = Category.find(SiteSetting.svdex_presales_category_id)
[
  ["Northstar Pocket Spectrometer — First production run", "northstar", "hardware", {
    summary: "Pocket optical spectrometer for field measurements.", price: "$249 per device",
    includes: "Device and calibration kit", delivery: "Expected March 2027", terms: "Shipping charged separately."
  }],
  ["SVDEX Research — Annual early access", "svdex-company", "finance", {
    summary: "Company research and private-market data in one workspace.", price: "$120 per year",
    includes: "12 months of research tools", delivery: "Access from January 2027", terms: "One named user."
  }],
].each do |title, username, tag, fields|
  next if Topic.exists?(title: title, category_id: category.id)
  author = User.find_by!(username: username)
  PostCreator.create!(author, { title: title, raw: "#{fields[:summary]}\n\n#{fields[:includes]}. #{fields[:price]}. #{fields[:delivery]}. #{fields[:terms]}\n\nUse this thread for product questions and updates.",
    category: category.id, tags: [tag], skip_validations: true, skip_jobs: true }.merge(fields.to_h { |key, value| ["svdex_presale_#{key}".to_sym, value] }))
end
puts "Local Pre-sales topics ready."
