# frozen_string_literal: true

require File.expand_path('../test_helper', __dir__)

# Core methods that other GEOxyz plugins patch too are patched with prepend,
# never with alias_method: an alias chain on a method another plugin prepends
# on recurses (Project > Settings answered HTTP 500 with all plugins installed).
class ItilPrependedPatchesTest < ActiveSupport::TestCase
  PATCHES = {
    ProjectsHelper => [RedmineItilPriority::Patches::ProjectsHelperPatch, :project_settings_tabs],
    IssueQuery => [RedmineItilPriority::Patches::IssueQueryPatch, :initialize_available_filters],
    MailHandler => [RedmineItilPriority::Patches::MailHandlerPatch, :issue_attributes_from_keywords]
  }.freeze

  def test_patches_are_prepended_without_alias_chains
    PATCHES.each do |target, (patch, method)|
      assert_includes target.ancestors.take_while { |a| a != target }, patch, "#{patch} must be prepended to #{target}"
      all = target.instance_methods + target.private_instance_methods
      assert_empty all.grep(/_(with|without)_itil_priority\z/), "#{target} still has an alias chain"
      assert target.instance_method(method).owner != target || target.ancestors.index(patch) < target.ancestors.index(target)
    end
    assert_includes IssueQuery.ancestors.take_while { |a| a != IssueQuery }, RedmineItilPriority::Patches::IssueQueryPatch
  end

  # What another plugin does: prepend on the same method and call super.
  def test_project_settings_tabs_combine_with_another_prepended_plugin
    helper = Module.new do
      def project_settings_tabs
        [{ name: 'info' }]
      end
    end
    other = Module.new do
      def project_settings_tabs
        super + [{ name: 'other_plugin' }]
      end
    end
    helper.prepend(other)
    helper.prepend(RedmineItilPriority::Patches::ProjectsHelperPatch)
    view = Object.new.extend(helper)
    project = Project.find(1)
    project.enable_module!(:itil_priority)
    view.instance_variable_set(:@project, project)
    User.current = User.find(1)

    names = view.project_settings_tabs.map { |t| t[:name] }
    assert_equal %w[info other_plugin itil_priority], names
  ensure
    User.current = nil
  end

  fixtures :projects, :users, :enabled_modules
end
