# frozen_string_literal: true

require_relative '../spec_helper'

module Redmine
  module Hook
    class ViewListener; end
  end
end

require_relative '../../lib/redmine_itil_priority/hooks/view_hooks'

RSpec.describe RedmineItilPriority::Hooks::ViewHooks do
  subject(:hook) { described_class.new }

  let(:controller) { double('controller') }
  let(:project) { double(id: 1, identifier: 'proj', module_enabled?: true) }
  let(:tracker1) { double(id: 1) }
  let(:tracker2) { double(id: 2) }
  let(:issue_enabled) { double(project: project, tracker: tracker1) }
  let(:issue_disabled) { double(project: project, tracker: tracker2) }

  before do
    Setting.values = {
      'plugin_redmine_itil_priority' => { 'default_tracker_mode' => 'default' },
      'plugin_redmine_itil_priority_project_1' => {
        'tracker_settings' => {
          '1' => { 'mode' => 'default' },
          '2' => { 'mode' => 'inactive' }
        }
      }
    }
  end

  after do
    Setting.values.clear
  end

  describe '#view_issues_context_menu_end' do
    it 'renders menu when all issues have settings' do
      allow(controller).to receive(:render_to_string).and_return('rendered')
      context = { controller: controller, issues: [issue_enabled] }
      expect(hook.view_issues_context_menu_end(context)).to eq('rendered')
    end

    it 'skips menu when any issue lacks settings' do
      allow(controller).to receive(:render_to_string)
      context = { controller: controller, issues: [issue_enabled, issue_disabled] }
      expect(hook.view_issues_context_menu_end(context)).to eq('')
      expect(controller).not_to have_received(:render_to_string)
    end
  end
end
