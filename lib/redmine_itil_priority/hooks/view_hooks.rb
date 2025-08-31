# frozen_string_literal: true

module RedmineItilPriority
  module Hooks
    class ViewHooks < Redmine::Hook::ViewListener
      RedmineItilPriority.log { '[ITIL] Class ViewHooks loaded' }
      def view_issues_form_details_bottom(context = {})
        issue = context[:issue]
        project = context[:project]
        unless issue && project
          RedmineItilPriority.log { '[ITIL] missing issue or project, skipping issue form partial' }
          return ''
        end
        unless RedmineItilPriority.settings_for(project, issue.tracker)
          RedmineItilPriority.log do
            "[ITIL] no settings found for project #{project.identifier || project.id} " \
            "and tracker #{issue.tracker.id}, skipping issue form partial"
          end
          return ''
        end

        context[:controller].render_to_string(partial: 'issues/itil_priority', locals: context)
      end

      def view_issues_context_menu_end(context = {})
        issues = Array(context[:issues] || context[:issue]).compact
        if issues.empty?
          RedmineItilPriority.log { '[ITIL] missing issue, skipping context menu partial' }
          return ''
        end

        unless issues.all? { |i| RedmineItilPriority.settings_for(i.project, i.tracker) }
          RedmineItilPriority.log do
            '[ITIL] settings missing for some issues, skipping context menu partial'
          end
          return ''
        end

        context[:controller].render_to_string(partial: 'context_menus/itil_priority', locals: context)
      end

      def view_issues_bulk_edit_details_bottom(context = {})
        issue = context[:issues]&.first
        unless issue
          RedmineItilPriority.log { '[ITIL] missing issue, skipping bulk edit partial' }
          return ''
        end
        unless RedmineItilPriority.settings_for(issue.project, issue.tracker)
          RedmineItilPriority.log do
            "[ITIL] no settings found for project #{issue.project.identifier || issue.project.id} " \
            "and tracker #{issue.tracker.id}, skipping bulk edit partial"
          end
          return ''
        end

        context[:controller].render_to_string(partial: 'issues/itil_priority_bulk_edit', locals: context)
      end

    end
  end
end
