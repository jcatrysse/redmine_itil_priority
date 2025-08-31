# frozen_string_literal: true

class ItilPrioritySettingsController < ApplicationController
  before_action :find_project
  before_action :authorize

  def update
    tracker_settings = RedmineItilPriority.filter_tracker_settings(params[:tracker_settings])
    RedmineItilPriority.log("[ITIL] settings#update: tracker_settings=#{tracker_settings.inspect}")

    key = "plugin_redmine_itil_priority_project_#{@project.id}"
    Setting.available_settings[key] ||= { 'serialized' => true, 'default' => {} }
    record = Setting.find_or_initialize_by(name: key)
    settings = record.value ? record.value.deep_dup : {}
    settings['tracker_settings'] = tracker_settings
    record.value = settings

    if record.save
        RedmineItilPriority.log("[ITIL] settings#update: saved settings to #{key} for project=#{@project.identifier}")
      flash[:notice] = l(:notice_successful_update)
    else
        RedmineItilPriority.log(
          "[ITIL] settings#update: failed to save settings to #{key} for project=#{@project.identifier} " \
          "errors=#{record.errors.full_messages.join(', ')}"
        )
    end

    redirect_to settings_project_path(@project, tab: 'itil_priority')
  end
end
