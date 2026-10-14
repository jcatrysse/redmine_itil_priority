# frozen_string_literal: true

require 'set'

# Module containing helpers for ITIL priorities.
module RedmineItilPriority
  CACHE_PREFIX = 'itil_priority'
  ALLOWED_SETTING_KEY_PATTERN = /\A(?:label_(?:impact|urgency)_\d|help_(?:impact|urgency)_[1-3]|priority_i\d_u\d|default_tracker_mode)\z/.freeze

  class << self
    attr_accessor :logging_enabled
  end

  module_function

  def cache_key(*parts)
    [CACHE_PREFIX, *parts].join('/').freeze
  end

  def clear_cache
    Rails.cache.delete_matched(/\A#{CACHE_PREFIX}\//)
    clear_memo
  end

  # The in-process memos live for one request: core calls Setting.check_cache
  # at the start of each, see SettingPatch.
  def clear_memo
    @settings_cache&.clear
    @enabled_cache&.clear
    @project_settings_cache&.clear
    @projects_cache&.clear
    @enabled_project_ids = nil
    @global_settings = nil
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
    @global_settings ||= Rails.cache.fetch(cache_key('global_settings')) do
      Setting['plugin_redmine_itil_priority'] || {}
    end.deep_dup
    @global_settings.deep_dup
  end

  def project_settings_key(project_id)
    key = "plugin_redmine_itil_priority_project_#{project_id}"
    Setting.available_settings[key] ||= { 'serialized' => true, 'default' => {} }
    key
  end

  def project_settings(project)
    key = project_settings_key(project.id)
    return @project_settings_cache[project.id].deep_dup if @project_settings_cache&.key?(project.id)

    Rails.cache.fetch(cache_key('project_settings', project.id)) do
      Setting.find_by(name: key)&.value || {}
    end.deep_dup
  end

  # The settings of many projects in one query, kept for the request, so a
  # list over every project costs the same with 10 projects as with 1000.
  def preload_project_settings(projects)
    return unless Setting.respond_to?(:where)

    @project_settings_cache ||= {}
    missing = projects.map(&:id).uniq - @project_settings_cache.keys
    return if missing.empty?

    keys = missing.index_by { |id| project_settings_key(id) }
    found = Setting.where(name: keys.keys).to_h { |setting| [keys[setting.name], setting.value || {}] }
    missing.each { |id| @project_settings_cache[id] = found[id] || {} }
  end

  # Ids of the projects with the module enabled, one query per request.
  def enabled_project_ids
    @enabled_project_ids ||= EnabledModule.where(name: 'itil_priority').distinct.pluck(:project_id).to_set
  end

  def module_enabled?(project)
    return project.module_enabled?(:itil_priority) unless defined?(EnabledModule)

    enabled_project_ids.include?(project.id)
  end

  # Returns settings hash for a project+tracker or nil when disabled.
  # module_checked: from itil_projects, which checked the module and preloaded
  # the project settings; no Rails.cache read per tracker then.
  def settings_for(project, tracker, module_checked: false)
    return nil unless project && tracker
    return nil unless module_checked || project.module_enabled?(:itil_priority)

    @settings_cache ||= {}
    cache_id = [project.id, tracker.id]
    return @settings_cache[cache_id] if @settings_cache.key?(cache_id)

    @settings_cache[cache_id] =
      if module_checked
        merge_settings(project, tracker, global_settings)
      else
        Rails.cache.fetch(cache_key('settings', project.id, tracker.id)) do
          merge_settings(project, tracker, global_settings)
        end
      end
  end

  def merge_settings(project, tracker, global)
    default_mode = global.delete('default_tracker_mode') || 'default'

    pset = project_settings(project)
    tset = pset['tracker_settings']

    # No project-level settings saved yet => use global based on default mode
    if tset.blank?
      log("[ITIL] settings_for: project=#{project.identifier} has no project settings")
      return nil if default_mode == 'inactive'
      return global.deep_dup
    end

    tr = tset[tracker.id.to_s]
    if tr.blank?
      log("[ITIL] settings_for: tracker #{tracker.id} not configured for project=#{project.identifier}")
      return nil if default_mode == 'inactive'
      return global.deep_dup
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

  # Whether the user may set the priority by hand or unlink it in the project.
  #
  # RedmineUP's helpdesk creates tickets from mail as the anonymous user
  # (User.current is nil while it receives), and Redmine gives the Anonymous
  # role no permissions on a private project. So that helpdesk tickets keep
  # the helpdesk's configured priority (Jan, 2026-10-07: "Helpdeskprioriteit
  # behouden"), the Anonymous role's permission counts while the helpdesk
  # receives mail, on private projects too. Nowhere else.
  def may_override_priority?(user, project)
    return true if user.allowed_to?(:override_itil_priority, project)

    helpdesk_mail? && user.anonymous? && project.respond_to?(:module_enabled?) &&
      project.module_enabled?(:itil_priority) && Role.anonymous.has_permission?(:override_itil_priority)
  end

  # Marks the block as the helpdesk receiving mail (see may_override_priority?).
  def helpdesk_mail
    previous = Thread.current[:itil_priority_helpdesk_mail]
    Thread.current[:itil_priority_helpdesk_mail] = true
    yield
  ensure
    Thread.current[:itil_priority_helpdesk_mail] = previous
  end

  def helpdesk_mail?
    Thread.current[:itil_priority_helpdesk_mail] == true
  end

  # Returns true if ITIL priority is enabled for at least one tracker in the
  # given project scope. When a project is provided, all its descendants are
  # checked as well. If no project is given, any active project with the module
  # enabled and configured trackers will enable the feature.
  def enabled_for_project?(project)
    @enabled_cache ||= {}
    cache_id = project ? project.id : :all
    return @enabled_cache[cache_id] if @enabled_cache.key?(cache_id)

    return true if project.nil? && !defined?(Project)

    @enabled_cache[cache_id] = itil_projects(project).any? do |proj|
      proj.trackers.any? { |t| settings_for(proj, t, module_checked: true) }
    end
  end

  # The projects with the module enabled that a list over the project covers
  # (it and its subprojects, or every active project without one), their
  # trackers loaded and settings preloaded: the same number of queries
  # whatever the number of projects, once per request.
  def itil_projects(project)
    @projects_cache ||= {}
    cache_id = project.nil? ? :all : (project.id if project.respond_to?(:self_and_descendants))
    return @projects_cache[cache_id] if cache_id && @projects_cache.key?(cache_id)

    projects =
      if project.nil?
        defined?(Project) ? Project.active.has_module(:itil_priority).includes(:trackers).to_a : []
      elsif project.respond_to?(:self_and_descendants)
        project.self_and_descendants.includes(:trackers).select { |proj| module_enabled?(proj) }
      elsif project.respond_to?(:each)
        arr = project.to_a
        preload_trackers(arr)
        arr.select { |proj| proj.module_enabled?(:itil_priority) }
      else
        project.trackers.load
        [project].select { |proj| proj.module_enabled?(:itil_priority) }
      end
    preload_project_settings(projects)
    cache_id ? (@projects_cache[cache_id] = projects) : projects
  end

  # Rails 7 (Redmine 6.0 and later) replaced Preloader.new.preload(records,
  # associations) with Preloader.new(records:, associations:).call.
  def preload_trackers(projects)
    preloader = ActiveRecord::Associations::Preloader
    if preloader.method_defined?(:call)
      preloader.new(records: projects, associations: :trackers).call
    else
      preloader.new.preload(projects, :trackers)
    end
  end

  def options_for(type, project = nil, tracker = nil)
    global = global_settings
    labels = Hash.new { |h, k| h[k] = Set.new }

    if tracker.nil?
      itil_projects(project).each do |proj|
        proj.trackers.each do |t|
          settings = settings_for(proj, t, module_checked: true)
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

  # The explanation per level of impact or urgency ('impact' / 'urgency'),
  # {level => text} for the levels that have one.
  def help_texts(settings, type)
    return {} unless settings

    (1..3).each_with_object({}) do |level, texts|
      text = settings["help_#{type}_#{level}"]
      texts[level] = text if text.present?
    end
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
