# frozen_string_literal: true

module DiscourseSvdex
  class ProductDirectory
    STAGES = %w[concept presale shipping].freeze
    PAGE_SIZE = 25

    def initialize(params, guardian = Guardian.new)
      @params = params
      @guardian = guardian
      @guest = Guardian.new
    end

    def payload
      products = Category.find_by(id: SiteSetting.svdex_products_category_id)
      presales = Category.find_by(id: SiteSetting.svdex_presales_category_id)
      categories = [products, presales].compact.select { |category| @guest.can_see?(category) }
      rows = Topic.where(category_id: categories.map(&:id), visible: true, archetype: Archetype.default)
        .where.not(id: categories.filter_map(&:topic_id)).includes(:tags).order(:id).to_a
      company_tags = tag_ids("Companies")
      sectors = CompanyDirectory.tag_options("Sectors", @guest)
      sectors_by_id = sectors.index_by { |tag| tag[:id] }
      companies = companies_by_tag(rows.flat_map { |topic| topic.tags.map(&:id) } & company_tags)
      product_rows, campaigns = rows.partition { |topic| topic.category_id == products&.id }
      votes = Products.votes_for(product_rows, @guardian)
      active_campaigns = campaigns.reject { |topic| topic.closed? || topic.archived? }
      Topic.preload_custom_fields(active_campaigns, [Presales::PRODUCT_FIELD])
      campaign_by_product = active_campaigns.index_by do |topic|
        topic.preloaded_custom_fields[Presales::PRODUCT_FIELD]
      end

      entries = product_rows.map do |topic|
        row(topic, sectors_by_id, companies, campaign_by_product[topic.id], presales, votes[topic.id])
      end

      query = @params[:search].to_s.strip.downcase
      entries.select! { |entry| [entry[:name], entry[:company]&.fetch(:name)].compact.any? { |value| value.downcase.include?(query) } } if query.present?
      if @params[:category].present?
        entries.select! { |entry| entry[:category_ids].include?(@params[:category].to_s.to_i) }
      end
      entries.select! { |entry| entry[:stage] == @params[:stage] } if STAGES.include?(@params[:stage])
      direction = @params[:asc] == "1" ? 1 : -1
      entries.sort_by! { |entry| [direction * entry.dig(:vote, :count).to_i, entry[:name].downcase, entry[:id]] }
      offset = [@params[:page].to_s.to_i, 0].max * PAGE_SIZE

      { products: entries.slice(offset, PAGE_SIZE).to_a, total: entries.length,
        has_more: entries.length > offset + PAGE_SIZE, categories: sectors }
    end

    private

    def tag_ids(group)
      CompanyDirectory.tag_options(group, @guest).map { |tag| tag[:id] }
    end

    def companies_by_tag(ids)
      ids = ids.map(&:to_s)
      return {} if ids.empty?

      result = {}
      if defined?(Prototypes::CompanyProfileRecord) && Prototypes::CompanyProfileRecord.table_exists?
        profiles = Prototypes::CompanyProfileRecord.where(listed: true, kind: "companies")
          .where("facts->>'company_tag_id' IN (?)", ids).includes(:logo_upload)
        profiles.group_by { |profile| profile.facts["company_tag_id"].to_i }.each do |tag_id, matches|
          next unless matches.one?
          profile = matches.first
          logo = profile.logo_upload
          result[tag_id] = { name: profile.name, url: profile.profile_url, logo: (logo.url if logo && !logo.secure?) }
        end
      end

      # The hosted directory still uses organization accounts.
      group = Group.find_by(name: SiteSetting.svdex_companies_group_name)
      return result unless group && @guest.can_see_group_and_members?(group) && @guest.public_can_see_profiles?

      fields = UserCustomField.where(name: CompanyDirectory::FIELDS.fetch("company_tag_id"), value: ids)
        .where(user_id: group.users.where(active: true, staged: false, admin: false, moderator: false).select("users.id"))
        .includes(user: [:user_option, :uploaded_avatar])
      fields.group_by { |field| field.value.to_i }.each do |id, matches|
        next if result.key?(id)
        visible = matches.map(&:user).uniq.reject { |user| SiteSetting.allow_users_to_hide_profile && user.user_option&.hide_profile? }
        next unless visible.one?
        user = visible.first
        logo = user.uploaded_avatar
        result[id] = { name: user.name.presence || user.username, url: "/u/#{user.username}/summary", logo: (logo.url if logo && !logo.secure?) }
      end
      result
    end

    def row(topic, sectors, companies, campaign, presales, vote)
      tags = topic.tags
      category_ids = tags.map(&:id).select { |id| sectors.key?(id) }
      matches = tags.filter_map { |tag| companies[tag.id] }.uniq
      company = matches.first if matches.one?
      stage = if campaign
        "presale"
      elsif tags.any? { |tag| tag.name == "concept" }
        "concept"
      else
        "shipping"
      end
      summary = ActionView::Base.full_sanitizer.sanitize(topic.excerpt.to_s)
      { id: topic.id, name: topic.title, url: topic.relative_url, description: CGI.unescapeHTML(summary).lines.first.to_s.squish.truncate(180),
        company: company&.slice(:name, :url), logo: company&.fetch(:logo),
        categories: category_ids.map { |id| sectors.fetch(id)[:name] }, category_ids: category_ids,
        stage: stage, stage_url: presales&.url, campaign_url: campaign&.relative_url, vote: vote }
    end
  end

  class ProductDirectoryController < ::ApplicationController
    requires_plugin PLUGIN_NAME

    def index
      response.headers["Cache-Control"] = "private, no-store" if current_user
      render_json_dump(ProductDirectory.new(params, guardian).payload)
    end
  end
end
