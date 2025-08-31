# frozen_string_literal: true

require_relative 'spec_helper'

RSpec.describe RedmineItilPriority do
  before do
    Setting.values = {
      'plugin_redmine_itil_priority' => {
        'foo' => 'bar',
        'label_urgency_1' => 'Urg1',
        'default_tracker_mode' => 'default'
      }
    }
  end

  let(:tracker) { double(id: 1) }
  let(:project) { double(identifier: 'proj', module_enabled?: true, id: 1) }

  context 'when project has no project settings' do
    it 'falls back to global settings by default' do
      expect(described_class.settings_for(project, tracker))
        .to eq(Setting['plugin_redmine_itil_priority'].except('default_tracker_mode'))
    end

    context 'and default mode is inactive' do
      before { Setting['plugin_redmine_itil_priority']['default_tracker_mode'] = 'inactive' }

      it 'returns nil' do
        expect(described_class.settings_for(project, tracker)).to be_nil
      end
    end
  end

  context 'when tracker not configured' do
    before do
      Setting.values['plugin_redmine_itil_priority_project_1'] = {
        'tracker_settings' => { '2' => {} }
      }
    end

    it 'falls back to global settings by default' do
      expect(described_class.settings_for(project, tracker))
        .to eq(Setting['plugin_redmine_itil_priority'].except('default_tracker_mode'))
    end

    context 'and default mode is inactive' do
      before { Setting['plugin_redmine_itil_priority']['default_tracker_mode'] = 'inactive' }

      it 'returns nil' do
        expect(described_class.settings_for(project, tracker)).to be_nil
      end
    end
  end

  context 'when tracker has overrides' do
    before do
      Setting.values['plugin_redmine_itil_priority_project_1'] = {
        'tracker_settings' => {
          '1' => { 'foo' => 'baz', 'label_urgency_1' => '', 'mode' => 'custom' }
        }
      }
    end

    it 'merges overrides with global settings and keeps defaults for blanks' do
      expect(described_class.settings_for(project, tracker))
        .to eq('foo' => 'baz', 'label_urgency_1' => 'Urg1')
    end
  end

  it 'returns nil when mode is inactive' do
    Setting.values['plugin_redmine_itil_priority_project_1'] = {
      'tracker_settings' => { '1' => { 'mode' => 'inactive' } }
    }
    expect(described_class.settings_for(project, tracker)).to be_nil
  end

  it 'returns global settings when mode is default' do
    Setting.values['plugin_redmine_itil_priority_project_1'] = {
      'tracker_settings' => { '1' => { 'mode' => 'default' } }
    }
    expect(described_class.settings_for(project, tracker))
      .to eq('foo' => 'bar', 'label_urgency_1' => 'Urg1')
  end

  it 'returns tracker-specific settings when present' do
    Setting.values['plugin_redmine_itil_priority_project_1'] = {
      'tracker_settings' => { '1' => { 'foo' => 'baz' } }
    }
    expect(described_class.settings_for(project, tracker))
      .to eq('foo' => 'baz', 'label_urgency_1' => 'Urg1')
  end
end
