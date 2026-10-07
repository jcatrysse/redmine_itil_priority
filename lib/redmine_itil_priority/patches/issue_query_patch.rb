# frozen_string_literal: true

require_dependency 'issue_query'
require 'active_support/concern'

module RedmineItilPriority
  module Patches
    # Patch IssueQuery to expose impact and urgency.
    module IssueQueryPatch
      RedmineItilPriority.log('[ITIL] IssueQueryPatch prepended')

      # Prepended, never alias_method: other GEOxyz plugins prepend on the
      # same two methods (see ProjectsHelperPatch).
      def self.prepended(base)
        base.class_eval do
          Query.operators_by_filter_type[:list_optional] |= %w[>= <=]
          # Core's QueryColumn ignores a block and shows the raw 1..3; this one
          # shows the label (list, CSV, PDF and group headers alike).
          label_column = Class.new(QueryColumn) do
            def initialize(name, options = {}, &block)
              super(name, options)
              @label_block = block
            end

            def value(object)
              @label_block.call(object)
            end

            def value_object(object)
              value(object)
            end
          end
          self.available_columns << label_column.new(
            :impact_id,
            caption: :label_impact,
            sortable: "#{Issue.table_name}.impact_id",
            groupable: "#{Issue.table_name}.impact_id"
          ) do |issue|
            RedmineItilPriority.impact_label(issue)
          end
          self.available_columns << label_column.new(
            :urgency_id,
            caption: :label_urgency,
            sortable: "#{Issue.table_name}.urgency_id",
            groupable: "#{Issue.table_name}.urgency_id"
          ) do |issue|
            RedmineItilPriority.urgency_label(issue)
          end
        end
      end

      def initialize_available_filters
        super
        return unless RedmineItilPriority.enabled_for_project?(project)

        add_available_filter 'impact_id', type: :list_optional, label: :label_impact,
                                          values: RedmineItilPriority.impact_options(project, nil)
        add_available_filter 'urgency_id', type: :list_optional, label: :label_urgency,
                                           values: RedmineItilPriority.urgency_options(project, nil)
      end

      def available_columns
        cols = super
        return cols if RedmineItilPriority.enabled_for_project?(project)

        cols.reject { |c| %i[impact_id urgency_id].include?(c.name) }
      end
    end
  end
end
