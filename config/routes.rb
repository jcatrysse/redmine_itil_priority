# frozen_string_literal: true

RedmineApp::Application.routes.draw do
  match '/projects/:id/itil_priority_settings',
        to: 'itil_priority_settings#update',
        via: [:post, :put, :patch],
        as: :project_itil_priority_settings

  match '/itil_priority/api/settings',
        to: 'itil_priority_settings_api#global',
        via: :get,
        defaults: { format: :json }
  match '/itil_priority/api/settings',
        to: 'itil_priority_settings_api#update_global',
        via: :put,
        defaults: { format: :json }
  match '/projects/:id/itil_priority/api/settings',
        to: 'itil_priority_settings_api#project',
        via: :get,
        defaults: { format: :json }
  match '/projects/:id/itil_priority/api/settings',
        to: 'itil_priority_settings_api#update_project',
        via: :put,
        defaults: { format: :json }
end
