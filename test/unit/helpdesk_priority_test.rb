# frozen_string_literal: true

require File.expand_path('../test_helper', __dir__)

# Jan, 2026-10-07: "Helpdeskprioriteit behouden". RedmineUP's helpdesk creates
# tickets from mail as the anonymous user, so the Anonymous role's "Override
# ITIL priority" decides whether the helpdesk's configured priority is kept,
# on private projects too, and only while the helpdesk receives mail.
class ItilHelpdeskPriorityTest < ActiveSupport::TestCase
  include RedmineItilPriority::TestHelper
  fixtures(*FIXTURES)

  def setup
    @private = Project.find(2) # onlinestore, private
    assert_not @private.is_public?
    itil_setup(@private)
    @anonymous = User.anonymous
    Role.anonymous.add_permission!(:add_issues)
  end

  def teardown
    Thread.current[:itil_priority_helpdesk_mail] = nil
  end

  def test_anonymous_may_override_only_while_the_helpdesk_receives_mail
    Role.anonymous.add_permission!(:override_itil_priority)
    assert_not RedmineItilPriority.may_override_priority?(@anonymous, @private), 'never outside the helpdesk'
    RedmineItilPriority.helpdesk_mail do
      assert RedmineItilPriority.may_override_priority?(@anonymous, @private)
    end
    assert_not RedmineItilPriority.helpdesk_mail?
  end

  def test_without_the_role_permission_the_helpdesk_may_not_override
    Role.anonymous.remove_permission!(:override_itil_priority)
    RedmineItilPriority.helpdesk_mail do
      assert_not RedmineItilPriority.may_override_priority?(@anonymous, @private)
    end
  end

  def test_logged_in_users_keep_their_own_roles_in_the_helpdesk_too
    Role.anonymous.add_permission!(:override_itil_priority)
    role_without_override(2)
    RedmineItilPriority.helpdesk_mail do
      assert_not RedmineItilPriority.may_override_priority?(User.find(3), @private)
    end
  end

  def test_helpdesk_ticket_keeps_the_configured_priority_with_the_permission
    Role.anonymous.add_permission!(:override_itil_priority)
    issue = new_helpdesk_issue
    assert_equal 7, issue.priority_id
    # no impact and urgency yet: still linked, so classifying it later applies the matrix
    assert_equal [nil, nil, true], [issue.impact_id, issue.urgency_id, issue.itil_priority_linked]
  end

  def test_helpdesk_ticket_gets_the_default_priority_without_the_permission
    Role.anonymous.remove_permission!(:override_itil_priority)
    issue = new_helpdesk_issue
    assert_equal IssuePriority.default.id, issue.priority_id
  end

  private

  # What HelpdeskMailRecipient::IssueRecipient#receive does with the
  # helpdesk's configured priority (User.current is nil there).
  def new_helpdesk_issue
    User.current = nil
    RedmineItilPriority.helpdesk_mail do
      issue = Issue.new(author: @anonymous, project: @private, tracker_id: 1)
      issue.safe_attributes = { 'priority_id' => '7', 'subject' => 'From the helpdesk' }
      issue
    end
  end
end
