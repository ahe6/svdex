# frozen_string_literal: true
# Native workflow prototype only. No installation or runtime activation.
module SvdexPrivateAccessWorkflowPrototype
  def self.graph(group_id:, badge_id:)
    nodes = [
      { id: "membership-added", name: "Member invited", type: "trigger:user_added_to_group", parameters: { group_id: group_id }, position: { x: 0, y: 0 } },
      { id: "membership-removed", name: "Member removed", type: "trigger:user_removed_from_group", parameters: { group_id: group_id }, position: { x: 0, y: 200 } },
      { id: "current-member", name: "Read current membership", type: "action:user", parameters: { operation: "get", username: "={{ $json.user.username }}", actor_username: "system" }, position: { x: 300, y: 100 } },
      { id: "access-badge", name: "Sync achievement", type: "action:badge", parameters: {
        operation: "={{ $json.user.groups.some(group => group.id === #{group_id}) ? 'grant' : 'revoke' }}",
        username: "={{ $json.user.username }}", badge_id: badge_id, actor_username: "system",
      }, position: { x: 600, y: 100 } },
    ]
    connections = {
      "Member invited" => { "main" => [[{ "node" => "Read current membership", "type" => "main", "index" => 0 }]] },
      "Member removed" => { "main" => [[{ "node" => "Read current membership", "type" => "main", "index" => 0 }]] },
      "Read current membership" => { "main" => [[{ "node" => "Sync achievement", "type" => "main", "index" => 0 }]] },
    }
    { nodes: nodes, connections: connections }
  end
end
