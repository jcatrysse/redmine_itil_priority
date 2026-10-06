class AddItilPriorityLinkedToIssues < ActiveRecord::Migration[5.2]
  # Whether the priority follows the impact x urgency matrix (true) or was set
  # by hand (false). Existing issues stay linked, as the form treated them.
  def change
    add_column :issues, :itil_priority_linked, :boolean, default: true, null: false
  end
end
