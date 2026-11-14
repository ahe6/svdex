# frozen_string_literal: true
# Native replacement feasibility check. Nothing is activated on the real site.
abort "Local verification only" unless GlobalSetting.hostname == "localhost" && SiteSetting.port.to_s == "4080"
require_relative "native-workflow-check-helper"
require_relative "svdex-prototypes/private-access-workflow"
def assert_workflow!(condition, message)
  raise message unless condition
  puts "PASS #{message}"
end

def make_workflow_prototype(actor, graph)
  result = DiscourseWorkflows::Workflow::Create.call(guardian: actor.guardian, params: { name: "SVDEX Private Access #{SecureRandom.hex(3)}", **graph })
  raise "Native prototype creation failed" unless result.success?
  workflow = result[:workflow]
  result = DiscourseWorkflows::Workflow::Publish.call(guardian: actor.guardian, params: { workflow_id: workflow.id })
  raise "Native prototype publish failed" unless result.success?
  workflow.reload
end

before = [User.count, UserBadge.count, DiscourseWorkflows::Workflow.count, SiteSetting.enable_discourse_workflows]
begin
  User.transaction do
    SiteSetting.enable_discourse_workflows = true
    SiteSetting.discourse_workflows_max_executions_per_minute = 100
    SiteSetting.discourse_workflows_max_executions_per_minute_per_workflow = 100
    actor = User.find_by!(username: "svdex")
    group = Group.find_by!(name: SiteSetting.svdex_private_offerings_group_name)
    badge = Badge.find_by!(name: "Private Access")
    category = Category.find(SiteSetting.svdex_private_offerings_category_id)
    graph = SvdexPrivateAccessWorkflowPrototype.graph(group_id: group.id, badge_id: badge.id)
    workflow = make_workflow_prototype(actor, graph)
    SvdexWorkflowCheckQueue.workflow_id = workflow.id
    assert_workflow!(workflow.nodes.none? { |node| node['type'].include?('code') || node['type'].include?('http') }, "native badge prototype needs only membership, user and badge nodes")
    user = User.create!(username: "workflow_#{SecureRandom.hex(4)}", email: "#{SecureRandom.hex(8)}@example.invalid", password: SecureRandom.hex(24), active: true, approved: true, trust_level: 1)
    group.add(user)
    assert_workflow!(UserBadge.exists?(user: user, badge: badge), "retained synchronous hook grants the badge without depending on Workflows")
    UserBadge.where(user: user, badge: badge).find_each { |grant| BadgeGranter.revoke(grant) }
    assert_workflow!(SvdexWorkflowCheckQueue.drain! == 1 && UserBadge.exists?(user: user, badge: badge), "native workflow can independently grant the badge")
    group.remove(user)
    assert_workflow!(!Guardian.new(user.reload).can_see?(category), "native group removal immediately revokes category access")
    BadgeGranter.grant(badge, user)
    assert_workflow!(SvdexWorkflowCheckQueue.drain! == 1 && !UserBadge.exists?(user: user, badge: badge), "native workflow can independently revoke the badge")
    group.add(user)
    group.remove(user)
    assert_workflow!(SvdexWorkflowCheckQueue.drain! == 2 && !UserBadge.exists?(user: user, badge: badge), "delayed invitation events check current membership")
    group.add(user)
    SvdexWorkflowCheckQueue.drain!
    group.remove(user)
    group.add(user)
    assert_workflow!(SvdexWorkflowCheckQueue.drain! == 2 && UserBadge.where(user: user, badge: badge).count == 1, "delayed removal events preserve a renewed invitation")
    group.remove(user)
    SvdexWorkflowCheckQueue.drain!
    BadgeGranter.grant(badge, user)
    assert_workflow!(!Guardian.new(user.reload).can_see?(category), "achievement ownership never grants private category access")

    # Force a small native budget on an isolated workflow to prove saturation
    # without generating a batch of accounts or changing production limits.
    burst = make_workflow_prototype(actor, graph)
    SiteSetting.discourse_workflows_max_executions_per_minute_per_workflow = 1
    statuses = 2.times.map do
      result = DiscourseWorkflows::Workflow::Execute.call(params: { workflow_id: burst.id, workflow_version_id: burst.active_version_id, trigger_node_id: 'membership-added', trigger_data: { user: { username: user.username } } })
      raise "Rate-limit prototype failed" unless result.success?
      result[:execution].status
    end
    assert_workflow!(statuses == %w[success rate_limited], "native workflow saturation records a rate-limited execution rather than applying its badge update")
    raise ActiveRecord::Rollback
  end
ensure
  SvdexWorkflowCheckQueue.workflow_id = nil
  SvdexWorkflowCheckQueue.pending = []
  SiteSetting.refresh!
  DiscourseWorkflows::Workflow::Action::ExpireCaches.call
end
assert_workflow!(before == [User.count, UserBadge.count, DiscourseWorkflows::Workflow.count, SiteSetting.enable_discourse_workflows], "prototype rolls back every account, badge, workflow and feature-setting change")
