# frozen_string_literal: true
abort "Local verification only" unless GlobalSetting.hostname == "localhost" && SiteSetting.port.to_s == "4080"
Middleware::AnonymousCache.disable_anon_cache
raise "Companies must not be a category" if Category.exists?(slug: "companies")
group = Group.find_by!(name: SiteSetting.svdex_companies_group_name)
raise "Company identity allows self-enrollment" if group.public_admission
expected = User.where(username: %w[svdex-company northstar svdex-fund-i]).pluck(:id).sort
raise "Unexpected company membership" unless group.users.where(admin: false, moderator: false).pluck(:id).sort == expected
raise "Company accounts gained staff permissions" if group.users.any? { |u| u.staff? && DiscourseSvdex::CompanyDirectory.company?(u) }
app = ActionDispatch::Integration::Session.new(Rails.application)
app.host! "localhost"
app.get "/companies"
raise "Company directory shell failed" unless app.response.status == 200
%i[weekly all].each do |period|
  app.get "/listings/company-directory.json", params: { kind: "all", period: period, group: group.name, order: "likes_given" }
  raise "Native company directory failed: #{app.response.status} #{app.response.body[0, 500]}" unless app.response.status == 200
  rows = app.response.parsed_body.fetch("directory_items")
  raise "Company directory exposes ordinary accounts" unless rows.map { |row| row.fetch("user").fetch("id") }.sort == expected
  rows.each do |row|
    user = User.find(row.fetch("user").fetch("id"))
    if Guardian.new(nil).can_see_profile?(user)
      raise "Company summary missing" if row.fetch("user")["svdex_company_summary"].blank?
    else
      raise "Profile privacy bypassed" if row.fetch("user").key?("svdex_company_summary")
    end
    raise "Native statistics missing" unless row.key?("likes_given") && row.key?("topic_count")
  end
  more = app.response.parsed_body.fetch("meta").fetch("load_more_directory_items")
  raise "Pagination loses group restriction" unless URI.parse(more).path == "/listings/company-directory.json" && CGI.parse(URI.parse(more).query).fetch("kind") == ["all"]
end
app.get "/listings/company-directory.json", params: { kind: "all", period: "all", group: group.name, name: "northstar", order: "username", asc: "true" }
raise "Native company filtering failed" unless app.response.parsed_body.fetch("directory_items").map { |row| row.fetch("user").fetch("username") } == ["northstar"]
app.get "/directory_items.json", params: { period: "all" }
raise "Ordinary Users directory changed" unless app.response.parsed_body.fetch("directory_items").any? { |row| row.fetch("user").fetch("username") == "svdex" }
raise "Ordinary account gets company summary" if app.response.parsed_body.fetch("directory_items").find { |row| row.fetch("user").fetch("username") == "svdex" }.fetch("user").key?("svdex_company_summary")
Group.transaction do
  group.update!(visibility_level: Group.visibility_levels[:staff], members_visibility_level: Group.visibility_levels[:staff])
  app.get "/listings/company-directory.json", params: { kind: "all", period: "all", group: group.name }
  raise "Native private-group protection bypassed" unless [403, 404].include?(app.response.status)
  raise ActiveRecord::Rollback
end
User.transaction do
  user = User.find_by!(username: "northstar")
  user.user_profile.update!(bio_raw: "Updated company biography for native account editing.")
  app.get "/listings/company-directory.json", params: { kind: "all", period: "all", group: group.name, name: "northstar" }
  summary = DirectoryItemSerializer::UserSerializer.new(user.reload, scope: User.find_by!(username: "svdex").guardian, root: false).as_json.with_indifferent_access.fetch("svdex_company_summary")
  raise "Company summary does not follow native biography edits" unless summary.include?("Updated company biography")
  group.remove(user)
  app.get "/listings/company-directory.json", params: { kind: "all", period: "all", group: group.name }
  raise "Removed company still listed" if app.response.parsed_body.fetch("directory_items").any? { |row| row.fetch("user").fetch("id") == user.id }
  raise ActiveRecord::Rollback
end
puts "PASS actual native company-account directory, grouped filtering, native stats and pagination, membership removal, profile biography edits, ordinary Users preservation and private-group protection"
