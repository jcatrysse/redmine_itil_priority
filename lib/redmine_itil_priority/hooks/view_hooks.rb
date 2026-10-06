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

      # The history stores impact and urgency as 1..3 and the link as 0/1:
      # show the configured labels and Yes/No instead. Only the in-memory
      # detail changes, and only raw values, so a second rendering (html and
      # text mail) leaves the labels alone.
      def helper_issues_show_detail_after_setting(context = {})
        detail = context[:detail]
        return '' unless detail && detail.property == 'attr'

        case detail.prop_key
        when 'impact_id', 'urgency_id'
          issue = detail.journal&.journalized
          field = detail.prop_key.delete_suffix('_id')
          %i[value old_value].each do |attr|
            raw = detail.send(attr).to_s
            next unless raw.match?(/\A[1-3]\z/)

            label = RedmineItilPriority.label("label_#{field}_#{raw}", issue&.project, issue&.tracker)
            detail.send("#{attr}=", label) if label.present?
          end
        when 'itil_priority_linked'
          %i[value old_value].each do |attr|
            raw = detail.send(attr).to_s
            detail.send("#{attr}=", l(raw == '0' ? :general_text_No : :general_text_Yes)) if %w[0 1].include?(raw)
          end
        end
        ''
      end

    end
  end
end
