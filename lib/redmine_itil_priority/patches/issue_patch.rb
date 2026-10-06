# frozen_string_literal: true
require_dependency 'issue'
require 'active_support/concern'

module RedmineItilPriority
  module Patches
    # Patch the Issue model to map impact/urgency to priorities.
    module IssuePatch
      RedmineItilPriority.log('[ITIL] IssuePatch included')
      extend ActiveSupport::Concern

      included do
        # Same condition as core's priority_id: impact and urgency change the priority.
        safe_attributes 'impact_id', 'urgency_id', 'itil_priority_linked',
                        if: lambda { |issue, user| issue.new_record? || issue.attributes_editable?(user) }
        prepend PrependedMethods
      end

      # itil_priority_linked is a boolean column: '0', 'false' and false unlink,
      # anything else (blank included) links.
      def self.linked_value(value)
        !%w[0 false f off no].include?(value.to_s.strip.downcase)
      end

      def itil_priority_active?
        IssuePatch.linked_value(itil_priority_linked)
      end

      # Linking again recalculates the priority from impact and urgency.
      def itil_priority_linked=(value)
        linked = IssuePatch.linked_value(value)
        write_attribute(:itil_priority_linked, linked)
        return unless linked && impact_id && urgency_id

        settings = settings_for_mapping
        priority = settings && settings["priority_i#{impact_id}_u#{urgency_id}"]
        write_attribute(:priority_id, priority) if priority.present?
      end

      def urgency_id=(pid)
        pid = nil if pid.blank? || pid == 'none'
        write_attribute(:urgency_id, pid)
        return unless itil_priority_active?
        return if pid.nil? || impact_id.nil?

        settings = settings_for_mapping
        write_attribute(:priority_id, settings["priority_i#{impact_id}_u#{pid}"]) if settings
      end

      def impact_id=(pid)
        pid = nil if pid.blank? || pid == 'none'
        write_attribute(:impact_id, pid)
        return unless itil_priority_active?
        return if pid.nil? || urgency_id.nil?

        settings = settings_for_mapping
        write_attribute(:priority_id, settings["priority_i#{pid}_u#{urgency_id}"]) if settings
      end

      # rubocop:disable Metrics/MethodLength, Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
      def priority_id=(pid)
        self.priority = nil
        write_attribute(:priority_id, pid)
        return unless itil_priority_active?

        settings = settings_for_mapping
        return unless settings

        priority = settings["priority_i#{impact_id}_u#{urgency_id}"] if impact_id && urgency_id
        return unless priority.nil? || pid != priority

        (1..3).each do |i|
          (1..3).each do |u|
            next unless pid == settings["priority_i#{i}_u#{u}"]

            write_attribute(:urgency_id, u)
            write_attribute(:impact_id, i)
          end
        end
      end
      # rubocop:enable Metrics/MethodLength, Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity

      module PrependedMethods
        # Where ITIL priority is active, only a user with the permission
        # "override ITIL priority" sets the priority itself or unlinks it; the
        # others set impact and urgency and the priority follows the matrix.
        # A priority made read-only by the workflow cannot be unlinked either.
        # Through safe attributes this holds for the form, bulk edit, context
        # menu, REST API and incoming mail alike.
        # Where ITIL priority is inactive (module off, tracker inactive) the
        # plugin's fields are not shown, so they are not assignable either.
        def safe_attribute_names(user = nil)
          names = super
          return names unless (names & %w[priority_id itil_priority_linked impact_id urgency_id]).any?
          return names - %w[impact_id urgency_id itil_priority_linked] unless RedmineItilPriority.settings_for(project, tracker)

          unless names.include?('priority_id') && (user || User.current).allowed_to?(:override_itil_priority, project)
            names -= %w[priority_id itil_priority_linked]
          end
          names
        end

        # The setters recalculate as they are called, so the result must not
        # depend on the order a form, an API client or a mail sends: the link
        # flag first, the priority last.
        def safe_attributes=(attrs, user = User.current)
          attrs = attrs.to_unsafe_hash if attrs.respond_to?(:to_unsafe_hash)
          if attrs.is_a?(Hash) && (attrs.key?('itil_priority_linked') || attrs.key?('priority_id'))
            attrs = attrs.slice('itil_priority_linked').
                      merge(attrs.except('itil_priority_linked', 'priority_id')).
                      merge(attrs.slice('priority_id'))
          end
          super
          itil_priority_after_assignment(attrs, user)
        end

        # Impact and urgency required by the workflow only where they are shown.
        def required_attribute_names(user = nil)
          names = super
          return names if (names & %w[impact_id urgency_id]).empty?
          return names if RedmineItilPriority.settings_for(project, tracker)

          names - %w[impact_id urgency_id]
        end

        # Redmine 7 webhooks render core's issues/show.api.rsb from Rails.root,
        # past the plugin's override; render the plugin's, so the payload has
        # impact, urgency and the link like the REST API.
        def webhook_payload_api_template
          File.expand_path('../../../app/views/issues/show.api.rsb', __dir__)
        end

        # Core copies the attributes in column order, so impact and urgency,
        # assigned after the priority, recalculate it. A copy of an issue
        # whose priority was set by hand keeps that priority.
        def copy_from(arg, options = {})
          super
          source = @copied_from
          if source.respond_to?(:itil_priority_active?) && !source.itil_priority_active?
            write_attribute(:itil_priority_linked, false)
            write_attribute(:priority_id, source.priority_id)
          end
          self
        end
      end

      private

      # Core's own Issue#priority_id= shadows the setter above, so a priority
      # set directly (context menu, bulk edit, REST API) is written as is. On
      # a linked issue that differs from the matrix: an explicit link wins and
      # gets the matrix priority; otherwise the priority was set by hand and
      # the issue is unlinked, so the next edit does not undo it.
      def itil_priority_after_assignment(attrs, user)
        return unless attrs.is_a?(Hash) && attrs.key?('priority_id') && safe_attribute?('priority_id', user)
        return unless itil_priority_active? && impact_id && urgency_id

        settings = settings_for_mapping
        computed = settings && settings["priority_i#{impact_id}_u#{urgency_id}"]
        return if computed.blank? || computed.to_s == priority_id.to_s

        if attrs.key?('itil_priority_linked')
          self.priority_id = computed
        else
          write_attribute(:itil_priority_linked, false)
        end
      end

      def settings_for_mapping
        project = respond_to?(:project) ? self.project : nil
        tracker = respond_to?(:tracker) ? self.tracker : nil
        RedmineItilPriority.settings_for(project, tracker)
      end
    end
  end
end
