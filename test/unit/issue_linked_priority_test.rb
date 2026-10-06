# frozen_string_literal: true

require File.expand_path('../test_helper', __dir__)

class ItilIssueLinkedPriorityTest < ActiveSupport::TestCase
  include RedmineItilPriority::TestHelper
  fixtures(*FIXTURES)

  def setup
    User.current = User.find(2)
    itil_setup
    role_with_override(1)
  end

  def unlinked_issue
    issue = Issue.find(1)
    issue.init_journal(User.current)
    issue.safe_attributes = { 'urgency_id' => '3', 'impact_id' => '3', 'itil_priority_linked' => '0',
                              'priority_id' => '4' }
    issue.save!
    issue.reload
  end

  def test_existing_issues_are_linked
    assert Issue.find(1).itil_priority_linked
    assert Issue.find(1).itil_priority_active?
  end

  def test_linked_issue_follows_the_matrix
    issue = Issue.find(1)
    issue.safe_attributes = { 'urgency_id' => '3', 'impact_id' => '2' }
    assert_equal 6, issue.priority_id
    issue.save!
    assert_equal 6, issue.reload.priority_id
  end

  def test_unlinked_priority_is_saved_and_kept
    issue = unlinked_issue
    assert_equal false, issue.itil_priority_linked
    assert_equal 4, issue.priority_id
    assert_equal 3, issue.impact_id
    assert_equal 3, issue.urgency_id
  end

  # The form sends impact and urgency on every save; before the flag was
  # stored, editing an unlinked issue recalculated its priority.
  def test_unlinked_priority_survives_a_later_change_of_urgency
    issue = unlinked_issue
    issue.init_journal(User.current)
    issue.safe_attributes = { 'urgency_id' => '1', 'impact_id' => '3', 'notes' => 'later edit' }
    issue.save!
    issue.reload
    assert_equal 4, issue.priority_id
    assert_equal 1, issue.urgency_id
    assert_equal false, issue.itil_priority_linked
  end

  def test_unlinking_does_not_depend_on_the_order_of_the_attributes
    issue = Issue.find(1)
    issue.safe_attributes = { 'priority_id' => '4', 'impact_id' => '3', 'urgency_id' => '3',
                              'itil_priority_linked' => '0' }
    issue.save!
    issue.reload
    assert_equal [4, 3, 3, false], [issue.priority_id, issue.impact_id, issue.urgency_id, issue.itil_priority_linked]
  end

  def test_linking_again_recalculates_the_priority
    issue = unlinked_issue
    issue.safe_attributes = { 'itil_priority_linked' => '1' }
    issue.save!
    issue.reload
    assert issue.itil_priority_linked
    assert_equal 7, issue.priority_id
  end

  # Core copies the attributes in column order; in a production database the
  # plugin's columns come last, the flag after impact and urgency (a schema
  # loaded from schema.rb sorts them, so force that order here).
  def test_copy_of_an_unlinked_issue_keeps_its_priority
    source = unlinked_issue
    def source.attributes
      attrs = super
      attrs.except('itil_priority_linked', 'impact_id', 'urgency_id').
        merge(attrs.slice('impact_id', 'urgency_id', 'itil_priority_linked'))
    end
    copy = Issue.new.copy_from(source)
    assert_equal false, copy.itil_priority_linked
    assert_equal 4, copy.priority_id
    copy.save!
    assert_equal 4, copy.reload.priority_id
  end

  def test_copy_of_a_linked_issue_follows_the_matrix
    source = Issue.find(1)
    source.safe_attributes = { 'urgency_id' => '2', 'impact_id' => '2' }
    source.save!
    copy = Issue.new.copy_from(source.reload)
    assert copy.itil_priority_linked
    assert_equal 5, copy.priority_id
  end

  def test_unlinking_is_journalized
    issue = unlinked_issue
    detail = issue.journals.last.details.detect { |d| d.prop_key == 'itil_priority_linked' }
    assert detail
    assert_equal %w[1 0], [detail.old_value, detail.value]
  end
end
