# frozen_string_literal: true

require File.expand_path('../test_helper', __dir__)

# Core methods that other GEOxyz plugins patch too are patched with prepend,
# never with alias_method: an alias chain on a method another plugin prepends
# on recurses (Project > Settings answered HTTP 500 with all plugins installed).
class ItilPrependedPatchesTest < ActiveSupport::TestCase
  PATCHES = {
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

  def test_settings_tabs_patch_sits_on_the_controller_helpers_not_in_projects_helper
    patch = RedmineItilPriority::Patches::ProjectsHelperPatch
    helpers = ProjectsController._helpers.ancestors
    assert_includes helpers, patch
    assert_operator helpers.index(patch), :<, helpers.index(ProjectsHelper)
    assert_not_includes ProjectsHelper.ancestors, patch
    all = ProjectsHelper.instance_methods + ProjectsHelper.private_instance_methods
    assert_empty all.grep(/_(with|without)_itil_priority\z/)
  end

  # What redmine_mail_digest does after this plugin has loaded: an alias chain
  # on ProjectsHelper. Applied the way init.rb applies the patch (on top of the
  # helper module, not inside it) the chain cannot copy this plugin's method.
  def test_project_settings_tabs_survive_an_alias_chain_installed_later
    helper = Module.new do
      def project_settings_tabs
        [{ name: 'info' }]
      end
    end
    controller_helpers = Module.new { include helper }
    controller_helpers.include(RedmineItilPriority::Patches::ProjectsHelperPatch)
    helper.module_eval do
      def project_settings_tabs_with_digest
        project_settings_tabs_without_digest + [{ name: 'digest' }]
      end
      alias_method :project_settings_tabs_without_digest, :project_settings_tabs
      alias_method :project_settings_tabs, :project_settings_tabs_with_digest
    end
    names = settings_tabs_of(controller_helpers)
    assert_equal %w[info digest itil_priority], names
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
    controller_helpers = Module.new { include helper }
    controller_helpers.include(RedmineItilPriority::Patches::ProjectsHelperPatch)
    assert_equal %w[info other_plugin itil_priority], settings_tabs_of(controller_helpers)
  end

  private

  def settings_tabs_of(helpers)
    view = Object.new.extend(helpers)
    project = Project.find(1)
    project.enable_module!(:itil_priority)
    view.instance_variable_set(:@project, project)
    User.current = User.find(1)
    view.project_settings_tabs.map { |t| t[:name] }
  ensure
    User.current = nil
  end

  public

  fixtures :projects, :users, :enabled_modules
end
