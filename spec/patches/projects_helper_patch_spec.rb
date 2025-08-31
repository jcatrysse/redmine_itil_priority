# frozen_string_literal: true

require_relative '../spec_helper'
require_relative '../../lib/redmine_itil_priority/patches/projects_helper_patch'

RSpec.describe RedmineItilPriority::Patches::ProjectsHelperPatch do
  before do
    stub_const('User', Class.new)
    User.singleton_class.attr_accessor :current
  end

  let(:helper_class) do
    Class.new do
      def project_settings_tabs
        [{ name: 'general' }]
      end

      include RedmineItilPriority::Patches::ProjectsHelperPatch
    end
  end

  let(:helper) { helper_class.new }
  let(:project) { double('Project', identifier: 'proj') }
  let(:user) { double('User') }

  it 'adds tab when module enabled and user allowed' do
    allow(project).to receive(:module_enabled?).with(:itil_priority).and_return(true)
    allow(user).to receive(:allowed_to?).with(:manage_itil_priority_settings, project).and_return(true)
    helper.instance_variable_set(:@project, project)
    User.current = user

    tabs = helper.project_settings_tabs

    expect(tabs.map { |t| t[:name] }).to include('itil_priority')
  end

  it 'does not add tab when user lacks permission' do
    allow(project).to receive(:module_enabled?).with(:itil_priority).and_return(true)
    allow(user).to receive(:allowed_to?).with(:manage_itil_priority_settings, project).and_return(false)
    helper.instance_variable_set(:@project, project)
    User.current = user

    tabs = helper.project_settings_tabs

    expect(tabs.map { |t| t[:name] }).not_to include('itil_priority')
  end
end

