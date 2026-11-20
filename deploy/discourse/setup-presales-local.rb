# frozen_string_literal: true
# Local product/pricing fixtures only. Never package as production content.
abort "Local fixtures only" unless GlobalSetting.hostname == "localhost" && SiteSetting.port.to_s == "4080"
category = Category.find(SiteSetting.svdex_presales_category_id)
[
  ["Northstar Pocket Spectrometer — First production run", "Northstar Pocket Spectrometer", "northstar", "hardware", {
    summary: "Pocket optical spectrometer for field measurements.", price: "$249 per device",
    includes: "Device and calibration kit", delivery: "Expected March 2027", terms: "Shipping charged separately."
  }],
  ["SVDEX Research — Annual early access", "SVDEX Research", "svdex-company", "finance", {
    summary: "Company research and private-market data in one workspace.", price: "$120 per year",
    includes: "12 months of research tools", delivery: "Access from January 2027", terms: "One named user."
  }],
].each do |title, product_title, username, tag, fields|
  product = Topic.find_by!(title: product_title, category_id: SiteSetting.svdex_products_category_id)
  product_field = DiscourseSvdex::Presales::PRODUCT_FIELD
  if (campaign = Topic.find_by(title: title, category_id: category.id))
    if campaign.custom_fields[product_field].blank?
      campaign.custom_fields[product_field] = product.id
      campaign.save_custom_fields
    end
    next
  end
  product_tags = TagGroup.find_by_name_insensitive("Products")&.tags&.where(id: product.tags.select(:id))&.pluck(:name) || []
  author = User.find_by!(username: username)
  PostCreator.create!(author, { title: title, raw: "#{fields[:summary]}\n\n#{fields[:includes]}. #{fields[:price]}. #{fields[:delivery]}. #{fields[:terms]}\n\nUse this thread for product questions and updates.",
    category: category.id, tags: [tag, *product_tags], svdex_presale_product_id: product.id,
    skip_validations: true, skip_jobs: true }.merge(fields.to_h { |key, value| ["svdex_presale_#{key}".to_sym, value] }))
end
puts "Local Pre-sales topics ready."
