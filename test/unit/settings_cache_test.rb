# frozen_string_literal: true

require File.expand_path('../test_helper', __dir__)

# Settings saved by another server process, or a module enabled since, must
# reach this process at its next request (core calls Setting.check_cache).
class ItilSettingsCacheTest < ActiveSupport::TestCase
  include RedmineItilPriority::TestHelper
  fixtures(*FIXTURES)

  def setup
    itil_setup
    @project = Project.find(1)
    @tracker = Tracker.find(1)
  end

  def test_settings_changed_by_another_process_are_seen_after_check_cache
    assert_equal '7', RedmineItilPriority.settings_for(@project, @tracker)['priority_i3_u3']

    # what another process does: the row changes, this process's callbacks do not run
    record = Setting.find_by(name: 'plugin_redmine_itil_priority')
    record.value = record.value.merge('priority_i3_u3' => '8')
    Setting.where(id: record.id).update_all(value: record.read_attribute(:value), updated_on: 1.minute.from_now)
    assert_equal '7', RedmineItilPriority.settings_for(@project, @tracker)['priority_i3_u3'], 'still memoized'

    Setting.check_cache
    assert_equal '8', RedmineItilPriority.settings_for(@project, @tracker)['priority_i3_u3']
  end

  def test_module_enabled_later_is_seen_at_the_next_request
    project = Project.find(2)
    project.disable_module!(:itil_priority)
    RedmineItilPriority.clear_cache
    assert_not RedmineItilPriority.enabled_for_project?(project)

    project.enable_module!(:itil_priority)
    Setting.check_cache
    assert RedmineItilPriority.enabled_for_project?(Project.find(2))
  end
end
