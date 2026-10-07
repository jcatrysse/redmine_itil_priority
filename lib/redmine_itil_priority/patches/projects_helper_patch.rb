# frozen_string_literal: true

module RedmineItilPriority
  module Patches
    # Added to ProjectsController's helpers (init.rb), above ProjectsHelper and
    # outside it: never alias_method (an alias chain mixed with other plugins'
    # prepends recurses), and not prepended to ProjectsHelper either (a plugin
    # that alias-chains the method afterwards copies the prepended method, whose
    # super then finds nothing). Either way Project > Settings answered HTTP 500
    # with all GEOxyz plugins installed.
    module ProjectsHelperPatch
      RedmineItilPriority.log('[ITIL] ProjectsHelperPatch added to ProjectsController helpers')

      # Redmine calls this to build tabs on /projects/:id/settings
      def project_settings_tabs
        tabs = super
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

