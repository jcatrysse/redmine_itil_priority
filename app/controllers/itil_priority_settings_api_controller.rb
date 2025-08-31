# frozen_string_literal: true

class ItilPrioritySettingsApiController < ApplicationController
  before_action :require_admin, only: [:global, :update_global]
  before_action :find_project, :authorize, only: [:project, :update_project]
  accept_api_auth :global, :update_global, :project, :update_project

  def global
    render json: Setting['plugin_redmine_itil_priority'] || {}
  end

  def update_global
    settings = RedmineItilPriority.filter_settings(params[:settings])
    record = Setting.find_or_initialize_by(name: 'plugin_redmine_itil_priority')
    current = record.value ? record.value.deep_dup : {}
    current.merge!(settings)
    record.value = current
    record.save
    render json: current
  end

  def project
    key = "plugin_redmine_itil_priority_project_#{@project.id}"
    proj_settings = Setting.find_by(name: key)&.value || {}
    tracker_settings = proj_settings['tracker_settings'] || {}
    trackers = {}
    @project.trackers.each do |tracker|
      raw = tracker_settings[tracker.id.to_s] || {}
      mode = raw['mode'] || 'default'
      trackers[tracker.id.to_s] = {
        'mode' => mode,
        'settings' => RedmineItilPriority.settings_for(@project, tracker)
      }
    end
    render json: { 'tracker_settings' => trackers }
  end

  def update_project
    tracker_settings = RedmineItilPriority.filter_tracker_settings(params[:tracker_settings])
    key = "plugin_redmine_itil_priority_project_#{@project.id}"
    Setting.available_settings[key] ||= { 'serialized' => true, 'default' => {} }
    record = Setting.find_or_initialize_by(name: key)
    settings = record.value ? record.value.deep_dup : {}
    settings['tracker_settings'] = tracker_settings
    record.value = settings
    record.save
    project
  end
end
