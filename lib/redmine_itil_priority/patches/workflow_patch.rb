# frozen_string_literal: true

module RedmineItilPriority
  module Patches
    # Impact and urgency as fields in Administration > Workflow > Fields
    # permissions, read-only or required per role, tracker and status like
    # core's fields. Core then enforces the rules itself (safe attributes and
    # validate_required_fields).
    module WorkflowPatch
      FIELDS = %w[impact_id urgency_id].freeze

      module WorkflowPermissionPatch
        protected

        def validate_field_name
          return if FIELDS.include?(field_name)

          super
        end
      end

      module WorkflowsControllerPatch
        # Added when the page renders, not in #permissions: another plugin
        # (redmine_project_workflows) replaces that action without calling
        # super, and whichever prepends last wins.
        def default_render(*)
          add_itil_priority_fields if action_name == 'permissions'
          super
        end

        private

        def add_itil_priority_fields
          return if @fields.nil? || @fields.any? { |field, _| FIELDS.include?(field) }

          @fields += FIELDS.map { |field| [field, l("field_#{field.delete_suffix('_id')}")] }
        end
      end
    end
  end
end
