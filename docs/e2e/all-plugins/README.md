# All GEOxyz plugins installed (2026-10-07)

Redmine 7.0-stable-GEOxyz, PostgreSQL 16, production mode, this plugin together
with the redmine70-migration branches of 41 other GEOxyz plugins (public and
private, fetched 2026-10-07 ~16:15 UTC). Left out: redmine_issue_field_visibility,
whose alias chain on IssueQuery#initialize_available_filters recurses with
redmine_agile's prepend (stack overflow already in `rake redmine:load_default_data`).
The seeded Reporter role got redmine_view_issue_description's issue permissions,
which that plugin requires to open an issue at all.

Result: core 6, issue_form 14, issue_list 6, mail 4, rest_api 2, webhook 3,
workflow 4 screenshots, 0 problems. Smoke 13 screenshots, 1 problem:
Project > Settings HTTP 500, and settings.mjs stopped at the project tab for the
same reason: redmine_depending_custom_fields' tab partial calls
`dcf_relevant_custom_fields`, which ProjectsController's helpers do not contain
(that plugin includes its helper into ProjectsHelper after ProjectsController has
been loaded). Not caused by this plugin: the same with this plugin's tab patch
reverted. See docs/REDMINE7-MIGRATION.md for the run without that plugin.
