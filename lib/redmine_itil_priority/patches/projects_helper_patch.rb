# frozen_string_literal: true

module RedmineItilPriority
  module Patches
    module ProjectsHelperPatch
      RedmineItilPriority.log('[ITIL] ProjectsHelperPatch included')
      def self.included(base)
        base.class_eval do
          alias_method :project_settings_tabs_without_itil_priority, :project_settings_tabs
          alias_method :project_settings_tabs, :project_settings_tabs_with_itil_priority
        end
      end

      # Redmine calls this to build tabs on /projects/:id/settings
      def project_settings_tabs_with_itil_priority
        tabs = project_settings_tabs_without_itil_priority
        project = @project
        unless project
          RedmineItilPriority.log('[ITIL] project_settings_tabs: no @project')
          return tabs
        end
        enabled = project.module_enabled?(:itil_priority)
        allowed = User.current.allowed_to?(:manage_itil_priority_settings, project)
        RedmineItilPriority.log("[ITIL] project_settings_tabs: project=#{project.identifier} enabled=#{enabled} allowed=#{allowed} tabs_before=#{tabs.map { |t| t[:name] }.inspect}")
        if enabled && allowed
          tabs << {
            name: 'itil_priority',
            partial: 'projects/settings/itil_priority', # MUST exist (see step A.3)
            label: :label_itil_priority
          }
          RedmineItilPriority.log("[ITIL] project_settings_tabs: injected ITIL tab for project=#{project.identifier}")
        else
          RedmineItilPriority.log("[ITIL] project_settings_tabs: skipping (enabled=#{enabled}, allowed=#{allowed})")
        end
        tabs
      end
    end
  end
end

