# frozen_string_literal: true

require_relative '../spec_helper'

class ApplicationController
  def self.before_action(*); end
end

require_relative '../../app/controllers/itil_priority_settings_controller'

RSpec.describe ItilPrioritySettingsController do
  subject(:controller) { described_class.new }

  before do
    allow(controller).to receive(:flash).and_return({})
    allow(controller).to receive(:redirect_to)
    allow(controller).to receive(:settings_project_path).and_return('/settings')
    allow(controller).to receive(:l).and_return('updated')
  end

  it 'stores tracker settings in Setting' do
    tracker_settings = { '1' => { 'mode' => 'custom', 'priority_i1_u1' => 5 } }
    project = double('Project', identifier: 'proj', id: 42)
    controller.instance_variable_set(:@project, project)
    params = { tracker_settings: tracker_settings }
    allow(controller).to receive(:params).and_return(params)

    Setting.values = {}

    controller.update

    expect(Setting.values['plugin_redmine_itil_priority_project_42']).to eq('tracker_settings' => tracker_settings)
  end

  it 'ignores mapping values when mode is not custom' do
    tracker_settings = {
      '1' => { 'mode' => 'default', 'priority_i1_u1' => 1 },
      '2' => { 'mode' => 'inactive', 'priority_i1_u1' => 2 },
      '3' => { 'mode' => 'custom', 'priority_i1_u1' => 5, 'evil' => 'hack' }
    }
    project = double('Project', identifier: 'proj', id: 42)
    controller.instance_variable_set(:@project, project)
    params = { tracker_settings: tracker_settings }
    allow(controller).to receive(:params).and_return(params)

    Setting.values = {}

    controller.update

    expect(Setting.values['plugin_redmine_itil_priority_project_42']).to eq(
      'tracker_settings' => {
        '1' => { 'mode' => 'default' },
        '2' => { 'mode' => 'inactive' },
        '3' => { 'mode' => 'custom', 'priority_i1_u1' => 5 }
      }
    )
  end
end

