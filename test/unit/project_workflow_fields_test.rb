# frozen_string_literal: true

require File.expand_path('../test_helper', __dir__)

# redmine_project_workflows offers the fields other plugins register in
# config.x.project_workflow_permission_fields on its own Fields permissions
# matrices; impact and urgency are registered there.
class ItilProjectWorkflowFieldsTest < ActiveSupport::TestCase
  def test_impact_and_urgency_are_registered_for_project_workflows
    registered = Rails.configuration.x.project_workflow_permission_fields

    assert_equal true, registered[:impact_id]
    assert_equal true, registered[:urgency_id]
  end
end
