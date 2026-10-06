# frozen_string_literal: true

require File.expand_path('../test_helper', __dir__)

class ItilWebhookPayloadTest < ActiveSupport::TestCase
  include RedmineItilPriority::TestHelper
  fixtures(*FIXTURES)

  def setup
    skip 'webhooks are new in Redmine 7' unless Issue.method_defined?(:webhook_payload)
    itil_setup
  end

  def test_issue_payload_has_impact_urgency_and_link
    Issue.find(1).update_columns(impact_id: 3, urgency_id: 2, itil_priority_linked: false)
    payload = Issue.find(1).webhook_payload(User.find(1), 'updated')
    data = payload[:data][:issue]
    data = data['issue'] || data[:issue] || data
    assert_equal 3, data[:impact_id] || data['impact_id']
    assert_equal 2, data[:urgency_id] || data['urgency_id']
    assert_equal false, data.key?(:itil_priority_linked) ? data[:itil_priority_linked] : data['itil_priority_linked']
  end
end
