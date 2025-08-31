# frozen_string_literal: true

require_relative 'spec_helper'

RSpec.describe 'RedmineItilPriority caching' do
  let(:project) { double(id: 1, identifier: 'proj', module_enabled?: true) }
  let(:tracker) { double(id: 1) }

  before do
    Setting.values = {
      'plugin_redmine_itil_priority' => { 'foo' => 'bar', 'default_tracker_mode' => 'default' },
      'plugin_redmine_itil_priority_project_1' => {
        'tracker_settings' => { '1' => { 'foo' => 'baz' } }
      }
    }
  end

  it 'caches global settings and invalidates after save' do
    expect(RedmineItilPriority.global_settings['foo']).to eq('bar')
    Setting.values['plugin_redmine_itil_priority']['foo'] = 'updated'
    expect(RedmineItilPriority.global_settings['foo']).to eq('bar')
    record = Setting.find_by(name: 'plugin_redmine_itil_priority')
    record.value = Setting.values['plugin_redmine_itil_priority']
    record.save
    expect(RedmineItilPriority.global_settings['foo']).to eq('updated')
  end

  it 'caches project settings and settings_for until settings change' do
    expect(RedmineItilPriority.settings_for(project, tracker)['foo']).to eq('baz')
    Setting.values['plugin_redmine_itil_priority_project_1']['tracker_settings']['1']['foo'] = 'new'
    expect(RedmineItilPriority.settings_for(project, tracker)['foo']).to eq('baz')
    record = Setting.find_by(name: 'plugin_redmine_itil_priority_project_1')
    record.value = Setting.values['plugin_redmine_itil_priority_project_1']
    record.save
    expect(RedmineItilPriority.settings_for(project, tracker)['foo']).to eq('new')
  end
end

