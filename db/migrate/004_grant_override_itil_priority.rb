class GrantOverrideItilPriority < ActiveRecord::Migration[5.2]
  # Before this permission existed, everyone who could add or edit issues could
  # set the priority by hand. Grant it to those roles so nothing changes on
  # upgrade; remove it afterwards from the roles that must not override (helpdesk).
  ISSUE_PERMISSIONS = %i[add_issues edit_issues edit_own_issues].freeze

  def up
    Role.reset_column_information
    Role.find_each do |role|
      next if role.has_permission?(:override_itil_priority)
      next unless ISSUE_PERMISSIONS.any? { |permission| role.has_permission?(permission) }

      role.add_permission!(:override_itil_priority)
    end
  end

  def down
    Role.reset_column_information
    Role.find_each do |role|
      role.remove_permission!(:override_itil_priority) if role.has_permission?(:override_itil_priority)
    end
  end
end
