# frozen_string_literal: true

require File.expand_path('../test_helper', __dir__)

class ItilIssueListTest < Redmine::IntegrationTest
  include RedmineItilPriority::TestHelper
  fixtures(*FIXTURES)

  def setup
    itil_setup
    Issue.find(1).update_columns(impact_id: 3, urgency_id: 1)
  end

  def test_columns_show_labels_not_numbers
    log_user('jsmith', 'jsmith')
    get '/projects/ecookbook/issues', params: { set_filter: 1, f: ['issue_id'], op: { issue_id: '=' }, v: { issue_id: ['1'] },
                                                c: %w[subject impact_id urgency_id] }
    assert_response :success
    assert_select 'tr#issue-1 td.impact_id', text: 'Important impact'
    assert_select 'tr#issue-1 td.urgency_id', text: 'Not urgent'
  end

  def test_csv_has_labels
    log_user('jsmith', 'jsmith')
    get '/projects/ecookbook/issues.csv', params: { set_filter: 1, f: ['issue_id'], op: { issue_id: '=' }, v: { issue_id: ['1'] },
                                                    c: %w[subject impact_id urgency_id] }
    assert_response :success
    assert_include 'Important impact', response.body
    assert_include 'Not urgent', response.body
  end
end
