# frozen_string_literal: true
# Native policy topics and static pages; no separate storage or custom legal UI.
require "digest"
require "json"
require "date"

local = GlobalSetting.hostname == "localhost" && SiteSetting.port.to_s == "4080"
production = GlobalSetting.hostname == "svdex.com" && ENV["SVDEX_APPLY_SITE_PAGES"] == "1"
abort "Expected local preview or explicit SVDEX production operation" unless local || production
root = ENV.fetch("SVDEX_SITE_PAGES_ROOT", "/tmp/svdex-site-pages")
paths = %w[privacy terms].to_h { |name| [name, File.join(root, "#{name}.md")] }
source = paths.transform_values { |path| File.read(path) }
config_path = ENV["SVDEX_SITE_PAGES_CONFIG"]
config = config_path ? JSON.parse(File.read(config_path)) : {}
content_hash = Digest::SHA256.hexdigest(source.sort.map { |name, raw| "#{name}\0#{raw}" }.join("\0"))

if production
  raise "Owner-approved operator name required" unless %w[operator_name].all? { |key| config[key].is_a?(String) && config[key].strip.present? && !config[key].match?(/[{}<>]/) }
  raise "Current policy text must be approved" unless config["approved_content_sha256"] == content_hash && config["approved"] == true
  raise "Effective date required" unless config["effective_date"]&.match?(/\A\d{4}-\d{2}-\d{2}\z/)
end
effective = Date.iso8601(config.fetch("effective_date", Date.current.iso8601)).strftime("%-d %B %Y")
intro = if config["operator_name"].present?
  name = ERB::Util.html_escape(config.fetch("operator_name"))
  jurisdiction = config["operator_jurisdiction"].presence
  jurisdiction ? "SVDEX is operated by #{name}, incorporated in #{ERB::Util.html_escape(jurisdiction)}." : "SVDEX is operated by #{name}."
else
  "SVDEX is a company research and discussion site."
end
rendered = source.transform_values { |raw| raw.gsub("{{operator_intro}}", intro).gsub("{{effective_date}}", effective).rstrip }
raise "Unresolved policy fields" if rendered.values.any? { |raw| raw.match?(/\{\{.*?\}\}/) }
actor = local ? User.find_by!(username: "svdex") : User.find_by_email(ENV.fetch("DISCOURSE_DEVELOPER_EMAILS").split(",").first.strip)
raise "Active administrator required" unless actor&.admin? && actor.active?
staff = Category.find_by!(slug: "staff")
settings = { "privacy" => :privacy_topic_id, "terms" => :tos_topic_id }
titles = { "privacy" => "Privacy Policy", "terms" => "Terms of Service" }
result = {}

ActiveRecord::Base.transaction do
  settings.each do |name, setting|
    topic = Topic.find_by(id: SiteSetting.public_send(setting).to_i)
    if topic
      post = topic.first_post
      raise "Missing native policy post" unless post
      if post.raw != rendered.fetch(name)
        raise "Could not revise #{name}" unless PostRevisor.new(post).revise!(actor, { raw: rendered.fetch(name) }, skip_validations: true, bypass_bump: true)
      end
    else
      post = PostCreator.create!(Discourse.system_user, title: titles.fetch(name), raw: rendered.fetch(name), category: staff.id, skip_validations: true, skip_jobs: true)
      topic = post.topic
      SiteSetting.public_send("#{setting}=", topic.id)
    end
    topic.update!(visible: false) if topic.visible?
    result[name] = topic.id
  end
  # Core publishes these topics at the native static routes, despite staff-only
  # editing/storage. Refuse to silently replace a configured external policy URL.
  raise "External policy URLs need separate review" if SiteSetting.tos_url.present? || SiteSetting.privacy_policy_url.present?
  welcome = Topic.find_by(slug: "welcome-to-svdex", user_id: Discourse.system_user.id)&.first_post
  if welcome
    raw = welcome.raw.gsub(/\[(?:Community )?Guidelines\]\(\/(?:faq|guidelines)\)/, "[Terms](/tos)")
    if raw != welcome.raw
      raise "Could not update Welcome policy link" unless PostRevisor.new(welcome).revise!(actor, { raw: raw }, skip_validations: true, bypass_bump: true)
    end
  end
  # Native help/email links should lead to the rules retained in Terms.
  SiteSetting.faq_url = "#{Discourse.base_url}/tos"
  SiteSetting.contact_email = "austin@svdex.com"
  SiteSetting.company_name = config.fetch("operator_name") if production
  PluginStore.set("svdex", "site_pages", { source_sha256: content_hash, effective_date: config.fetch("effective_date", Date.current.iso8601), operator_confirmed: production })
end
puts JSON.generate(native_pages: result, source_sha256: content_hash, production: production, operator_confirmed: production)
