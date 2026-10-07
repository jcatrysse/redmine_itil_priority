# frozen_string_literal: true

module RedmineItilPriority
  module Patches
    # RedmineUP helpdesk (redmine_contacts_helpdesk): new tickets from mail.
    module HelpdeskPatch
      # Marks the receiving so that RedmineItilPriority.may_override_priority?
      # can let the Anonymous role's "Override ITIL priority" count, and the
      # ticket keeps the helpdesk's configured priority.
      module IssueRecipientPatch
        def receive
          RedmineItilPriority.helpdesk_mail { super }
        end
      end
    end
  end
end
