# frozen_string_literal: true

require 'set'

# Module containing helpers for ITIL priorities.
module RedmineItilPriority
  CACHE_PREFIX = 'itil_priority'
  ALLOWED_SETTING_KEY_PATTERN = /\A(?:label_(?:impact|urgency)_\d|priority_i\d_u\d|default_tracker_mode)\z/.freeze

  class << self
    attr_accessor :logging_enabled
  end

  module_function

  def cache_key(*parts)
    [CACHE_PREFIX, *parts].join('/').freeze
  end

  def clear_cache
    Rails.cache.delete_matched(/\A#{CACHE_PREFIX}\//)
    @settings_cache&.clear
  end

  def log(message = nil, level: :info, &block)
    return unless logging_enabled
    if block
      Rails.logger.public_send(level, &block)
    else
      Rails.logger.public_send(level, message)
    end
  end

  def global_settings
    Rails.cache.fetch(cache_key('global_settings')) do
      Setting['plugin_redmine_itil_priority'] || {}
    end.deep_dup
  end

  def project_settings(project)
    key = "plugin_redmine_itil_priority_project_#{project.id}"
    Setting.available_settings[key] ||= { 'serialized' => true, 'default' => {} }
    Rails.cache.fetch(cache_key('project_settings', project.id)) do
      Setting.find_by(name: key)&.value || {}
    end.deep_dup
  end

  # Returns settings hash for a project+tracker or nil when disabled.
  def settings_for(project, tracker)
    return nil unless project && tracker
    return nil unless project.module_enabled?(:itil_priority)

    @settings_cache ||= {}
    cache_id = [project.id, tracker.id]
    return @settings_cache[cache_id] if @settings_cache.key?(cache_id)

    ckey = cache_key('settings', project.id, tracker.id)

    @settings_cache[cache_id] = Rails.cache.fetch(ckey) do
      global = global_settings
      default_mode = global.delete('default_tracker_mode') || 'default'

      pset = project_settings(project)
      tset = pset['tracker_settings']

      # No project-level settings saved yet => use global based on default mode
      if tset.blank?
        log("[ITIL] settings_for: project=#{project.identifier} has no project settings")
        next nil if default_mode == 'inactive'
        next global.deep_dup
      end

      tr = tset[tracker.id.to_s]
      if tr.blank?
        log("[ITIL] settings_for: tracker #{tracker.id} not configured for project=#{project.identifier}")
        next nil if default_mode == 'inactive'
        next global.deep_dup
      end

      mode = tr['mode'] || 'custom'
      log("[ITIL] settings_for: project=#{project.identifier} tracker=#{tracker.id} mode=#{mode}")
      case mode
      when 'inactive'
        nil
      when 'default'
        global.deep_dup
      else
        merged = global.deep_dup
        tr.each do |k, v|
          next if k == 'mode'
          merged[k] = v unless v.blank?
        end
        merged
      end
    end
  end

  # Returns true if ITIL priority is enabled for at least one tracker in the
  # given project scope. When a project is provided, all its descendants are
  # checked as well. If no project is given, any active project with the module
  # enabled and configured trackers will enable the feature.
  def enabled_for_project?(project)
    if project
      projects = if project.respond_to?(:self_and_descendants)
                   project.self_and_descendants.includes(:trackers)
                 else
                   project.trackers.load
                   [project]
                 end
      projects.any? do |proj|
        next false unless proj.module_enabled?(:itil_priority)
        proj.trackers.any? { |t| settings_for(proj, t) }
      end
    else
      return true unless defined?(Project)
      Project.active.has_module(:itil_priority).includes(:trackers).any? do |proj|
        proj.trackers.any? { |t| settings_for(proj, t) }
      end
    end
  end

  def options_for(type, project = nil, tracker = nil)
    global = global_settings
    labels = Hash.new { |h, k| h[k] = Set.new }

    if tracker.nil?
      projects =
        if project.nil?
          if defined?(Project)
            Project.active.has_module(:itil_priority).includes(:trackers)
          else
            []
          end
        elsif project.respond_to?(:self_and_descendants)
          project.self_and_descendants.includes(:trackers)
        elsif project.respond_to?(:each)
          arr = project.to_a
          ActiveRecord::Associations::Preloader.new.preload(arr, :trackers)
          arr
        else
          project.trackers.load
          [project]
        end

      projects.each do |proj|
        proj.trackers.each do |t|
          settings = settings_for(proj, t)
          next unless settings
          [1, 2, 3].each do |i|
            key = "label_#{type}_#{i}"
            lbl = settings[key]
            next if lbl.blank? || lbl == global[key]
            labels[i] << lbl
          end
        end
      end

      return [1, 2, 3].flat_map do |i|
        if labels[i].empty?
          [[global["label_#{type}_#{i}"], i.to_s]]
        else
          labels[i].map { |lbl| [lbl, i.to_s] }
        end
      end
    end

    settings = settings_for(project, tracker) || global
    [1, 2, 3].map { |i| [settings["label_#{type}_#{i}"], i.to_s] }
  end

  def urgency_options(project = nil, tracker = nil)
    options_for('urgency', project, tracker)
  end

  def impact_options(project = nil, tracker = nil)
    options_for('impact', project, tracker)
  end

  def label(key, project = nil, tracker = nil)
    (settings_for(project, tracker) || global_settings)[key]
  end

  def impact_label(issue)
    return unless issue&.impact_id
    label("label_impact_#{issue.impact_id}", issue.project, issue.tracker)
  end

  def urgency_label(issue)
    return unless issue&.urgency_id
    label("label_urgency_#{issue.urgency_id}", issue.project, issue.tracker)
  end

  def filter_settings(raw)
    hash = if raw.respond_to?(:to_unsafe_h)
             raw.to_unsafe_h
           elsif raw.respond_to?(:to_h)
             raw.to_h
           else
             {}
           end
    hash.select { |k, _| k.match?(ALLOWED_SETTING_KEY_PATTERN) }
  end

  def filter_tracker_settings(raw)
    hash = if raw.respond_to?(:to_unsafe_h)
             raw.to_unsafe_h
           elsif raw.respond_to?(:to_h)
             raw.to_h
           else
             {}
           end
    hash.each_with_object({}) do |(id, cfg_raw), out|
      cfg = if cfg_raw.respond_to?(:to_unsafe_h)
              cfg_raw.to_unsafe_h
            elsif cfg_raw.respond_to?(:to_h)
              cfg_raw.to_h
            else
              {}
            end
      mode = cfg['mode'] || 'default'
      out[id] = { 'mode' => mode }
      next unless mode == 'custom'
      out[id].merge!(filter_settings(cfg))
    end
  end
end
