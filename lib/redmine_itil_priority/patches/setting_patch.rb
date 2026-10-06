# frozen_string_literal: true

require_dependency 'setting'
require 'active_support/concern'

module RedmineItilPriority
  module Patches
    # Clears cached settings when a Setting related to the plugin changes,
    # in this process and in the others.
    module SettingPatch
      extend ActiveSupport::Concern

      included do
        after_save do |record|
          next unless record.name.to_s.start_with?('plugin_redmine_itil_priority')

          RedmineItilPriority.clear_cache
        end
        singleton_class.prepend ClassMethods if respond_to?(:check_cache)
      end

      # after_save clears the caches in the process that saved; other server
      # processes learn about it the way core does for its own settings.
      module ClassMethods
        # Called by core at the start of every request.
        def check_cache
          RedmineItilPriority.clear_memo
          super
        end

        # Called when a setting changed in the database, by any process.
        def clear_cache
          super
          RedmineItilPriority.clear_cache
        end
      end
    end
  end
end
