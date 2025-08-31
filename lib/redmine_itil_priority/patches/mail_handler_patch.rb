# frozen_string_literal: true

require_dependency 'mail_handler'
require 'active_support/concern'

module RedmineItilPriority
  module Patches
    # Patch MailHandler to parse Impact and Urgency from emails.
    module MailHandlerPatch
      RedmineItilPriority.log('[ITIL] MailHandlerPatch included')
      extend ActiveSupport::Concern

      included do
        alias_method :issue_attributes_from_keywords_without_itil_priority, :issue_attributes_from_keywords
        alias_method :issue_attributes_from_keywords, :issue_attributes_from_keywords_with_itil_priority
      end

      # Returns a Hash of issue attributes extracted from keywords in the email body.
      # Adds support for Impact, Urgency and the linking flag.
      def issue_attributes_from_keywords_with_itil_priority(issue)
        attrs = issue_attributes_from_keywords_without_itil_priority(issue)
        project = issue.project
        tracker_id = attrs['tracker_id'] || issue.tracker_id || issue.tracker&.id
        tracker = nil

        if project.respond_to?(:trackers)
          tracker = project.trackers.find { |t| t.id == tracker_id } if tracker_id
          tracker ||= project.trackers.first
          tracker_id ||= tracker&.id
        end

        RedmineItilPriority.log("[ITIL] MailHandler: project=#{project&.identifier} tracker=#{tracker_id}")

        if tracker && RedmineItilPriority.settings_for(project, tracker)
          if (k = get_keyword(:impact))
            opts = RedmineItilPriority.impact_options(project, tracker)
            if (pair = opts.find { |label, _id| label.casecmp?(k) })
              attrs['impact_id'] = pair.last
              RedmineItilPriority.log("[ITIL] MailHandler: impact '#{k}' -> #{pair.last}")
            else
              RedmineItilPriority.log("[ITIL] MailHandler: unknown impact '#{k}'")
            end
          end
          if (k = get_keyword(:urgency))
            opts = RedmineItilPriority.urgency_options(project, tracker)
            if (pair = opts.find { |label, _id| label.casecmp?(k) })
              attrs['urgency_id'] = pair.last
              RedmineItilPriority.log("[ITIL] MailHandler: urgency '#{k}' -> #{pair.last}")
            else
              RedmineItilPriority.log("[ITIL] MailHandler: unknown urgency '#{k}'")
            end
          end
          unless (k = get_keyword_bool(:itil_priority_linked)).nil?
            attrs['itil_priority_linked'] = k ? '1' : '0'
            RedmineItilPriority.log("[ITIL] MailHandler: itil_priority_linked=#{k}")
          end
        else
          RedmineItilPriority.log("[ITIL] MailHandler: ITIL priority disabled for project=#{project&.identifier} tracker=#{tracker_id}")
        end
        attrs
      end
    end
  end
end

