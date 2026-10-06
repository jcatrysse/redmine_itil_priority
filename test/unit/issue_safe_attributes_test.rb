# frozen_string_literal: true

require File.expand_path('../test_helper', __dir__)

class ItilIssueSafeAttributesTest < ActiveSupport::TestCase
  include RedmineItilPriority::TestHelper
  fixtures(*FIXTURES)

  def setup
    User.current = nil
    itil_setup
  end

  # Impact and urgency change the priority, so they follow the rule of core's
  # other attributes: whoever may only add notes cannot change them.
  def test_impact_and_urgency_are_not_safe_for_a_user_who_may_only_add_notes
    Role.find(2).remove_permission!(:edit_issues)
    user = User.find(3)
    issue = Issue.find(1)
    assert issue.notes_addable?(user)
    assert_not issue.attributes_editable?(user)

    %w[impact_id urgency_id].each do |name|
      assert_not issue.safe_attribute?(name, user), "#{name} must not be safe"
    end

    priority = issue.priority_id
    issue.init_journal(user)
    issue.safe_attributes = { 'impact_id' => '3', 'urgency_id' => '3', 'notes' => 'Only a note' }, user
    assert_nil issue.impact_id
    assert_nil issue.urgency_id
    assert_equal priority, issue.priority_id
  end

  def test_impact_and_urgency_are_safe_for_a_user_who_may_edit
    user = User.find(3)
    issue = Issue.find(1)
    %w[impact_id urgency_id].each { |name| assert issue.safe_attribute?(name, user) }
  end

  def test_impact_and_urgency_are_safe_on_a_new_issue
    issue = Issue.new(project_id: 1, tracker_id: 1)
    %w[impact_id urgency_id].each { |name| assert issue.safe_attribute?(name, User.find(3)) }
  end
end
