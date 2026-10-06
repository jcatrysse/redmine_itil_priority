# Before: the plugin as GEOxyz runs it today

Branch `master` (a0e5f55) on Redmine 5.1-stable, Ruby 3.2, PostgreSQL, run
2026-10-06 with the same scenarios (`RMP_E2E_OUT=docs/e2e/before`). The
scenarios check the new behaviour, so where the old one differs they fail
or stop; that is the point of these pictures.

| screenshot | shows (before) |
|---|---|
| ![](issue_form-new-linked.png) | New issue as operator: impact x urgency gives the priority (unchanged) |
| ![](issue_form-unlinked-edit.png) | The operator unlinks and sets Immediate |
| ![](issue_form-unlinked-history.png) | Saved: priority Immediate; no trace in the history that it was unlinked |
| ![](issue_form-unlinked-reopened.png) | Opening the form again: the issue shows as linked and the priority is recalculated (Urgent): saving anything would undo the operator's Immediate |
| ![](issue_form-helpdesk-edit.png) | Helpdesk user (role without plugin permissions): the priority can be unlinked and set by anyone who edits the issue |
| ![](issue_form-helpdesk-saved.png) | After the helpdesk user changed the urgency the operator's Immediate is gone (back to Urgent); history says "Urgency changed from 3 to 1" |
| ![](issue_form-helpdesk-new.png) | Helpdesk user, new issue: has the priority link toggle too |
| ![](issue_form-helpdesk-created.png) | Created by the helpdesk user |
| ![](issue_form-relinked.png) | Relinked by the operator |
| ![](issue_form-created.png) | Created issue |
| ![](issue_list-columns-filter.png) | Issue list: the Impact and Urgency columns show 1, 2, 3 instead of the labels |
| ![](issue_list-context-menu-operator.png) | Context menu as operator |
| ![](issue_list-context-menu-applied.png) | Urgency set through the context menu; history shows numbers |
| ![](issue_list-context-menu-helpdesk.png) | Context menu as helpdesk user: Priority is there |
| ![](issue_list-bulk-edit-helpdesk.png) | Bulk edit as helpdesk user: Priority is there |
| ![](issue_list-bulk-edit-result.png) | Bulk edit result |

The run stopped at the info icon (new) in issue_form.mjs; issue_list.mjs
reported "Priority present" for the helpdesk user twice, as expected.
