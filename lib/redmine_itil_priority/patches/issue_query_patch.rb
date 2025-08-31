# frozen_string_literal: true

require_dependency 'issue_query'
require 'active_support/concern'

module RedmineItilPriority
  module Patches
    # Patch IssueQuery to expose impact and urgency.
    module IssueQueryPatch
      RedmineItilPriority.log('[ITIL] IssueQueryPatch included')
      extend ActiveSupport::Concern

      included do
        Query.operators_by_filter_type[:list_optional] |= %w[>= <=]
        self.available_columns << QueryColumn.new(
          :impact_id,
          caption: :label_impact,
          sortable: "#{Issue.table_name}.impact_id",
          groupable: "#{Issue.table_name}.impact_id"
        ) do |issue|
          RedmineItilPriority.impact_label(issue)
        end
        self.available_columns << QueryColumn.new(
          :urgency_id,
          caption: :label_urgency,
          sortable: "#{Issue.table_name}.urgency_id",
          groupable: "#{Issue.table_name}.urgency_id"
        ) do |issue|
          RedmineItilPriority.urgency_label(issue)
        end

        alias_method :initialize_available_filters_without_itil_priority, :initialize_available_filters
        def initialize_available_filters
          initialize_available_filters_without_itil_priority
          return unless RedmineItilPriority.enabled_for_project?(project)
          add_available_filter 'impact_id', type: :list_optional, label: :label_impact,
                                       values: RedmineItilPriority.impact_options(project, nil)
          add_available_filter 'urgency_id', type: :list_optional, label: :label_urgency,
                                        values: RedmineItilPriority.urgency_options(project, nil)
        end

        alias_method :available_columns_without_itil_priority, :available_columns
        def available_columns
          cols = available_columns_without_itil_priority
          return cols if RedmineItilPriority.enabled_for_project?(project)
          cols.reject { |c| %i[impact_id urgency_id].include?(c.name) }
        end
      end
    end
  end
end
