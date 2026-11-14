# frozen_string_literal: true
# Capture only the rollback-only prototype's native jobs. Real site hooks remain.
raise "Local checks only" unless GlobalSetting.hostname == "localhost" && SiteSetting.port.to_s == "4080"
module SvdexWorkflowCheckQueue
  class << self
    attr_accessor :pending, :workflow_id
    def drain!
      jobs = self.pending || []
      self.pending = []
      jobs.each do |trigger, data, user_id|
        result = DiscourseWorkflows::Workflow::Execute.call(params: {
          workflow_id: trigger.workflow_id, workflow_version_id: trigger.workflow_version_id,
          trigger_node_id: trigger.trigger_node_id, trigger_data: data, user_id: user_id,
        }.compact)
        raise "Native badge prototype execution failed" unless result.success? && result[:execution].success?
      end
      jobs.length
    end
  end
  module Capture
    def enqueue(trigger, trigger_data:, user_id: nil, run_at: nil)
      return super unless trigger.workflow_id == SvdexWorkflowCheckQueue.workflow_id
      SvdexWorkflowCheckQueue.pending ||= []
      SvdexWorkflowCheckQueue.pending << [trigger, trigger_data, user_id]
    end
  end
end
DiscourseWorkflows::TriggerDispatcher.singleton_class.prepend(SvdexWorkflowCheckQueue::Capture)
