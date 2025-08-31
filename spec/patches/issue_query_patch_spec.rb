# frozen_string_literal: true

require_relative '../spec_helper'
require_relative '../../lib/redmine_itil_priority/patches/issue_query_patch'

RSpec.describe RedmineItilPriority::Patches::IssueQueryPatch do
  before do
    Setting['plugin_redmine_itil_priority'] = {
      'label_impact_1' => 'Low impact',
      'label_impact_2' => 'Medium impact',
      'label_impact_3' => 'High impact',
      'label_urgency_1' => 'Low urgency',
      'label_urgency_2' => 'Medium urgency',
      'label_urgency_3' => 'High urgency'
    }

    class Query
      class << self
        attr_accessor :operators_by_filter_type
      end
      self.operators_by_filter_type = {
        list: ['=', '!'],
        list_optional: ['=', '!', '!*', '*'],
        integer: ['=', '>=', '<=', '><', '!*', '*']
      }
    end

    class QueryColumn
      attr_reader :name, :caption, :sortable, :groupable

      def initialize(name, options = {}, &block)
        @name = name
        @caption = options[:caption]
        @sortable = options[:sortable]
        @groupable = options[:groupable]
        @block = block
      end

      def value(obj)
        @block ? @block.call(obj) : obj.send(@name)
      end
    end

    Issue = Struct.new(:impact_id, :urgency_id, :project, :tracker)
    def Issue.table_name
      'issues'
    end

    class IssueQuery
      class << self
        attr_accessor :available_columns
      end
      self.available_columns = []

      attr_reader :project

      def initialize(issues, project: nil)
        @issues = issues
        @project = project
        initialize_available_filters
      end

      def available_filters
        @available_filters ||= {}
      end

      def initialize_available_filters; end

      def add_available_filter(field, options)
        available_filters[field] = options
      end

      def available_columns
        self.class.available_columns
      end

      def filter(filters)
        results = @issues
        filters.each do |field, value|
          values = Array(value).map(&:to_s)
          results = results.select { |issue| values.include?(issue.send(field).to_s) }
        end
        results
      end
    end

    IssueQuery.include RedmineItilPriority::Patches::IssueQueryPatch
  end

  after do
    Object.send(:remove_const, :IssueQuery)
    Object.send(:remove_const, :QueryColumn)
    Object.send(:remove_const, :Issue)
    Object.send(:remove_const, :Query)
    Setting.values.clear
  end

  let(:issues) do
    [
      Issue.new(1, 1, nil, nil),
      Issue.new(2, 2, nil, nil),
      Issue.new(1, 3, nil, nil)
    ]
  end

  it 'adds impact and urgency columns with labels and filters' do
    columns = IssueQuery.available_columns
    impact = columns.find { |c| c.name == :impact_id }
    urgency = columns.find { |c| c.name == :urgency_id }

    expect(impact.sortable).to eq('issues.impact_id')
    expect(impact.groupable).to eq('issues.impact_id')
    expect(impact.value(issues.first)).to eq('Low impact')

    expect(urgency.sortable).to eq('issues.urgency_id')
    expect(urgency.groupable).to eq('issues.urgency_id')
    expect(urgency.value(issues.first)).to eq('Low urgency')

    query = IssueQuery.new(issues)
    expect(query.available_filters.keys).to include('impact_id', 'urgency_id')
    expect(query.available_filters['impact_id'][:type]).to eq(:list_optional)
    expect(query.available_filters['impact_id'][:values]).to include(['Low impact', '1'])
    expect(query.available_filters['urgency_id'][:values]).to include(['Medium urgency', '2'])
    expect(Query.operators_by_filter_type[:list_optional]).to include('>=', '<=', '*', '!*')
  end

  it 'filters issues by impact and urgency' do
    query = IssueQuery.new(issues)

    by_impact = query.filter('impact_id' => ['1'])
    expect(by_impact.map(&:impact_id).uniq).to eq([1])

    by_urgency = query.filter('urgency_id' => ['3'])
    expect(by_urgency.map(&:urgency_id)).to eq([3])
  end

  context 'with project hierarchy settings' do
    QueryProject = Struct.new(:id, :identifier, :trackers, :children) do
      def module_enabled?(_)
        true
      end

      def self_and_descendants
        FakeRelation.new([self] + children.flat_map(&:self_and_descendants))
      end
    end
    QueryTracker = Struct.new(:id)

    let(:tracker1) { QueryTracker.new(1) }
    let(:tracker2) { QueryTracker.new(2) }
    let(:child) { QueryProject.new(2, 'child', FakeRelation.new([tracker1, tracker2]), []) }
    let(:project) { QueryProject.new(1, 'root', FakeRelation.new([tracker1, tracker2]), [child]) }

    before do
      Setting.values['plugin_redmine_itil_priority_project_1'] = {
        'tracker_settings' => {
          '1' => { 'mode' => 'custom', 'label_impact_1' => 'Root-Imp1', 'label_urgency_1' => 'Root-Urg1' },
          '2' => { 'mode' => 'default' }
        }
      }
      Setting.values['plugin_redmine_itil_priority_project_2'] = {
        'tracker_settings' => {
          '1' => { 'mode' => 'custom', 'label_impact_2' => 'Child-Imp2', 'label_urgency_3' => 'Child-Urg3' },
          '2' => { 'mode' => 'inactive' }
        }
      }
    end

    it 'uses project and subproject labels for filter options' do
      query = IssueQuery.new(issues, project: project)
      expect(query.available_filters['impact_id'][:values]).to include(['Root-Imp1', '1'], ['Child-Imp2', '2'])
      expect(query.available_filters['urgency_id'][:values]).to include(['Root-Urg1', '1'], ['Child-Urg3', '3'])
    end
  end

  context 'when plugin inactive for project tree' do
    InactiveProject = Struct.new(:id, :identifier, :trackers, :children) do
      def module_enabled?(_)
        true
      end

      def self_and_descendants
        FakeRelation.new([self] + children.flat_map(&:self_and_descendants))
      end
    end
    InactiveTracker = Struct.new(:id)

    let(:tracker1) { InactiveTracker.new(1) }
    let(:child) { InactiveProject.new(2, 'child', FakeRelation.new([tracker1]), []) }
    let(:project) { InactiveProject.new(1, 'root', FakeRelation.new([tracker1]), [child]) }

    before do
      Setting['plugin_redmine_itil_priority']['default_tracker_mode'] = 'inactive'
    end

    it 'hides filters and columns' do
      query = IssueQuery.new(issues, project: project)
      expect(query.available_filters.keys).not_to include('impact_id', 'urgency_id')
      names = query.available_columns.map(&:name)
      expect(names).not_to include(:impact_id, :urgency_id)
    end
  end

  context 'when only subproject has plugin active' do
    ProjectStruct = Struct.new(:id, :identifier, :trackers, :children) do
      def module_enabled?(_)
        true
      end

      def self_and_descendants
        FakeRelation.new([self] + children.flat_map(&:self_and_descendants))
      end
    end
    TrackerStruct = Struct.new(:id)

    let(:tracker1) { TrackerStruct.new(1) }
    let(:child) { ProjectStruct.new(2, 'child', FakeRelation.new([tracker1]), []) }
    let(:project) { ProjectStruct.new(1, 'root', FakeRelation.new([tracker1]), [child]) }

    before do
      Setting['plugin_redmine_itil_priority']['default_tracker_mode'] = 'inactive'
      Setting.values['plugin_redmine_itil_priority_project_2'] = {
        'tracker_settings' => { '1' => { 'mode' => 'default' } }
      }
    end

    it 'shows filters and columns for parent project' do
      query = IssueQuery.new(issues, project: project)
      expect(query.available_filters.keys).to include('impact_id', 'urgency_id')
      names = query.available_columns.map(&:name)
      expect(names).to include(:impact_id, :urgency_id)
    end
  end

  context 'with global query across multiple projects' do
    GlobalProject = Struct.new(:id, :identifier, :trackers, :children) do
      def module_enabled?(_)
        true
      end

      def self_and_descendants
        FakeRelation.new([self])
      end
    end
    GlobalTracker = Struct.new(:id)

    let(:tracker1) { GlobalTracker.new(1) }
    let(:tracker2) { GlobalTracker.new(2) }
    let(:project1) { GlobalProject.new(1, 'p1', FakeRelation.new([tracker1]), []) }
    let(:project2) { GlobalProject.new(2, 'p2', FakeRelation.new([tracker2]), []) }

    before do
      Setting.values = {
        'plugin_redmine_itil_priority' => {
          'label_impact_1' => 'G1',
          'label_impact_2' => 'G2',
          'label_impact_3' => 'G3',
          'label_urgency_1' => 'U1',
          'label_urgency_2' => 'U2',
          'label_urgency_3' => 'U3'
        },
        'plugin_redmine_itil_priority_project_1' => {
          'tracker_settings' => {
            '1' => { 'mode' => 'custom', 'label_impact_1' => 'P1-Imp1', 'label_urgency_3' => 'P1-Urg3' }
          }
        },
        'plugin_redmine_itil_priority_project_2' => {
          'tracker_settings' => {
            '2' => { 'mode' => 'custom', 'label_impact_3' => 'P2-Imp3', 'label_urgency_2' => 'P2-Urg2' }
          }
        }
      }

      stub_const('Project', Class.new do
        class << self
          attr_accessor :projects
        end

        def self.active
          self
        end

        def self.has_module(_)
          self
        end

        def self.includes(_)
          projects
        end
      end)
      Project.projects = [project1, project2]
    end

    it 'includes labels from all projects in filters' do
      query = IssueQuery.new(issues)
      expect(query.available_filters['impact_id'][:values]).to include(['P1-Imp1', '1'], ['P2-Imp3', '3'])
      expect(query.available_filters['urgency_id'][:values]).to include(['P1-Urg3', '3'], ['P2-Urg2', '2'])
    end
  end
end
