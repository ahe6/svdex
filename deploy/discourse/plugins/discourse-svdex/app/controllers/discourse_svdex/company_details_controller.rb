# frozen_string_literal: true
module DiscourseSvdex
  class CompanyDetailsController < ::ApplicationController
    requires_plugin PLUGIN_NAME
    requires_login
    before_action :ensure_staff

    def show
      render_json_dump(payload(company))
    end

    def update
      user = company
      supplied = params.require(:company).permit(*(CompanyDirectory::FIELDS.keys - %w[key_people related_entities]), key_people: %i[name role url user_id], related_entities: %i[name role url user_id]).to_h
      raise Discourse::InvalidParameters.new(:company) if supplied.empty?
      values = supplied.transform_keys(&:to_s).to_h { |key, value| [key, CompanyDirectory.validate!(key, value)] }
      %w[sector_tag_id company_tag_id].each do |key|
        next unless values[key]
        group = key == "sector_tag_id" ? "Sectors" : "Companies"
        raise Discourse::InvalidParameters.new(key) unless CompanyDirectory.tag_options(group, guardian).any? { |tag| tag[:id] == values[key] }
      end
      if values["company_tag_id"]
        others = Group.find_by!(name: SiteSetting.svdex_companies_group_name).users.where.not(id: user.id)
        raise Discourse::InvalidParameters.new(:company_tag_id) if UserCustomField.where(user_id: others.select(:id), name: CompanyDirectory::FIELDS.fetch("company_tag_id"), value: values["company_tag_id"].to_s).exists?
      end
      size = values.key?("fund_size_usd") ? values["fund_size_usd"] : user.custom_fields[CompanyDirectory::FIELDS.fetch("fund_size_usd")]
      basis = values.key?("fund_size_basis") ? values["fund_size_basis"] : user.custom_fields[CompanyDirectory::FIELDS.fetch("fund_size_basis")]
      raise Discourse::InvalidParameters.new(:fund_size_basis) if size && basis.blank?
      User.transaction do
        values.each { |key, value| user.custom_fields[CompanyDirectory::FIELDS.fetch(key)] = value }
        user.save_custom_fields
        user.touch
        StaffActionLogger.new(current_user).log_custom("svdex_company_details", user_id: user.id, fields: values.keys.join(", "))
      end
      render_json_dump(payload(user.reload))
    end

    private

    def company
      user = User.find(params[:user_id])
      raise Discourse::NotFound unless CompanyDirectory.company?(user)
      user
    end

    def payload(user)
      {
        kind: user.groups.where(name: SiteSetting.svdex_funds_group_name).exists? ? "funds" : "companies",
        company: CompanyDirectory::FIELDS.transform_values { |field| user.custom_fields[field] },
        sectors: CompanyDirectory.tag_options("Sectors", guardian),
        companies: CompanyDirectory.tag_options("Companies", guardian),
        stages: CompanyDirectory::STAGES.map { |name| { id: name, name: name } },
      }
    end
  end
end
