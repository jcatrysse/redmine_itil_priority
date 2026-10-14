# frozen_string_literal: true

require File.expand_path('../test_helper', __dir__)

# Every issue list, gantt and my page builds an IssueQuery: its impact and
# urgency filters must not cost a query or a cache read per project.
class ItilFilterPerformanceTest < ActiveSupport::TestCase
  include RedmineItilPriority::TestHelper
  fixtures(*FIXTURES)

  def setup
    itil_setup
    User.current = User.find(1)
  end

  def teardown
    User.current = nil
  end

  def test_building_the_filters_does_not_compute_their_values
    RedmineItilPriority.expects(:options_for).never

    query = IssueQuery.new(name: '_')
    assert query.available_filters.key?('impact_id')
    assert query.available_filters.key?('urgency_id')
  end

  def test_filter_values_are_computed_when_asked
    query = IssueQuery.new(name: '_', project: Project.find(1))
    assert_equal [['Low impact', '1'], ['Medium impact', '2'], ['Important impact', '3']],
                 query.available_filters['impact_id'][:values]
    assert_equal [['Not urgent', '1'], ['Normal', '2'], ['Urgent', '3']],
                 query.available_filters['urgency_id'][:values]
  end

  def test_labels_of_projects_with_own_settings_stay_in_the_filter
    project = create_projects(1, 'own').first
    save_project_settings(project, 'label_impact_2' => 'Own medium')
    RedmineItilPriority.clear_memo

    # a level with labels of its own lists those instead of the global one, as before
    assert_equal [['Low impact', '1'], ['Own medium', '2'], ['Important impact', '3']],
                 IssueQuery.new(name: '_').available_filters['impact_id'][:values]
  end

  def test_cost_of_the_filters_does_not_grow_with_the_number_of_projects
    create_projects(5, 'a')
    small = filter_cost(nil)
    create_projects(5, 'b')
    large = filter_cost(nil)

    assert_equal small, large, 'queries for 5 more projects with ITIL priority'
  end

  def test_cost_of_the_filters_does_not_grow_with_the_number_of_subprojects
    parent = Project.find(1)
    create_projects(5, 'c', parent)
    small = filter_cost(parent)
    create_projects(5, 'd', parent)
    large = filter_cost(parent)

    assert_equal 10, parent.reload.descendants.where('identifier LIKE ?', 'itil-perf-%').count

    assert_equal small, large, 'queries for 5 more subprojects with ITIL priority'
  end

  private

  # Projects with the module and their own settings, as a large GEOxyz install.
  def create_projects(count, prefix, parent = nil)
    Array.new(count) do |i|
      project = Project.create!(name: "ITIL #{prefix}#{i}", identifier: "itil-perf-#{prefix}#{i}",
                                tracker_ids: [1, 2], enabled_module_names: %w[issue_tracking itil_priority],
                                parent_id: parent&.id)
      save_project_settings(project, 'label_impact_1' => "Impact #{prefix}#{i}")
      project
    end
  end

  def save_project_settings(project, labels)
    key = RedmineItilPriority.project_settings_key(project.id)
    setting = Setting.find_or_initialize_by(name: key)
    setting.value = { 'tracker_settings' => { '1' => { 'mode' => 'custom' }.merge(labels) } }
    setting.save!
  end

  # Queries of one request that builds the filters and shows their values,
  # with Rails.cache warm from an earlier request.
  def filter_cost(project)
    run = lambda do
      Setting.check_cache
      query = IssueQuery.new(name: '_', project: project&.reload)
      query.available_filters['impact_id'][:values]
      query.available_filters['urgency_id'][:values]
      query.available_columns
    end
    run.call
    queries = []
    callback = lambda do |*, payload|
      queries << payload[:sql] unless %w[SCHEMA CACHE].include?(payload[:name]) || payload[:cached]
    end
    ActiveSupport::Notifications.subscribed(callback, 'sql.active_record') { run.call }
    queries.size
  end
end
