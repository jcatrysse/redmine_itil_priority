# frozen_string_literal: true

require_dependency 'setting'
require 'active_support/concern'

module RedmineItilPriority
  module Patches
    # Clears cached settings when a Setting related to the plugin changes.
    module SettingPatch
      extend ActiveSupport::Concern

      included do
        after_save do |record|
          next unless record.name.to_s.start_with?('plugin_redmine_itil_priority')

          RedmineItilPriority.clear_cache
        end
      end
    end
  end
end
