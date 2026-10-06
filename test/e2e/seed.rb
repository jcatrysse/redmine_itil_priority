# Plugin data for the end-to-end scenarios, run by .codex/start_server.sh after
# the generic seed. Idempotent.
#
# - the matrix maps to the priorities by name (Low, Normal, High, Urgent, Immediate)
# - a help text for impact (none for urgency: the icon must only show with a text)
# - role "Reporter" plays the helpdesk role: it may edit issues but must not
#   override the priority, so the "override ITIL priority" permission that
#   migration 004 granted it on upgrade is taken away here, as the "After the
#   upgrade" section of docs/REDMINE7-MIGRATION.md asks for helpdesk roles
# - incoming mail through /mail_handler with key "e2e-mail-key"
# - webhooks enabled
prio = IssuePriority.all.index_by(&:name)
id = ->(name) { (prio[name] || IssuePriority.default).id.to_s }

Setting.plugin_redmine_itil_priority = {
  'default_tracker_mode' => 'default',
  'label_urgency_1' => 'Not urgent', 'label_urgency_2' => 'Normal', 'label_urgency_3' => 'Urgent',
  'label_impact_1' => 'Low impact', 'label_impact_2' => 'Medium impact', 'label_impact_3' => 'Important impact',
  'priority_i1_u1' => id['Low'],    'priority_i1_u2' => id['Low'],    'priority_i1_u3' => id['Normal'],
  'priority_i2_u1' => id['Low'],    'priority_i2_u2' => id['Normal'], 'priority_i2_u3' => id['High'],
  'priority_i3_u1' => id['Normal'], 'priority_i3_u2' => id['High'],   'priority_i3_u3' => id['Urgent'],
  'help_impact' => "* *Low impact*: one user\n* *Medium impact*: a team\n* *Important impact*: the whole company",
  'help_urgency' => ''
}

reporter = Role.find_by(name: 'Reporter')
if reporter
  reporter.add_permission!(:edit_issues) unless reporter.has_permission?(:edit_issues)
  reporter.remove_permission!(:override_itil_priority) if reporter.has_permission?(:override_itil_priority)
end

project = Project.find_by(identifier: 'e2e-project')
Setting.where(name: "plugin_redmine_itil_priority_project_#{project.id}").delete_all if project
WorkflowPermission.where(field_name: %w[impact_id urgency_id]).delete_all

Setting.mail_handler_api_enabled = '1'
Setting.mail_handler_api_key = 'e2e-mail-key'
Setting.webhooks_enabled = '1'
RedmineItilPriority.clear_cache

puts "ITIL seed: matrix by priority name, Reporter without override (#{reporter&.has_permission?(:override_itil_priority).inspect}), " \
     "Manager with override (#{Role.find_by(name: 'E2E full')&.has_permission?(:override_itil_priority).inspect})"
