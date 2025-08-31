# frozen_string_literal: true

require_relative '../spec_helper'
require_relative '../../lib/redmine_itil_priority/patches/mail_handler_patch'

RSpec.describe RedmineItilPriority::Patches::MailHandlerPatch do
  before do
    Setting.values = {
      'plugin_redmine_itil_priority' => {
        'label_urgency_1' => 'Not urgent', 'label_urgency_2' => 'Normal', 'label_urgency_3' => 'Urgent',
        'label_impact_1' => 'Low impact', 'label_impact_2' => 'Medium impact', 'label_impact_3' => 'Important impact',
        'priority_i1_u1' => 1, 'priority_i1_u2' => 2, 'priority_i1_u3' => 2,
        'priority_i2_u1' => 2, 'priority_i2_u2' => 2, 'priority_i2_u3' => 3,
        'priority_i3_u1' => 2, 'priority_i3_u2' => 3, 'priority_i3_u3' => 3
      }
    }
    Setting.values['plugin_redmine_itil_priority_project_1'] = {
      'tracker_settings' => { '1' => Setting.values['plugin_redmine_itil_priority'] }
    }
  end

  let(:tracker) { double(id: 1) }
  let(:project) { double(identifier: 'proj', id: 1, module_enabled?: true, trackers: [tracker]) }
  let(:issue) { double(project: project, tracker_id: nil, tracker: tracker) }

  let(:handler_class) do
    Class.new do
      attr_accessor :handler_options, :keywords, :base_attrs
      def initialize
        @handler_options = { allow_override: ['all'], issue: {} }
        @keywords = {}
        @base_attrs = { 'tracker_id' => 1 }
      end

      def issue_attributes_from_keywords(_issue)
        base_attrs
      end

      def get_keyword(key, _options = {})
        @keywords[key]
      end

      def get_keyword_bool(key)
        val = @keywords[key]
        return nil if val.nil?
        %w[1 yes true].include?(val.to_s.downcase)
      end
    end
  end

  before do
    handler_class.include described_class
  end

  it 'extracts impact and urgency ids from keywords' do
    handler = handler_class.new
    handler.keywords[:impact] = 'Low impact'
    handler.keywords[:urgency] = 'Urgent'
    handler.keywords[:itil_priority_linked] = '0'
    attrs = handler.issue_attributes_from_keywords(issue)
    expect(attrs['impact_id']).to eq('1')
    expect(attrs['urgency_id']).to eq('3')
    expect(attrs['itil_priority_linked']).to eq('0')
  end

  it 'falls back to first tracker when none specified' do
    handler = handler_class.new
    handler.base_attrs = {}
    handler.keywords[:impact] = 'Low impact'
    handler.keywords[:urgency] = 'Urgent'
    attrs = handler.issue_attributes_from_keywords(double(project: project, tracker_id: nil, tracker: nil))
    expect(attrs['impact_id']).to eq('1')
    expect(attrs['urgency_id']).to eq('3')
  end
end
