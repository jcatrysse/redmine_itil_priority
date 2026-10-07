# frozen_string_literal: true

require File.expand_path('../test_helper', __dir__)

# Change request: helpdesk users set impact and urgency only, never the
# priority; an operator (permission "override ITIL priority") can unlink the
# priority and set it by hand.
class ItilOverridePriorityTest < ActiveSupport::TestCase
  include RedmineItilPriority::TestHelper
  fixtures(*FIXTURES)

  def setup
    User.current = nil
    itil_setup
    @operator = User.find(2)   # Manager in project 1
    @helpdesk = User.find(3)   # Developer in project 1
    role_with_override(1)
    role_without_override(2)
  end

  def test_permission_is_in_the_itil_module
    permission = Redmine::AccessControl.permission(:override_itil_priority)
    assert permission
    assert_equal :itil_priority, permission.project_module
  end

  def test_priority_and_link_are_not_safe_without_the_permission
    issue = Issue.find(1)
    assert_not issue.safe_attribute?('priority_id', @helpdesk)
    assert_not issue.safe_attribute?('itil_priority_linked', @helpdesk)
    assert issue.safe_attribute?('impact_id', @helpdesk)
    assert issue.safe_attribute?('urgency_id', @helpdesk)
  end

  def test_priority_and_link_are_safe_with_the_permission
    issue = Issue.find(1)
    assert issue.safe_attribute?('priority_id', @operator)
    assert issue.safe_attribute?('itil_priority_linked', @operator)
  end

  def test_admin_may_override
    assert Issue.find(1).safe_attribute?('priority_id', User.find(1))
  end

  def test_helpdesk_user_cannot_set_or_unlink_the_priority
    issue = Issue.find(1)
    issue.init_journal(@helpdesk)
    issue.send(:safe_attributes=, { 'impact_id' => '1', 'urgency_id' => '1', 'priority_id' => '8',
                              'itil_priority_linked' => '0' }, @helpdesk)
    issue.save!
    issue.reload
    assert_equal 4, issue.priority_id, 'the matrix decides, not the submitted priority'
    assert issue.itil_priority_linked
  end

  def test_helpdesk_user_on_a_new_issue_gets_the_matrix_priority
    issue = Issue.new(project_id: 1, tracker_id: 1, author: @helpdesk, subject: 'Helpdesk')
    issue.send(:safe_attributes=, { 'impact_id' => '3', 'urgency_id' => '2', 'priority_id' => '4' }, @helpdesk)
    issue.save!
    assert_equal 6, issue.reload.priority_id
  end

  def test_helpdesk_user_keeps_an_override_made_by_an_operator
    issue = Issue.find(1)
    issue.send(:safe_attributes=, { 'impact_id' => '1', 'urgency_id' => '1', 'itil_priority_linked' => '0',
                              'priority_id' => '8' }, @operator)
    issue.save!
    issue.reload
    assert_equal 8, issue.priority_id

    issue.init_journal(@helpdesk)
    issue.send(:safe_attributes=, { 'urgency_id' => '3', 'itil_priority_linked' => '1' }, @helpdesk)
    issue.save!
    issue.reload
    assert_equal 8, issue.priority_id
    assert_equal 3, issue.urgency_id
    assert_equal false, issue.itil_priority_linked
  end

  def test_operator_can_unlink_and_set_the_priority
    issue = Issue.find(1)
    issue.send(:safe_attributes=, { 'impact_id' => '1', 'urgency_id' => '1', 'itil_priority_linked' => '0',
                              'priority_id' => '8' }, @operator)
    issue.save!
    issue.reload
    assert_equal [8, false], [issue.priority_id, issue.itil_priority_linked]
  end

  # Core's Issue#priority_id= shadows the plugin's, so a priority set directly
  # was written while the issue stayed linked, and the next edit undid it.
  def test_operator_setting_the_priority_directly_unlinks
    issue = Issue.find(1)
    issue.send(:safe_attributes=, { 'impact_id' => '2', 'urgency_id' => '2' }, @operator)
    issue.save!
    issue = Issue.find(1)
    issue.send(:safe_attributes=, { 'priority_id' => '8' }, @operator)
    issue.save!
    issue.reload
    assert_equal [8, false, 2, 2], [issue.priority_id, issue.itil_priority_linked, issue.impact_id, issue.urgency_id]

    issue.send(:safe_attributes=, { 'urgency_id' => '3' }, @helpdesk)
    issue.save!
    assert_equal 8, issue.reload.priority_id
  end

  def test_setting_the_matrix_priority_keeps_the_link
    issue = Issue.find(1)
    issue.send(:safe_attributes=, { 'impact_id' => '2', 'urgency_id' => '2' }, @operator)
    issue.send(:safe_attributes=, { 'priority_id' => '5' }, @operator)
    assert_equal [5, true], [issue.priority_id, issue.itil_priority_linked]
  end

  def test_explicit_link_wins_over_a_submitted_priority
    issue = Issue.find(1)
    issue.send(:safe_attributes=, { 'impact_id' => '2', 'urgency_id' => '3', 'itil_priority_linked' => '1',
                                    'priority_id' => '8' }, @operator)
    assert_equal [6, true], [issue.priority_id, issue.itil_priority_linked]
  end

  def test_priority_stays_a_core_field_where_itil_is_inactive
    itil_setup(Project.find(1), 'default_tracker_mode' => 'inactive')
    assert Issue.find(1).safe_attribute?('priority_id', @helpdesk)
  end

  # The fields are not shown there, so an API client or a bulk edit over
  # mixed trackers must not store them either.
  def test_impact_urgency_and_link_are_not_assignable_where_itil_is_inactive
    itil_setup(Project.find(1), 'default_tracker_mode' => 'inactive')
    issue = Issue.find(1)
    %w[impact_id urgency_id itil_priority_linked].each do |name|
      assert_not issue.safe_attribute?(name, @operator), "#{name} must not be safe"
    end
    issue.send(:safe_attributes=, { 'impact_id' => '3', 'urgency_id' => '3', 'itil_priority_linked' => '0',
                                    'priority_id' => '8' }, @operator)
    issue.save!
    issue.reload
    assert_equal [nil, nil, true, 8], [issue.impact_id, issue.urgency_id, issue.itil_priority_linked, issue.priority_id]
  end

  # Core's safe_attributes= applies project_id and tracker_id before it drops
  # unsafe attributes, so the order of the keys cannot sneak impact and urgency
  # onto a tracker where ITIL is inactive (OpenAI review of 3281330).
  def test_key_order_cannot_set_impact_on_an_inactive_tracker
    Setting.where(name: 'plugin_redmine_itil_priority_project_1').delete_all
    Setting.available_settings['plugin_redmine_itil_priority_project_1'] ||= { 'serialized' => true, 'default' => {} }
    record = Setting.new(name: 'plugin_redmine_itil_priority_project_1')
    record.value = { 'tracker_settings' => { '2' => { 'mode' => 'inactive' } } }
    record.save!
    RedmineItilPriority.clear_cache

    issue = Issue.new(project_id: 1, author: @helpdesk)
    issue.send(:safe_attributes=, { 'impact_id' => '3', 'urgency_id' => '2', 'subject' => 'Order', 'tracker_id' => '2' }, @helpdesk)
    assert_equal 2, issue.tracker_id
    assert_equal [nil, nil], [issue.impact_id, issue.urgency_id]

    issue = Issue.new(project_id: 1, author: @helpdesk)
    issue.send(:safe_attributes=, { 'impact_id' => '3', 'urgency_id' => '2', 'subject' => 'Order', 'tracker_id' => '1' }, @helpdesk)
    assert_equal [3, 2], [issue.impact_id, issue.urgency_id]
  end

  def test_impact_and_urgency_are_not_assignable_without_the_module
    Project.find(1).disable_module!(:itil_priority)
    RedmineItilPriority.clear_cache
    assert_not Issue.find(1).safe_attribute?('impact_id', @operator)
  end

  def test_priority_stays_a_core_field_without_the_module
    Project.find(1).disable_module!(:itil_priority)
    RedmineItilPriority.clear_cache
    assert Issue.find(1).safe_attribute?('priority_id', @helpdesk)
  end

  # A priority made read-only by the workflow cannot be unlinked either, even
  # with the permission.
  def test_read_only_priority_in_the_workflow_wins_over_the_permission
    issue = Issue.find(1)
    WorkflowPermission.create!(role_id: 1, tracker_id: issue.tracker_id, old_status_id: issue.status_id,
                               field_name: 'priority_id', rule: 'readonly')
    assert_not issue.safe_attribute?('priority_id', @operator)
    assert_not issue.safe_attribute?('itil_priority_linked', @operator)
    assert issue.safe_attribute?('urgency_id', @operator)
  end

  def test_mail_from_a_helpdesk_user_sets_impact_and_urgency_but_not_the_priority
    issue = receive_mail('dlopper@somenet.foo', "Impact: Important impact\nUrgency: Urgent\nPriority: Low\nItil priority linked: 0")
    assert issue.is_a?(Issue), 'issue created'
    assert_equal [3, 3], [issue.impact_id, issue.urgency_id]
    assert_equal 7, issue.priority_id
    assert issue.itil_priority_linked
  end

  def test_mail_from_an_operator_may_unlink_and_set_the_priority
    issue = receive_mail('jsmith@somenet.foo', "Impact: Important impact\nUrgency: Urgent\nPriority: Low\nItil priority linked: 0")
    assert issue.is_a?(Issue), 'issue created'
    assert_equal [4, false], [issue.priority_id, issue.itil_priority_linked]
  end

  def test_migration_grants_the_permission_to_roles_that_edit_issues
    require File.expand_path('../../db/migrate/004_grant_override_itil_priority', __dir__)
    Role.find_each { |role| role.remove_permission!(:override_itil_priority) }
    ActiveRecord::Migration.suppress_messages { GrantOverrideItilPriority.new.migrate(:up) }
    granted = Role.all.select { |role| role.has_permission?(:override_itil_priority) }.map(&:id).sort
    expected = Role.all.select do |role|
      %i[add_issues edit_issues edit_own_issues].any? { |p| role.has_permission?(p) }
    end.map(&:id).sort
    assert_equal expected, granted
    assert_includes granted, 1

    ActiveRecord::Migration.suppress_messages { GrantOverrideItilPriority.new.migrate(:down) }
    assert Role.all.none? { |role| role.has_permission?(:override_itil_priority) }
  end

  private

  def receive_mail(from, body)
    raw = <<~MAIL
      Return-Path: <#{from}>
      From: #{from}
      To: redmine@somenet.foo
      Subject: ITIL by mail #{SecureRandom.hex(4)}
      Date: Sat, 1 Jun 2024 10:00:00 +0200
      Message-ID: <#{SecureRandom.hex(8)}@somenet.foo>
      Content-Type: text/plain; charset="utf-8"

      A helpdesk request.

      #{body}
    MAIL
    MailHandler.receive(raw, issue: { project: 'ecookbook', tracker: 'Bug' },
                             allow_override: 'priority,impact,urgency,itil_priority_linked')
  end
end
