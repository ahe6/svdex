# frozen_string_literal: true
module DiscourseSvdex
  class Discovery < ActiveRecord::Base
    self.table_name = "svdex_discoveries"
    belongs_to :entity, class_name: "User", foreign_key: :entity_user_id, optional: true
    belongs_to :contributor, class_name: "User", foreign_key: :contributor_user_id, optional: true
    attr_readonly :original_entity_user_id
    validate :preserve_first_attribution
    def preserve_first_attribution
      return if new_record?
      %w[listed_at original_contributor_user_id].each do |field|
        original = attribute_in_database(field)
        errors.add(field, "must preserve the original attribution") if original && public_send(field) != original
      end
    end
    validates :entity_kind, inclusion: { in: %w[companies funds people] }
    validates :provenance, inclusion: { in: %w[discovered self_listed staff_added imported] }
    validates :status, inclusion: { in: %w[accepted withdrawn disputed] }
  end
  class DiscoveryEvent < ActiveRecord::Base
    self.table_name = "svdex_discovery_events"
    # Append-only through the service. Native backups include both tables.
    def readonly?
      persisted?
    end
  end
end
