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
        safe_attributes 'impact_id', 'urgency_id', 'itil_priority_linked'
        attr_accessor :itil_priority_linked
      end

      def itil_priority_active?
        itil_priority_linked.to_s != '0'
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

      private

      def settings_for_mapping
        project = respond_to?(:project) ? self.project : nil
        tracker = respond_to?(:tracker) ? self.tracker : nil
        RedmineItilPriority.settings_for(project, tracker)
      end
    end
  end
end
