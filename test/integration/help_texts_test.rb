# frozen_string_literal: true

require File.expand_path('../test_helper', __dir__)

# Info icons next to impact and urgency with one explanation per level (Jan,
# 2026-10-07, choice B): per instance, and per project and tracker in the
# tracker's custom mode. The chosen level's text shows under the field.
class ItilHelpTextsTest < Redmine::IntegrationTest
  include RedmineItilPriority::TestHelper
  fixtures(*FIXTURES)

  HELP = { 'help_impact_1' => 'One *user*', 'help_impact_3' => 'The whole company' }.freeze

  def setup
    itil_setup(Project.find(1), HELP)
    role_with_override(1)
    Issue.find(1).update_columns(impact_id: 3, urgency_id: 1)
  end

  def test_form_shows_one_text_per_level_and_the_chosen_one
    log_user('jsmith', 'jsmith')
    get '/issues/1/edit'
    assert_response :success
    assert_select 'a.itil-help-toggle[data-target=?]', 'itil_help_impact'
    assert_select 'a.itil-help-toggle[data-target=?]', 'itil_help_urgency', 0
    # overview behind the icon: the three levels with their labels, texts where set
    assert_select '#itil_help_impact .itil-help-level', 3
    assert_select '#itil_help_impact .itil-help-level[data-level="1"]', text: /Low impact.*One user/m
    assert_select '#itil_help_impact .itil-help-level[data-level="1"] em, #itil_help_impact .itil-help-level[data-level="1"] p strong', text: 'user'  # wiki-formatted
    assert_select '#itil_help_impact .itil-help-level[data-level="3"]', text: /Important impact.*The whole company/m
    # the chosen level's text, under the field (shown by the page's script)
    assert_select '#itil_help_current_impact > div', 2
    assert_select '#itil_help_current_impact > div[data-level="3"]', text: /The whole company/
    assert_select '#itil_help_urgency', 0
    assert_select '#itil_help_current_urgency', 0
  end

  def test_text_is_sanitized
    itil_setup(Project.find(1), 'help_urgency_2' => '<script>alert(1)</script>')
    log_user('jsmith', 'jsmith')
    get '/issues/1/edit'
    assert_select '#itil_help_urgency script', 0
    assert_select '#itil_help_urgency .itil-help-level[data-level="2"]', text: /alert\(1\)/
  end

  def test_tracker_custom_texts_override_the_generic_ones
    log_user('jsmith', 'jsmith')
    Role.find(1).add_permission!(:manage_itil_priority_settings)
    post '/projects/ecookbook/itil_priority_settings',
         params: { tracker_settings: { '1' => { mode: 'custom', help_impact_3: 'Bugs: every customer', help_impact_1: '' } } }
    assert_response :redirect

    get '/issues/1/edit' # a bug
    assert_select '#itil_help_impact .itil-help-level[data-level="3"]', text: /Bugs: every customer/
    assert_select '#itil_help_impact .itil-help-level[data-level="1"]', text: /One user/ # empty: the generic text

    get '/issues/new', params: { project_id: 'ecookbook', issue: { tracker_id: 2 } }
    assert_select '#itil_help_impact .itil-help-level[data-level="3"]', text: /The whole company/

    get '/projects/ecookbook/settings/itil_priority'
    assert_select 'textarea[name=?]', 'tracker_settings[1][help_impact_3]', text: 'Bugs: every customer'
    assert_select 'textarea[name^=?]', 'tracker_settings[1][help_', 6
  end

  def test_global_settings_page_has_six_texts
    log_user('admin', 'admin')
    get '/settings/plugin/redmine_itil_priority'
    assert_response :success
    %w[impact urgency].product([1, 2, 3]).each do |field, level|
      assert_select 'textarea[name=?]', "settings[help_#{field}_#{level}]"
    end
    assert_select 'textarea[name=?]', 'settings[help_impact_3]', text: /The whole company/
    assert_select 'textarea[name=?]', 'settings[help_impact]', 0
  end

  def test_settings_tab_is_refused_without_the_permission
    log_user('dlopper', 'foo')
    get '/projects/ecookbook/settings/itil_priority'
    assert_select 'textarea[name^=?]', 'tracker_settings', 0
  end
end
