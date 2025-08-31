# frozen_string_literal: true

require 'rspec'
require 'logger'
require 'active_support'
require 'active_support/core_ext/object/blank'
require 'active_support/core_ext/object/deep_dup'
require 'active_support/concern'
require 'stringio'

class FakeRelation < Array
  def includes(*)
    self
  end
  def load
    self
  end
end

module ActiveRecord
  module Associations
    class Preloader
      def preload(*); end
    end
  end
end

def require_dependency(_name)
  # no-op for tests
end

  module Rails
    def self.logger
      @logger ||= Logger.new(StringIO.new)
    end

    def self.cache
      @cache ||= ActiveSupport::Cache::MemoryStore.new
    end
  end

class Setting
  SettingRecord = Struct.new(:name, :value) do
    def save
      Setting.values[name] = value
      Setting.run_after_save_callbacks(self)
      true
    end
  end

  class << self
    attr_accessor :values, :available_settings, :after_save_callbacks

    def [](key)
      raise "There's no setting named #{key}" unless values.key?(key)
      values[key]
    end

    def []=(key, value)
      values[key] = value
    end

    def find_by(name:)
      return nil unless values.key?(name)
      SettingRecord.new(name, values[name])
    end

    def find_or_initialize_by(name:)
      find_by(name: name) || SettingRecord.new(name, nil)
    end

    def after_save(method = nil, &block)
      cb = block || proc { |record| record.send(method) }
      (@after_save_callbacks ||= []) << cb
    end

    def run_after_save_callbacks(record)
      (@after_save_callbacks || []).each { |cb| cb.call(record) }
    end
  end
end

Setting.values ||= {}
Setting.available_settings ||= {}

require_relative '../lib/redmine_itil_priority'
require_relative '../lib/redmine_itil_priority/patches/issue_patch'
require_relative '../lib/redmine_itil_priority/patches/setting_patch'

Setting.include RedmineItilPriority::Patches::SettingPatch

RSpec.configure do |config|
  config.disable_monkey_patching!
  config.before(:each) do
    Rails.cache.clear
    RedmineItilPriority.clear_cache
  end
end
