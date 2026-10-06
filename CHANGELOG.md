# Changelog
## Unreleased

* New permission "Override ITIL priority": without it a user sets impact and urgency only (form, bulk edit, context menu, REST API, mail); migration 004 grants it to every role that can add or edit issues
* The link between priority and impact/urgency is stored (migration 003, `issues.itil_priority_linked`): an unlinked priority survives later edits, is journalized and is in the REST API
* A priority set directly (context menu, bulk edit, API) that differs from the matrix unlinks the issue
* Impact and Urgency in the workflow's fields permissions (read-only, required)
* Optional explanation of the impact and urgency levels behind an info icon, per instance or per project and tracker
* Issue list columns, CSV/PDF and the history show impact and urgency labels instead of 1..3
* Redmine 7 webhooks carry impact_id, urgency_id and itil_priority_linked
* Fix: users who may only add notes could change impact and urgency, and through them the priority
* Impact, urgency and the link are not assignable (API, bulk edit) where ITIL priority is inactive
* Fix: setting changes reach every server process (Puma workers), and a project that gets the module later has the filters without a restart
* SVG icons on Redmine 6 and later (link toggle, context menu arrows)

* Fix the issue context menu on Redmine 6.0 and later (error 500: missing keywords :records, :associations)
* Allow activesupport 8, so Redmine 7.0 can bundle with the plugin installed
* REST API: journals of an issue have updated_on and updated_by again on Redmine 6.0 and later

## 0.0.2

* Cache project enabled check for improved performance

## 0.0.1

* Initial release with configurable priorities per project and tracker
