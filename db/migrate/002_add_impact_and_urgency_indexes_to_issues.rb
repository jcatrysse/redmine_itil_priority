class AddImpactAndUrgencyIndexesToIssues < ActiveRecord::Migration[4.2]
  def change
    add_index :issues, :impact_id
    add_index :issues, :urgency_id
    add_index :issues, [:impact_id, :urgency_id]
  end
end
