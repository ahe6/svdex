# frozen_string_literal: true
require "rails_helper"

RSpec.describe DiscourseSvdex::ListingsController do
  fab!(:user)
  fab!(:other_user) { Fabricate(:user) }
  fab!(:category)
  before { SiteSetting.svdex_listings_category_id = category.id }

  it "limits Home Latest to offerings and staff-published introductions" do
    introductions = Fabricate(:category)
    discussion = Fabricate(:category)
    help = Fabricate(:category)
    SiteSetting.svdex_introductions_category_id = introductions.id
    SiteSetting.svdex_help_category_id = help.id

    offering = Fabricate(:topic, category: category, title: "Northstar offering for investors")
    newcomer = Fabricate(:topic, category: introductions, title: "Welcome Northstar research fund")
    conversation = Fabricate(:topic, category: discussion, title: "General discussion of private capital")
    support = Fabricate(:topic, category: help, title: "How to use SVDEX navigation")

    get "/latest.json"
    expect(response.status).to eq(200)
    ids = response.parsed_body.dig("topic_list", "topics").map { |topic| topic["id"] }
    expect(ids).to include(offering.id, newcomer.id)
    expect(ids).not_to include(conversation.id, support.id)

    get "#{discussion.url}.json"
    expect(response.status).to eq(200)
    expect(response.parsed_body.dig("topic_list", "topics").map { |topic| topic["id"] }).to include(conversation.id)
  end

  it "does not expose staff-only private offering topics in Home" do
    restricted = Fabricate(:category)
    restricted.set_permissions("staff" => :full)
    restricted.save!
    SiteSetting.svdex_private_offerings_category_id = restricted.id
    topic = Fabricate(:topic, category: restricted, title: "Restricted primary financing opportunity")

    get "/latest.json"
    expect(response.status).to eq(200)
    expect(response.parsed_body.dig("topic_list", "topics").map { |row| row["id"] }).not_to include(topic.id)
  end

  it "redirects old browsing links into the native category" do
    get "/listings"
    expect(response).to redirect_to(category.url)
  end

  it "resolves old identifiers only for topics the visitor may see" do
    topic = Fabricate(:topic, category: category)
    topic.custom_fields["svdex_source_id"] = "old-listing"
    topic.save_custom_fields
    get "/listings/old-listing"
    expect(response).to redirect_to(topic.url)
    category.set_permissions(Group::AUTO_GROUPS[:staff] => :full)
    category.save!
    get "/listings/old-listing"
    expect(response.status).to eq(403)
  end

  it "uses the logged-in user's native bookmarks for saved listings" do
    sign_in(user)
    get "/listings/watchlist"
    expect(response).to redirect_to("/u/#{user.username_lower}/activity/bookmarks")
  end

  it "persists fields through native creation and first-post editing" do
    sign_in(user)
    post "/posts.json", params: { title: "Optical laboratory instruments", raw: "Compact optical instruments for laboratory research and independent testing.", category: category.id, svdex_summary: "Compact instruments for laboratories", svdex_terms: "USD 8m pre-money" }
    expect(response.status).to eq(200)
    post_id = response.parsed_body["id"]
    topic = Post.find(post_id).topic
    expect(topic.custom_fields["svdex_terms"]).to eq("USD 8m pre-money")
    put "/posts/#{post_id}.json", params: { post: { raw: Post.find(post_id).raw, svdex_terms: "USD 9m pre-money" } }
    expect(response.status).to eq(200)
    expect(topic.reload.custom_fields["svdex_terms"]).to eq("USD 9m pre-money")
    sign_in(other_user)
    put "/posts/#{post_id}.json", params: { post: { raw: "Attempting to change another author's listing.", svdex_terms: "tampered" } }
    expect(response.status).to eq(403)
    expect(topic.reload.custom_fields["svdex_terms"]).to eq("USD 9m pre-money")
  end
  it "searches listing titles case-insensitively and treats wildcard characters literally" do
    Fabricate(:topic, category: category, title: "Northstar Instruments")
    Fabricate(:topic, category: category, title: "Other company")
    get "#{category.url}.json", params: { svdex_company: "INSTRUMENTS" }
    expect(response.status).to eq(200)
    expect(response.parsed_body.dig("topic_list", "topics").map { |topic| topic["title"] }).to eq(["Northstar Instruments"])
    get "#{category.url}.json", params: { svdex_company: "%" }
    expect(response.parsed_body.dig("topic_list", "topics")).to eq([])
  end

  it "rejects unbounded search input" do
    get "#{category.url}.json", params: { svdex_company: "x" * 121 }
    expect(response.status).to eq(400)
  end

  it "suggests visible listing names without exposing other categories or unlisted topics" do
    Fabricate(:topic, category: category, title: "Northstar Instruments")
    Fabricate(:topic, title: "Northstar outside Listings")
    Fabricate(:topic, category: category, title: "Northstar unlisted", visible: false)
    get "/listings/companies.json", params: { q: "north" }
    expect(response.status).to eq(200)
    expect(response.parsed_body["companies"]).to eq([{ "name" => "Northstar Instruments" }])
    get "/listings/companies.json", params: { q: "%" }
    expect(response.parsed_body["companies"]).to eq([])
    get "/listings/companies.json", params: { q: "x" * 121 }
    expect(response.status).to eq(400)
  end

  it "suggests a company once and filters all of its offering topics" do
    titles = ["Northstar Instruments — Seed", "Northstar Instruments — 2030 Bond"]
    titles.each { |title| Fabricate(:topic, category: category, title: title) }
    Fabricate(:topic, category: category, title: "Northstar Instruments Private — Seed", visible: false)
    get "/listings/companies.json", params: { q: "northstar" }
    expect(response.parsed_body["companies"]).to eq([{ "name" => "Northstar Instruments" }])
    get "#{category.url}.json", params: { svdex_company: "Northstar Instruments" }
    expect(response.parsed_body.dig("topic_list", "topics").map { |topic| topic["title"] }).to match_array(titles)
  end

end
