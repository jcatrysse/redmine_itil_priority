# frozen_string_literal: true

# Tests against a real Redmine (fixtures, database), next to the stand-alone
# specs in spec/. Run with ./.codex/test_plugin.sh.
require File.expand_path('../../../test/test_helper', __dir__)

module RedmineItilPriority
  module TestHelper
    FIXTURES = %i[
      projects users email_addresses user_preferences roles members member_roles
      trackers projects_trackers enabled_modules issue_statuses issues enumerations
      workflows journals journal_details custom_fields custom_values
      custom_fields_projects custom_fields_trackers versions issue_categories watchers
    ].freeze

    # Priorities of the core fixtures: 4 Low, 5 Normal (default), 6 High,
    # 7 Urgent, 8 Immediate.
    MATRIX = {
      'priority_i1_u1' => '4', 'priority_i1_u2' => '4', 'priority_i1_u3' => '5',
      'priority_i2_u1' => '4', 'priority_i2_u2' => '5', 'priority_i2_u3' => '6',
      'priority_i3_u1' => '5', 'priority_i3_u2' => '6', 'priority_i3_u3' => '7'
    }.freeze

    LABELS = {
      'label_impact_1' => 'Low impact', 'label_impact_2' => 'Medium impact', 'label_impact_3' => 'Important impact',
      'label_urgency_1' => 'Not urgent', 'label_urgency_2' => 'Normal', 'label_urgency_3' => 'Urgent'
    }.freeze

    # Enables the module on the project and the generic matrix for its trackers.
    def itil_setup(project = Project.find(1), extra = {})
      project.enable_module!(:itil_priority)
      Setting.plugin_redmine_itil_priority = LABELS.merge(MATRIX).merge('default_tracker_mode' => 'default').merge(extra)
      RedmineItilPriority.clear_cache
      project
    end

    def role_without_override(role_id)
      role = Role.find(role_id)
      role.remove_permission!(:override_itil_priority)
      role
    end

    def role_with_override(role_id)
      role = Role.find(role_id)
      role.add_permission!(:override_itil_priority) unless role.has_permission?(:override_itil_priority)
      role
    end
  end
end
