# frozen_string_literal: true

abort "Local only" unless GlobalSetting.hostname == "localhost" && SiteSetting.port.to_s == "4080"

class ProposalGithubFixture
  attr_reader :writes, :pulls
  attr_accessor :fail_pull

  def initialize
    @trees = { "main" => {}, "a" * 40 => {} }
    @writes = []
    @pulls = {}
  end

  def get(path, missing: false)
    route, query = path.split("?", 2)
    params = URI.decode_www_form(query.to_s).to_h
    case route
    when %r{\A/contents/}
      @trees.fetch(params.fetch("ref"))[route]
    when "/git/ref/heads/main"
      { "object" => { "sha" => "a" * 40 } }
    when %r{\A/git/ref/heads/}
      @trees[route.delete_prefix("/git/ref/heads/")]
    when "/pulls"
      [@pulls[params.fetch("head").delete_prefix("ahe6:")]].compact
    else
      raise "Unexpected GET #{path}"
    end
  end

  def post(path, data)
    if path == "/git/refs"
      @trees[data.fetch(:ref).delete_prefix("refs/heads/")] = @trees.fetch(data.fetch(:sha)).dup
    elsif path == "/pulls"
      raise "Wrong base" unless data[:base] == "main"
      if @fail_pull
        @fail_pull = false
        raise DiscourseSvdex::CatalogGithub::Unavailable
      end
      @pulls[data.fetch(:head)] = { "number" => @pulls.length + 1 }
    else
      raise "Unexpected POST #{path}"
    end
  end

  def put(path, data)
    branch = data.fetch(:branch)
    raise "Wrong branch" unless branch.start_with?("directory-proposals/")
    @writes << [path, data]
    store(branch, path, data.fetch(:content))
  end

  def seed(path, text)
    ["main", "a" * 40].each { |branch| store(branch, path, Base64.strict_encode64(text)) }
  end

  private

  def store(branch, path, content)
    @trees.fetch(branch)[path] = { "encoding" => "base64", "content" => content, "sha" => Digest::SHA1.hexdigest(content) }
  end
end

def proposal_rejects(error)
  yield
  raise "Expected #{error}"
rescue error
  true
end

service = DiscourseSvdex::CatalogProposals
fixture = ProposalGithubFixture.new
proposals = service.new("people", github: fixture)
document = { "schema_version" => 1, "id" => "person-a", "name" => "Name", "summary" => "Public background.",
             "tag" => "person-a", "sector" => nil, "location" => nil, "facts" => { "role" => "Researcher" },
             "sources" => [{ "url" => "https://example.org/source", "note" => "Public profile." }] }
fixture.fail_pull = true
proposal_rejects(DiscourseSvdex::CatalogGithub::Unavailable) { proposals.submit(document.to_json) }
result = proposals.submit(document.to_json)
raise "Retry did not reuse existing PR" unless proposals.submit(document.to_json) == result && fixture.pulls.length == 1 && fixture.writes.length == 1
path, payload = fixture.writes.first
raise "Wrong single-file payload" unless path == "/contents/directory/people/person-a.json" && JSON.parse(Base64.decode64(payload.fetch(:content))) == document
raise "Unexpected write to main" if fixture.get("#{path}?ref=main")

fixture.seed(path, document.to_json)
draft = proposals.draft("person-a")
raise "Draft did not return current file" unless JSON.parse(draft.fetch(:document)) == document
edited = document.merge("summary" => "Updated from a public source.")
proposal_rejects(service::Conflict) { proposals.submit(edited.to_json) }
proposal_rejects(service::Conflict) { proposals.submit(edited.to_json, id: "person-a", sha: "b" * 40) }
proposal_rejects(service::Document::Invalid) { proposals.submit(edited.merge("email" => "private@example.org").to_json) }
proposal_rejects(service::Document::Invalid) { proposals.submit(edited.merge("id" => "../code").to_json) }
proposal_rejects(service::Document::Invalid) { proposals.submit(edited.to_json, id: "person-b", sha: draft.fetch(:sha)) }
proposal_rejects(service::Document::Invalid) { proposals.submit(edited.to_json.sub('{', '{"id":"duplicate",')) }
proposal_rejects(service::Conflict) { proposals.submit(document.to_json, id: "person-a", sha: draft.fetch(:sha)) }
proposals.submit(edited.to_json, id: "person-a", sha: draft.fetch(:sha))
raise "Edit did not use compare-and-swap revision" unless fixture.writes.last.last[:sha] == draft.fetch(:sha) && fixture.writes.length == 2
puts "PASS directory proposals validate public data, write a single file, recover partial failures, and reject stale edits"

securities = service.new("securities", github: fixture)
security = document.merge("id" => "public-security", "tag" => nil,
  "facts" => { "description" => "Terms from a public filing.", "instrument_type" => "debt" })
proposal_rejects(service::Document::Invalid) { securities.submit(security.to_json) }
category = DiscourseSvdex::SecuritiesDirectory.public_category
Topic.transaction do
  actor = User.find_by!(username: "svdex")
  topic = PostCreator.create!(actor, title: "Public offering #{SecureRandom.hex(5)}",
    raw: "Existing public offering for the reviewed directory.", category: category.id,
    skip_validations: true, skip_jobs: true).topic
  securities.submit(security.merge("facts" => security["facts"].merge("topic_id" => topic.id)).to_json)
  raise ActiveRecord::Rollback
end
raise "Securities did not use the shared proposal writer" unless fixture.writes.last.first == "/contents/directory/securities/public-security.json"
written = fixture.writes.size
unavailable_topic = security.merge("facts" => security["facts"].merge("topic_id" => 2_147_483_647))
proposal_rejects(service::Document::Invalid) { securities.submit(unavailable_topic.to_json) }
raise "Unavailable topic reference was sent to GitHub" unless fixture.writes.size == written
puts "PASS Securities uses the same GitHub writer and rejects nonpublic topic references before writing"

service.define_singleton_method(:enabled?) { true }
DiscourseSvdex::CatalogGithub.define_singleton_method(:new) { fixture }
guest = ActionDispatch::Integration::Session.new(Rails.application)
guest.host! "localhost"
guest.get "/directory-proposals/people/person-a.json"
raise "Guest can read through the bot" unless guest.response.status == 403

User.transaction do
  password = SecureRandom.hex(24)
  user = User.create!(username: "catalog_#{SecureRandom.hex(5)}", email: "#{SecureRandom.hex(10)}@example.invalid",
    password: password, active: true, approved: true)
  user.email_tokens.update_all(confirmed: true)
  session = ActionDispatch::Integration::Session.new(Rails.application)
  session.host! "localhost"
  session.get "/session/csrf.json"
  headers = { "X-CSRF-Token" => session.response.parsed_body.fetch("csrf"), "HTTP_ACCEPT" => "application/json", "X-Requested-With" => "XMLHttpRequest" }
  session.post "/session.json", params: { login: user.username, password: password }, headers: headers
  raise "Login failed" unless session.response.status == 200
  session.get "/directory-proposals/people/person-a.json", headers: headers
  raise "Draft request failed" unless session.response.status == 200 && session.response.parsed_body.fetch("sha") == draft.fetch(:sha)
  session.put "/directory-proposals/people/person-a.json", headers: headers, as: :json, params: { document: edited.to_json, sha: draft.fetch(:sha) }
  unless session.response.status == 201 && session.response.parsed_body.fetch("url") == "https://github.com/ahe6/svdex/pull/2"
    raise "Proposal request failed (#{session.response.status})"
  end
  session.post "/directory-proposals/people.json", headers: headers, as: :json, params: { document: "{invalid" }
  raise "Malformed file was accepted" unless session.response.status == 422
  raise ActiveRecord::Rollback
end
puts "PASS signed-in members can read and submit drafts; guests and malformed requests are rejected"
