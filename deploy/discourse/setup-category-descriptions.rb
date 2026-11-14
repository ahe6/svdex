# frozen_string_literal: true
abort "Local setup only" unless GlobalSetting.hostname == "localhost" && SiteSetting.port.to_s == "4080"
actor = User.find_by!(username: "svdex")
{
  "offerings" => "Explore financing rounds and securities offered by companies. Review disclosed terms and discuss each opportunity.",
  "discussion" => "Share company research, market insights and community conversation. Discuss companies, investing and private markets.",
}.each do |slug, description|
  category = Category.find_by!(slug: slug)
  post = category.topic.first_post
  unless post.raw == description
    revisor = PostRevisor.new(post)
    raise post.errors.full_messages.join(", ") unless revisor.revise!(actor, { raw: description })
  end
  raise "Description did not sync" if category.reload.description.blank?
  puts "#{category.name}: #{category.description}"
end
