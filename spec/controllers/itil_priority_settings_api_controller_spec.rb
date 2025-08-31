# frozen_string_literal: true

require_relative '../spec_helper'

class ApplicationController
  class << self
    attr_reader :before_actions, :accepted_api_actions

    def before_action(*args)
      (@before_actions ||= []) << args
    end

    def accept_api_auth(*args)
      (@accepted_api_actions ||= []) << args
    end
  end
end

require_relative '../../app/controllers/itil_priority_settings_api_controller'

RSpec.describe ItilPrioritySettingsApiController do
  subject(:controller) { described_class.new }

  before do
    allow(controller).to receive(:render)
  end

  describe 'filters' do
    it 'accepts API authentication for all actions' do
      expect(ItilPrioritySettingsApiController.accepted_api_actions).to include([
        :global, :update_global, :project, :update_project
      ])
    end

    it 'requires admin for global actions' do
      expect(ItilPrioritySettingsApiController.before_actions).to include([
        :require_admin, { only: [:global, :update_global] }
      ])
    end

    it 'authorizes project actions' do
      expect(ItilPrioritySettingsApiController.before_actions).to include([
        :find_project, :authorize, { only: [:project, :update_project] }
      ])
    end
  end

  describe '#update_global' do
    it 'stores sanitized settings in Setting' do
      params = { settings: { 'label_impact_1' => 'Low', 'evil' => 'hack' } }
      allow(controller).to receive(:params).and_return(params)

      Setting.values = {}

      controller.update_global

      expect(Setting.values['plugin_redmine_itil_priority']).to eq('label_impact_1' => 'Low')
    end
  end

  describe '#global' do
    it 'renders global settings' do
      Setting.values = { 'plugin_redmine_itil_priority' => { 'foo' => 'bar' } }
      expect(controller).to receive(:render).with(json: { 'foo' => 'bar' })
      controller.global
    end
  end

  describe '#update_project' do
    it 'stores tracker settings in Setting' do
      tracker_settings = { '1' => { 'mode' => 'custom', 'priority_i1_u1' => 5 } }
      project = double('Project', identifier: 'proj', id: 42)
      controller.instance_variable_set(:@project, project)
      params = { tracker_settings: tracker_settings }
      allow(controller).to receive(:params).and_return(params)
      allow(controller).to receive(:project)

      Setting.values = {}

      controller.update_project

      expect(Setting.values['plugin_redmine_itil_priority_project_42']).to eq('tracker_settings' => tracker_settings)
    end

    it 'ignores mapping values when mode is not custom' do
      tracker_settings = {
        '1' => { 'mode' => 'default', 'priority_i1_u1' => 2 },
        '2' => { 'mode' => 'inactive', 'priority_i1_u1' => 3 },
        '3' => { 'mode' => 'custom', 'priority_i1_u1' => 5, 'evil' => 'hack' }
      }
      project = double('Project', identifier: 'proj', id: 42)
      controller.instance_variable_set(:@project, project)
      params = { tracker_settings: tracker_settings }
      allow(controller).to receive(:params).and_return(params)
      allow(controller).to receive(:project)

      Setting.values = {}

      controller.update_project

      expect(Setting.values['plugin_redmine_itil_priority_project_42']).to eq(
        'tracker_settings' => {
          '1' => { 'mode' => 'default' },
          '2' => { 'mode' => 'inactive' },
          '3' => { 'mode' => 'custom', 'priority_i1_u1' => 5 }
        }
      )
    end
  end

  describe '#project' do
    it 'renders settings for all trackers respecting modes' do
      Setting.values = {
        'plugin_redmine_itil_priority' => {
          'label_urgency_1' => 'U1',
          'label_impact_1' => 'I1',
          'priority_i1_u1' => 1,
          'default_tracker_mode' => 'default'
        },
        'plugin_redmine_itil_priority_project_1' => {
          'tracker_settings' => {
            '1' => { 'mode' => 'default' },
            '2' => { 'mode' => 'custom', 'priority_i1_u1' => 5 },
            '3' => { 'mode' => 'inactive' }
          }
        }
      }

      tracker1 = double('Tracker', id: 1)
      tracker2 = double('Tracker', id: 2)
      tracker3 = double('Tracker', id: 3)
      project = double('Project', id: 1, identifier: 'p1', trackers: [tracker1, tracker2, tracker3])
      allow(project).to receive(:module_enabled?).with(:itil_priority).and_return(true)
      controller.instance_variable_set(:@project, project)

      expect(controller).to receive(:render).with(json: {
        'tracker_settings' => {
          '1' => {
            'mode' => 'default',
            'settings' => Setting['plugin_redmine_itil_priority'].except('default_tracker_mode')
          },
          '2' => {
            'mode' => 'custom',
            'settings' => Setting['plugin_redmine_itil_priority'].except('default_tracker_mode').merge('priority_i1_u1' => 5)
          },
          '3' => {
            'mode' => 'inactive',
            'settings' => nil
          }
        }
      })

      controller.project
    end
  end
end
