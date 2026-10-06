# frozen_string_literal: true

require File.expand_path('../test_helper', __dir__)

# Impact and urgency in the workflow's field permissions.
class ItilWorkflowFieldsTest < Redmine::IntegrationTest
  include RedmineItilPriority::TestHelper
  fixtures(*FIXTURES)

  def setup
    itil_setup
    role_with_override(1)
    role_without_override(2)
    @issue = Issue.find(1)
  end

  def rule(role_id, field, rule)
    WorkflowPermission.create!(role_id: role_id, tracker_id: @issue.tracker_id, old_status_id: @issue.status_id,
                               field_name: field, rule: rule)
  end

  def test_impact_and_urgency_are_valid_workflow_fields
    assert WorkflowPermission.new(role_id: 2, tracker_id: 1, old_status_id: 1, field_name: 'impact_id', rule: 'readonly').valid?
    assert WorkflowPermission.new(role_id: 2, tracker_id: 1, old_status_id: 1, field_name: 'urgency_id', rule: 'required').valid?
    assert_not WorkflowPermission.new(role_id: 2, tracker_id: 1, old_status_id: 1, field_name: 'foo', rule: 'required').valid?
  end

  def test_fields_permissions_page_lists_impact_and_urgency
    log_user('admin', 'admin')
    get '/workflows/permissions', params: { role_id: 2, tracker_id: 1 }
    assert_response :success
    assert_select 'td.name', text: /Impact/
    assert_select 'td.name', text: /Urgency/
    assert_select 'select[name=?]', 'permissions[1][impact_id]'

    patch '/workflows/update_permissions', params: { role_id: 2, tracker_id: 1,
                                                     permissions: { '1' => { 'urgency_id' => 'readonly' } } }
    assert WorkflowPermission.where(role_id: 2, tracker_id: 1, old_status_id: 1, field_name: 'urgency_id', rule: 'readonly').exists?
  end

  def test_read_only_urgency_cannot_be_changed_and_shows_as_text
    rule(2, 'urgency_id', 'readonly')
    user = User.find(3)
    assert_not @issue.safe_attribute?('urgency_id', user)
    assert @issue.safe_attribute?('impact_id', user)

    log_user('dlopper', 'foo')
    get '/issues/1/edit'
    assert_select 'select[name=?]', 'issue[urgency_id]', 0
    assert_select 'span#issue_urgency_id.itil-value'
    assert_select 'select[name=?]', 'issue[impact_id]'

    patch '/issues/1', params: { issue: { urgency_id: '3', impact_id: '2' } }
    assert_nil Issue.find(1).urgency_id
    assert_equal 2, Issue.find(1).impact_id
  end

  def test_required_impact_is_enforced_where_itil_is_active
    rule(2, 'impact_id', 'required')
    log_user('dlopper', 'foo')
    get '/issues/1/edit'
    assert_select 'label', text: /Impact\s*\*/

    patch '/issues/1', params: { issue: { urgency_id: '2', impact_id: '' } }
    assert_response :success
    assert_select '#errorExplanation', text: /Impact cannot be blank/
  end

  def test_required_impact_is_ignored_where_itil_is_inactive
    rule(2, 'impact_id', 'required')
    itil_setup(Project.find(1), 'default_tracker_mode' => 'inactive')
    assert_not @issue.required_attribute?('impact_id', User.find(3))
    log_user('dlopper', 'foo')
    patch '/issues/1', params: { issue: { subject: 'Still saved' } }
    assert_response :redirect
    assert_equal 'Still saved', Issue.find(1).subject
  end
end
