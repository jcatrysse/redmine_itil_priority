# frozen_string_literal: true

require_relative 'lib/redmine_itil_priority'
require_relative 'lib/redmine_itil_priority/hooks/view_hooks'
require_relative 'lib/redmine_itil_priority/patches/issue_patch'
require_relative 'lib/redmine_itil_priority/patches/issue_query_patch'
require_relative 'lib/redmine_itil_priority/patches/projects_helper_patch'
require_relative 'lib/redmine_itil_priority/patches/setting_patch'
require_relative 'lib/redmine_itil_priority/patches/mail_handler_patch'

# Toggle to enable verbose plugin logging.
RedmineItilPriority.logging_enabled = false

Redmine::Plugin.register :redmine_itil_priority do
  name        'Redmine ITIL Priority'
  description "Replace Redmine's priority with an ITIL Impact × Urgency choice"
  author      'Jan Catrysse'
  url         'https://github.com/jcatrysse/redmine_itil_priority'
  requires_redmine version_or_higher: '5.0.0'
  version '0.0.2'

  project_module :itil_priority do
    permission :manage_itil_priority_settings,
               { itil_priority_settings: [:update],
                 itil_priority_settings_api: [:project, :update_project] },
               require: :member
  end

  settings partial: 'settings/itil_priority',
           default: {
             "label_urgency_1" => "Not urgent", "label_urgency_2" => "Normal", "label_urgency_3" => "Urgent",
             "label_impact_1" => "Low impact", "label_impact_2" => "Medium impact", "label_impact_3" => "Important impact",
             "priority_i1_u1" => 1, "priority_i1_u2" => 2, "priority_i1_u3" => 2,
             "priority_i2_u1" => 2, "priority_i2_u2" => 2, "priority_i2_u3" => 3,
             "priority_i3_u1" => 2, "priority_i3_u2" => 3, "priority_i3_u3" => 3
           }
end

Issue.include RedmineItilPriority::Patches::IssuePatch
IssueQuery.include RedmineItilPriority::Patches::IssueQueryPatch
ProjectsHelper.include RedmineItilPriority::Patches::ProjectsHelperPatch
Setting.include RedmineItilPriority::Patches::SettingPatch
MailHandler.include RedmineItilPriority::Patches::MailHandlerPatch
