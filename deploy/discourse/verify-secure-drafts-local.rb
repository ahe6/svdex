# frozen_string_literal: true
abort "Local only" unless GlobalSetting.hostname == "localhost" && SiteSetting.port.to_s == "4080"
def draft_assert!(value, label)
  raise label unless value
  puts "PASS #{label}"
end
def draft_check(user, upload)
  controller = UploadsController.new
  controller.define_singleton_method(:current_user) { user }
  controller.define_singleton_method(:guardian) { Guardian.new(user) }
  controller.send(:check_secure_upload_permission, upload)
  true
rescue Discourse::NotFound, Discourse::InvalidAccess
  false
end
User.transaction do
  actor = User.find_by!(username: "svdex")
  owner, other = 2.times.map do
    User.create!(username: "draft_#{SecureRandom.hex(4)}", email: "#{SecureRandom.hex(8)}@example.invalid", password: SecureRandom.hex(24), active: true, approved: true)
  end
  upload = Upload.new(user_id: owner.id, secure: true)
  draft_assert!(draft_check(owner, upload) && draft_check(actor, upload), "secure unposted uploads remain available to their owner and staff")
  draft_assert!(!draft_check(other, upload) && !draft_check(nil, upload), "unrelated members and guests cannot obtain secure draft downloads or metadata")
  upload.secure = false
  draft_assert!(draft_check(other, upload), "ordinary unlinked public upload behavior remains native")
  upload.secure = true
  topic = PostCreator.create!(owner, title: "Private document review #{SecureRandom.hex(5)}", raw: "Private review conversation.", archetype: Archetype.private_message, target_usernames: actor.username, skip_validations: true, skip_jobs: true).topic
  upload.access_control_post = topic.first_post
  draft_assert!(draft_check(owner, upload) && draft_check(actor, upload), "posted documents keep native private-message participant access")
  draft_assert!(!draft_check(other, upload) && !draft_check(nil, upload), "posted document access still delegates to native post permissions")
  raise ActiveRecord::Rollback
end
puts "Secure draft checks complete; local records rolled back."
