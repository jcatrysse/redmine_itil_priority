# frozen_string_literal: true

require File.expand_path('../test_helper', __dir__)

# Info icons next to impact and urgency, with a text per instance, and per
# project and tracker in the tracker's custom mode.
class ItilHelpTextsTest < Redmine::IntegrationTest
  include RedmineItilPriority::TestHelper
  fixtures(*FIXTURES)

  def setup
    itil_setup(Project.find(1), 'help_impact' => "* *Low*: one user\n* *Important*: everyone")
    role_with_override(1)
  end

  def test_form_shows_the_icon_and_the_text_only_where_there_is_one
    log_user('jsmith', 'jsmith')
    get '/issues/1/edit'
    assert_response :success
    assert_select 'a.itil-help-toggle[data-target=?]', 'itil_help_impact'
    assert_select 'a.itil-help-toggle[data-target=?]', 'itil_help_urgency', 0
    assert_select '#itil_help_impact.itil-help li', 2
    assert_select '#itil_help_urgency', 0
  end

  def test_text_is_sanitized
    itil_setup(Project.find(1), 'help_urgency' => '<script>alert(1)</script>')
    log_user('jsmith', 'jsmith')
    get '/issues/1/edit'
    assert_select '#itil_help_urgency script', 0
    assert_select '#itil_help_urgency', text: /alert\(1\)/
  end

  def test_tracker_custom_text_overrides_the_generic_one
    log_user('jsmith', 'jsmith')
    Role.find(1).add_permission!(:manage_itil_priority_settings)
    post '/projects/ecookbook/itil_priority_settings',
         params: { tracker_settings: { '1' => { mode: 'custom', help_impact: 'Project text for bugs', help_urgency: '' } } }
    assert_response :redirect

    get '/issues/1/edit'   # a bug
    assert_select '#itil_help_impact', text: /Project text for bugs/

    get '/issues/new', params: { project_id: 'ecookbook', issue: { tracker_id: 2 } }
    assert_select '#itil_help_impact', text: /everyone/

    get '/projects/ecookbook/settings/itil_priority'
    assert_select 'textarea[name=?]', 'tracker_settings[1][help_impact]', text: 'Project text for bugs'
  end

  def test_global_settings_page_has_the_texts
    log_user('admin', 'admin')
    get '/settings/plugin/redmine_itil_priority'
    assert_response :success
    assert_select 'textarea[name=?]', 'settings[help_impact]', text: /everyone/
    assert_select 'textarea[name=?]', 'settings[help_urgency]'
  end
end
