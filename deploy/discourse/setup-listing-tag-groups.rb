# frozen_string_literal: true
abort "Local setup only" unless GlobalSetting.hostname == "localhost" && SiteSetting.port.to_s == "4080"
actor = User.find_by!(username: "svdex")

# Rename through core so memberships, topic associations and audit history stay
# attached to the original tags. Never replace a tag with an unrelated record.
{
  "science-technology" => "hardware",
  "private-capital" => "finance",
}.each do |old_name, new_name|
  tag = Tag.find_by(name: old_name)
  next unless tag
  raise "Rename conflict: #{new_name}" if Tag.where(name: new_name).where.not(id: tag.id).exists?
  updater = TagSettingsUpdater.new(tag, actor)
  raise updater.errors.join(", ") unless updater.update(name: new_name, slug: new_name)
end

sectors = {
  "software" => "Software products, platforms and developer tools.",
  "ai" => "Artificial intelligence models, applications and infrastructure.",
  "hardware" => "Physical computing, electronics, instruments and devices.",
  "finance" => "Financial services, investing and financial technology.",
  "healthcare" => "Healthcare delivery, services and medical technology.",
  "biotech" => "Biological research, therapeutics and life-science tools.",
  "energy" => "Energy generation, storage, infrastructure and services.",
  "climate" => "Climate mitigation, adaptation and environmental technology.",
  "industrials" => "Manufacturing, industrial equipment and automation.",
  "consumer" => "Consumer products, brands and retail businesses.",
  "property" => "Real estate, property services and property technology.",
  "transport" => "Mobility, logistics and transportation businesses.",
  "education" => "Learning products, education services and training.",
  "media" => "Media, entertainment, content and communications.",
  "agriculture" => "Farming, food production and agricultural technology.",
}
Tag.transaction do
  sectors.each do |name, description|
    Tag.find_or_create_by!(name: name) { |tag| tag.description = description }
  end
  {
    "Companies" => %w[northstar svdex],
    "Sectors" => sectors.keys,
    "Topics" => %w[community feedback financials founder-updates notifications research],
  }.each do |name, tag_names|
    group = TagGroup.find_by_name_insensitive(name) || TagGroup.create!(name: name)
    tag_names.each { |tag_name| Tag.find_or_create_by!(name: tag_name) }
    Tag.where(name: tag_names).find_each do |tag|
      group.tags << tag unless group.tags.exists?(tag.id)
    end
    puts "#{group.name}: #{group.tags.order(:name).pluck(:name).join(', ')}"
  end
end
SiteSetting.tags_listed_by_group = true
DiscourseTagging.clear_cache!
