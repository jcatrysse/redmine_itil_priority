# frozen_string_literal: true

require_relative '../spec_helper'

RSpec.describe RedmineItilPriority::Patches::IssuePatch do
  before do
    Setting.values = {
      'plugin_redmine_itil_priority' => {
        'priority_i1_u1' => 1, 'priority_i1_u2' => 2, 'priority_i1_u3' => 2,
        'priority_i2_u1' => 2, 'priority_i2_u2' => 2, 'priority_i2_u3' => 3,
        'priority_i3_u1' => 2, 'priority_i3_u2' => 3, 'priority_i3_u3' => 3
      }
    }
  end

  let(:tracker) { double(id: 1) }
  let(:project) do
    Setting.values['plugin_redmine_itil_priority_project_1'] = {
      'tracker_settings' => { '1' => Setting.values['plugin_redmine_itil_priority'] }
    }
    double(module_enabled?: true, identifier: 'proj', id: 1)
  end

  let(:issue_class) do
    proj = project
    trk = tracker
    Class.new do
      attr_reader :impact_id, :urgency_id, :priority_id
      attr_accessor :priority

      class << self
        attr_reader :saved_safe_attributes

        def safe_attributes(*attrs)
          @saved_safe_attributes = attrs
        end
      end

      define_method(:project) { proj }
      define_method(:tracker) { trk }

      include RedmineItilPriority::Patches::IssuePatch

      def initialize
        @priority = nil
      end

      def write_attribute(attr, value)
        instance_variable_set("@#{attr}", value)
      end
    end
  end

  let(:issue) { issue_class.new }

  it 'registers impact and urgency as safe attributes' do
    expect(issue_class.saved_safe_attributes).to include('impact_id', 'urgency_id', 'itil_priority_linked')
  end

  it 'derives priority from impact and urgency' do
    issue.impact_id = 1
    issue.urgency_id = 1
    expect(issue.priority_id).to eq(1)

    issue.urgency_id = 3
    expect(issue.priority_id).to eq(2)
  end

  it 'updates priority when impact changes' do
    issue.urgency_id = 2
    issue.impact_id = 3
    expect(issue.priority_id).to eq(3)
  end

  it 'sets impact and urgency when priority is set' do
    issue.priority_id = 3
    expect(issue.impact_id).to eq(3)
    expect(issue.urgency_id).to eq(3)
  end

  it 'initializes impact and urgency from default priority' do
    issue.priority_id = 2
    expect(issue.impact_id).to eq(3)
    expect(issue.urgency_id).to eq(1)
  end

  it 'does not map values when linking disabled' do
    issue.itil_priority_linked = '0'
    issue.impact_id = 1
    issue.urgency_id = 1
    expect(issue.priority_id).to be_nil

    issue.priority_id = 3
    expect(issue.impact_id).to eq(1)
    expect(issue.urgency_id).to eq(1)
  end

  it 'keeps priority when impact is blank' do
    issue.priority_id = 2
    issue.impact_id = nil
    expect(issue.priority_id).to eq(2)

    issue.urgency_id = 1
    expect(issue.priority_id).to eq(2)
  end

  it 'keeps priority when urgency is blank' do
    issue.priority_id = 2
    issue.urgency_id = nil
    expect(issue.priority_id).to eq(2)

    issue.impact_id = 1
    expect(issue.priority_id).to eq(2)
  end

  it 'clears impact and urgency when set to none' do
    issue.impact_id = 1
    issue.urgency_id = 2
    issue.impact_id = 'none'
    issue.urgency_id = 'none'
    expect(issue.impact_id).to be_nil
    expect(issue.urgency_id).to be_nil
  end
end
