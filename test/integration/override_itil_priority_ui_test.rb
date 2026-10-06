# frozen_string_literal: true

require File.expand_path('../test_helper', __dir__)

# The permission "override ITIL priority" in the issue form, the context menu
# and the REST API.
class ItilOverridePriorityUiTest < Redmine::IntegrationTest
  include RedmineItilPriority::TestHelper
  fixtures(*FIXTURES)

  def setup
    itil_setup
    role_with_override(1)       # jsmith, operator
    role_without_override(2)    # dlopper, helpdesk
  end

  def test_form_without_the_permission_has_impact_and_urgency_but_no_priority
    log_user('dlopper', 'foo')
    get '/issues/1/edit'
    assert_response :success
    assert_select 'select[name=?]', 'issue[urgency_id]'
    assert_select 'select[name=?]', 'issue[impact_id]'
    assert_select 'select[name=?]', 'issue[priority_id]', 0
    assert_select 'input[name=?]', 'issue[itil_priority_linked]', 0
    assert_select '#itil_priority_field[data-can-override=false]'
  end

  def test_form_with_the_permission_can_unlink
    log_user('jsmith', 'jsmith')
    get '/issues/1/edit'
    assert_response :success
    assert_select 'select#itil_issue_priority_id[name=?]', 'issue[priority_id]'
    assert_select 'input#itil_priority_linked[name=?][value=?]', 'issue[itil_priority_linked]', '1'
    assert_select '#itil_priority_field[data-can-override=true]'
  end

  def test_form_shows_an_unlinked_issue_as_unlinked
    issue = Issue.find(1)
    issue.update_columns(itil_priority_linked: false, impact_id: 1, urgency_id: 1, priority_id: 8)
    log_user('jsmith', 'jsmith')
    get '/issues/1/edit'
    assert_select 'input#itil_priority_linked[value=?]', '0'
    assert_select 'img#itil_priority_link.unlink'
  end

  def test_update_without_the_permission_ignores_the_priority
    log_user('dlopper', 'foo')
    patch '/issues/1', params: { issue: { impact_id: '1', urgency_id: '1', priority_id: '8', itil_priority_linked: '0' } }
    assert_response :redirect
    issue = Issue.find(1)
    assert_equal [4, true], [issue.priority_id, issue.itil_priority_linked]
  end

  def test_update_with_the_permission_unlinks
    log_user('jsmith', 'jsmith')
    patch '/issues/1', params: { issue: { impact_id: '1', urgency_id: '1', priority_id: '8', itil_priority_linked: '0' } }
    assert_response :redirect
    issue = Issue.find(1)
    assert_equal [8, false], [issue.priority_id, issue.itil_priority_linked]
  end

  def test_context_menu_without_the_permission_has_impact_and_urgency_but_no_priority
    log_user('dlopper', 'foo')
    get '/issues/context_menu', params: { ids: [1] }, xhr: true
    assert_response :success
    assert_select 'a.submenu', text: 'Urgency'
    assert_select 'a.submenu', text: 'Impact'
    assert_select 'a.submenu', text: 'Priority', count: 0
  end

  def test_context_menu_with_the_permission_has_the_priority
    log_user('jsmith', 'jsmith')
    get '/issues/context_menu', params: { ids: [1] }, xhr: true
    assert_select 'a.submenu', text: 'Priority'
    assert_select 'a.submenu', text: 'Urgency'
  end

  def test_bulk_update_without_the_permission_ignores_the_priority
    log_user('dlopper', 'foo')
    post '/issues/bulk_update', params: { ids: [1, 2], issue: { priority_id: '8', urgency_id: '3', impact_id: '3' } }
    assert_response :redirect
    assert_equal [7, 7], Issue.where(id: [1, 2]).order(:id).pluck(:priority_id)
  end

  def test_rest_api_without_the_permission_ignores_the_priority
    with_settings rest_api_enabled: '1' do
      put '/issues/1.json',
          params: { issue: { impact_id: 2, urgency_id: 3, priority_id: 8, itil_priority_linked: false } },
          headers: credentials('dlopper', 'foo')
      assert_response :no_content
      issue = Issue.find(1)
      assert_equal [6, true], [issue.priority_id, issue.itil_priority_linked]
    end
  end

  def test_rest_api_with_the_permission_unlinks_and_shows_the_flag
    with_settings rest_api_enabled: '1' do
      put '/issues/1.json',
          params: { issue: { priority_id: 8, impact_id: 2, urgency_id: 3, itil_priority_linked: false } },
          headers: credentials('jsmith', 'jsmith')
      assert_response :no_content
      get '/issues/1.json', headers: credentials('jsmith', 'jsmith')
      json = ActiveSupport::JSON.decode(response.body)['issue']
      assert_equal [8, 2, 3, false],
                   [json['priority']['id'], json['impact_id'], json['urgency_id'], json['itil_priority_linked']]
    end
  end
end
