# frozen_string_literal: true

require File.expand_path('../test_helper', __dir__)

class ItilHistoryTest < Redmine::IntegrationTest
  include RedmineItilPriority::TestHelper
  fixtures(*FIXTURES)

  def setup
    itil_setup
    role_with_override(1)
  end

  def test_history_shows_labels_and_yes_no
    issue = Issue.find(1)
    issue.update_columns(impact_id: 1, urgency_id: 1)
    issue = Issue.find(1)
    issue.init_journal(User.find(2))
    issue.send(:safe_attributes=, { 'impact_id' => '3', 'urgency_id' => '2', 'itil_priority_linked' => '0',
                                    'priority_id' => '8' }, User.find(2))
    issue.save!

    log_user('jsmith', 'jsmith')
    get '/issues/1'
    assert_response :success
    assert_select '#history li', text: 'Impact changed from Low impact to Important impact'
    assert_select '#history li', text: 'Urgency changed from Not urgent to Normal'
    assert_select '#history li', text: 'Priority linked to impact and urgency changed from Yes to No'
  end
end
