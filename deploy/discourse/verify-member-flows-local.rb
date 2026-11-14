# frozen_string_literal: true
abort "Local verification only" unless GlobalSetting.hostname == "localhost" && SiteSetting.port.to_s == "4080"
Middleware::AnonymousCache.disable_anon_cache

def assert!(condition, label)
  raise label unless condition
  puts "PASS #{label}"
end

Post.transaction do
  password = SecureRandom.hex(24)
  member = -> {
    user = User.create!(username: "member_#{SecureRandom.hex(4)}",
      email: "#{SecureRandom.hex(8)}@example.invalid", password: password,
      active: true, approved: true, trust_level: 1)
    user.email_tokens.update_all(confirmed: true)
    user
  }
  owner, peer, outsider = 3.times.map { member.call }
  app = ActionDispatch::Integration::Session.new(Rails.application)
  app.host! "localhost"
  app.get "/session/csrf.json"
  csrf = app.response.parsed_body.fetch("csrf")
  headers = { "X-CSRF-Token" => csrf, "HTTP_ACCEPT" => "application/json", "X-Requested-With" => "XMLHttpRequest" }
  app.post "/session.json", params: { login: owner.username, password: password }, headers: headers
  assert!(app.response.status == 200 && app.response.parsed_body.dig("user", "id") == owner.id,
    "confirmed ordinary member can log in through the native session endpoint")

  discussion = Category.find_by!(slug: "discussion")
  title = "Company research #{SecureRandom.hex(6)}"
  app.post "/posts.json", params: { title: title, raw: "Which company research sources have been useful for understanding this market?", category: discussion.id }, headers: headers
  assert!(app.response.status == 200 && app.response.parsed_body["id"].present?, "member can publish an ordinary discussion")
  post = Post.find(app.response.parsed_body.fetch("id"))
  assert!(post.user_id == owner.id && !owner.staff?, "published discussion belongs to the ordinary member")

  app.post "/bookmarks.json", params: { bookmarkable_id: post.topic_id, bookmarkable_type: "Topic" }, headers: headers
  assert!(app.response.status == 200 && Bookmark.exists?(user: owner, bookmarkable: post.topic), "member can bookmark a discussion over HTTP")
  bookmark_id = app.response.parsed_body.fetch("id")
  app.delete "/bookmarks/#{bookmark_id}.json", headers: headers
  assert!(app.response.status == 200 && !Bookmark.exists?(id: bookmark_id), "member can remove their bookmark")

  assert!(!owner.guardian.can_create_group? && !owner.guardian.can_create_category?, "ordinary members cannot create groups or categories")
  group = Group.create!(name: "members_#{SecureRandom.hex(4)}")
  group.add(owner)
  group.add_owner(owner)
  assert!(owner.guardian.can_edit_group?(group), "staff-created group owner can manage membership")
  private_category = Category.create!(name: "Company research #{SecureRandom.hex(4)}", user: Discourse.system_user)
  private_category.set_permissions(group.name => :full)
  private_category.save!
  assert!(owner.guardian.can_see?(private_category) && !outsider.guardian.can_see?(private_category) && !Guardian.new(nil).can_see?(private_category),
    "private category is visible only to permitted members and staff")

  dm = Chat::CreateDirectMessageChannel.call(guardian: owner.guardian,
    params: { target_usernames: [peer.username, outsider.username], name: "Company research" })
  assert!(dm.success?, "trust-level-one member can create a native group chat")
  channel = dm[:channel]
  assert!(channel.user_chat_channel_memberships.where(user_id: [owner.id, peer.id, outsider.id]).count == 3,
    "group chat contains exactly its invited participants")
  uninvited = member.call
  assert!(!uninvited.guardian.can_preview_chat_channel?(channel), "uninvited member cannot view the private group chat")

  app.delete "/session/#{owner.username}.json", headers: headers
  assert!(app.response.status == 200, "member can log out through the native session endpoint")
  app.post "/bookmarks.json", params: { bookmarkable_id: post.topic_id, bookmarkable_type: "Topic" }, headers: headers
  assert!([403, 422].include?(app.response.status), "logged-out session cannot save bookmarks")
  raise ActiveRecord::Rollback
end
