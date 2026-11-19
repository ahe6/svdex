# frozen_string_literal: true
module DiscourseSvdex
  module Discoveries
    KINDS = %w[companies funds people].freeze
    CREDITED = %w[discovered self_listed].freeze
    def self.kind(user, fresh: false)
      return unless user && !user.staff?
      names = fresh ? Group.where(id: GroupUser.where(user_id: user.id).select(:group_id)).pluck(:name) : user.groups.pluck(:name)
      return "funds" if names.include?(SiteSetting.svdex_funds_group_name)
      return "companies" if names.include?(SiteSetting.svdex_companies_group_name)
      "people" if names.include?(SiteSetting.svdex_people_group_name)
    end
    def self.visible?(user, guardian)
      return false unless user&.active? && !user.staged? && guardian.public_can_see_profiles? && guardian.can_see_profile?(user)
      return false if SiteSetting.allow_users_to_hide_profile && user.user_option&.hide_profile? && !guardian.is_staff? && guardian.user&.id != user.id
      type = kind(user)
      return true unless type
      name = { "companies" => SiteSetting.svdex_companies_group_name, "funds" => SiteSetting.svdex_funds_group_name, "people" => SiteSetting.svdex_people_group_name }.fetch(type)
      guardian.can_see_group_and_members?(Group.find_by(name: name))
    end
    def self.event!(row, actor, action, reason, before = {})
      DiscoveryEvent.create!(discovery_id: row.id, acting_user_id: actor&.id, action: action, reason: reason, before_state: before, after_state: row.attributes, created_at: Time.current)
    end
    def self.capture!(user, listed_at: Time.current)
      return unless type = kind(user, fresh: true)
      user.with_lock do
        row = Discovery.find_by(entity_user_id: user.id, superseded_by_id: nil)
        if row
          if row.entity_kind != type
            before = row.attributes
            row.update!(entity_kind: type)
            event!(row, nil, "reclassified", "Native directory classification changed", before)
          end
          return row
        end
        row = Discovery.create!(entity_user_id: user.id, original_entity_user_id: user.id, entity_kind: type, listed_at: listed_at)
        event!(row, nil, "indexed", listed_at ? "Native directory classification" : "Existing directory record; original listing date unknown")
        row
      end
    end
    def self.record!(entity, actor, attrs)
      raise Discourse::InvalidAccess unless actor&.staff?
      raise Discourse::NotFound unless type = kind(entity, fresh: true)
      attrs = attrs.stringify_keys
      reason = attrs["reason"].to_s.strip
      raise Discourse::InvalidParameters.new(:reason) unless reason.length.between?(5, 1000)
      entity.with_lock do
        row = capture!(entity, listed_at: nil)
        row.lock!
        before = row.attributes
        provenance = attrs.fetch("provenance", row.provenance)
        status = attrs.fetch("status", row.status)
        raise Discourse::InvalidParameters.new(:provenance) unless %w[discovered self_listed staff_added imported].include?(provenance)
        raise Discourse::InvalidParameters.new(:status) unless %w[accepted withdrawn disputed].include?(status)
        contributor = nil
        if CREDITED.include?(provenance)
          contributor = User.find_by(username_lower: attrs["contributor"].to_s.downcase)
          raise Discourse::InvalidParameters.new(:contributor) unless contributor&.active? && !contributor.staged?
          raise Discourse::InvalidParameters.new(:contributor) if provenance == "discovered" && contributor.id == entity.id
          raise Discourse::InvalidParameters.new(:contributor) if provenance == "self_listed" && contributor.id != entity.id
        end
        # Do not turn an old account's creation date into a discovery date.
        listed_at = row.listed_at
        if attrs["listed_at"].present?
          begin
            supplied_date = Time.iso8601(attrs["listed_at"])
          rescue ArgumentError
            raise Discourse::InvalidParameters.new(:listed_at)
          end
          raise Discourse::InvalidParameters.new(:listed_at) if supplied_date > Time.current || supplied_date.to_i < entity.created_at.to_i
          raise Discourse::InvalidParameters.new(:listed_at) if listed_at && supplied_date.to_i != listed_at.to_i
          listed_at ||= supplied_date
        end
        raise Discourse::InvalidParameters.new(:listed_at) if contributor && listed_at.nil?
        if contributor && status == "accepted"
          # Staff must review a substantive record, not award bare-name spam.
          description = ActionView::Base.full_sanitizer.sanitize(entity.user_profile.bio_raw.to_s).strip
          raise Discourse::InvalidParameters.new(:profile) if entity.name.blank? || description.length < 20
        end
        row.assign_attributes(entity_kind: type, provenance: provenance, status: status, contributor_user_id: contributor&.id, listed_at: listed_at)
        row.original_contributor_user_id ||= contributor&.id
        row.save!
        event!(row, actor, "reviewed", reason, before)
        StaffActionLogger.new(actor).log_custom("svdex_discovery_review", target_user_id: entity.id, discovery_id: row.id, reason: reason)
        row
      end
    end
    def self.credit(entity, guardian)
      return unless visible?(entity, guardian) && kind(entity)
      row = Discovery.find_by(entity_user_id: entity.id, superseded_by_id: nil, status: "accepted")
      return unless row
      contributor = row.contributor
      data = { provenance: row.provenance, listed_at: row.listed_at&.iso8601 }
      if CREDITED.include?(row.provenance)
        return unless visible?(contributor, guardian)
        data[:contributor] = BasicUserSerializer.new(contributor, scope: guardian, root: false).as_json
      end
      data
    end
    def self.history(user, guardian, type: nil, order: "newest", page: 0, limit: 20)
      raise Discourse::NotFound unless visible?(user, guardian)
      raise Discourse::InvalidParameters.new(:kind) if type.present? && !KINDS.include?(type)
      raise Discourse::InvalidParameters.new(:order) unless %w[newest oldest].include?(order)
      rows = Discovery.where(contributor_user_id: user.id, superseded_by_id: nil, status: "accepted", provenance: "discovered")
      rows = rows.where(entity_kind: type) if type.present?
      rows = rows.order(listed_at: order == "oldest" ? :asc : :desc, id: order == "oldest" ? :asc : :desc).includes(entity: [:groups, :user_option, :user_profile, :user_stat])
      # Visibility is applied before counts and pagination. Private/removed
      # entities never contribute even a public count or a dangling title.
      rows = rows.select { |r| kind(r.entity) == r.entity_kind && visible?(r.entity, guardian) }
      entries = rows.map { |row| serialize(row, guardian) } + additional_history(user, guardian, type: type)
      entries.sort_by! { |entry| [entry[:listed_at], entry[:id]] }
      entries.reverse! unless order == "oldest"
      { count: entries.length, records: entries.slice(page * limit, limit).to_a, has_more: entries.length > (page + 1) * limit }
    end
    # Local entity experiments can contribute entries before shared pagination.
    def self.additional_history(user, guardian, type: nil)
      []
    end
    def self.serialize(row, guardian)
      { id: row.id, entity: BasicUserSerializer.new(row.entity, scope: guardian, root: false).as_json, kind: row.entity_kind,
        background: row.entity_kind == "people" ? PeopleDirectory.background(row.entity) : ActionView::Base.full_sanitizer.sanitize(row.entity.user_profile.bio_excerpt.to_s).strip.presence,
        provenance: row.provenance, listed_at: row.listed_at.iso8601, url: "/u/#{row.entity.username_lower}/summary" }
    end
    def self.merge!(source, target)
      Discovery.transaction do
        # Keep immutable original IDs and full snapshots even when core deletes
        # the source account. Contributor identities follow native account merges.
        Discovery.where(contributor_user_id: source.id).find_each do |row|
          before = row.attributes
          row.update!(contributor_user_id: target.id)
          event!(row, nil, "contributor_merged", "Native account merge #{source.id} into #{target.id}", before)
        end
        source_row = Discovery.find_by(entity_user_id: source.id, superseded_by_id: nil)
        target_row = Discovery.find_by(entity_user_id: target.id, superseded_by_id: nil)
        return unless source_row
        if target_row
          credited = [source_row, target_row].select { |row| row.provenance == "discovered" && row.listed_at && row.status == "accepted" }
          winner = credited.min_by { |row| [row.listed_at, row.id] } || target_row
          loser = winner.id == source_row.id ? target_row : source_row
          before = loser.attributes
          loser.update!(superseded_by_id: winner.id)
          event!(loser, nil, "entity_merged", "Native entity merge into #{target.id}; original attribution retained for review", before)
          before = winner.attributes
          # Keep the earliest credited discovery's original date, but never
          # silently settle duplicate-credit disputes or award fresh credit.
          winner.update!(entity_user_id: target.id, entity_kind: kind(target, fresh: true) || winner.entity_kind, status: "disputed")
          event!(winner, nil, "merge_review_required", "Review merged discovery #{loser.id} before restoring public credit", before)
        else
          before = source_row.attributes
          source_row.update!(entity_user_id: target.id, entity_kind: kind(target, fresh: true) || source_row.entity_kind)
          event!(source_row, nil, "entity_merged", "Native entity merge #{source.id} into #{target.id}", before)
        end
      end
    end
  end
end
