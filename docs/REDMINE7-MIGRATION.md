# Redmine 7 migration: redmine_itil_priority

Start a Claude Code (or Codex) session on this repository, branch `redmine70-migration`, with:

> Read CLAUDE.md and docs/REDMINE7-MIGRATION.md, then carry out the Redmine 7 migration of this
> plugin as described there, on branch redmine70-migration. That includes the plugin's tests on
> PostgreSQL and MariaDB, every function exercised end to end on a real running Redmine in a
> browser (with and without permissions, failure paths included) with screenshots you looked at,
> and an OpenAI review of the diff when OPENAI_API_KEY is set. Report to me in Dutch at the end.

This file is the plan and the memory of that work. Update it as you go: verdicts, results,
what is left. Written 2026-10-06 from a measured analysis (report at the bottom).

## Status

| | |
|---|---|
| Plugin id | `redmine_itil_priority` |
| GEOxyz runs today | `master` |
| Upstream | geen |
| Runs on Redmine 7 as is | JA (baseline below); migration work done, see "Result" |
| Upstream sync | GEEN UPSTREAM |
| After sync | n.v.t. |
| Complexity (1 trivial .. 5 rewrite) | 1 |
| Measured on | Redmine 7.0.1 (7.0-stable-GEOxyz + latest 7.0-stable), Rails 8.1.3.1, Ruby 3.3.6, PostgreSQL 16 and MariaDB 10.11 |
| Branch head when this file was written | `d30ddf9` |
| Migration session | 2026-10-06, done; 2026-10-07 Jan's decisions built (prepend instead of alias_method, explanation per level), checked with all GEOxyz plugins installed |

## Already on this branch

Commits of the migration session (2026-10-06), oldest first:

| commit | what |
|---|---|
| 840377d | Impact and urgency only editable by who may edit the issue (security: notes-only users could change them, and so the priority) |
| 33ea77e | Store whether the priority is linked (migration 003, `issues.itil_priority_linked`); unlinked priority survives later edits; order-independent assignment; copy keeps it; REST API field |
| 03688e5 | Permission "override ITIL priority" (change request, migration 004 grants it to issue-editing roles) |
| 211335d | Impact and Urgency in the workflow's fields permissions; a priority set directly unlinks |
| 337bdc6 | History shows impact/urgency labels and the link as Yes/No |
| df287de | Webhook payloads carry impact, urgency and the link (Redmine 7) |
| 0a2d287 | SVG icons on Redmine 6+: link toggle, context menu arrows |
| 027b909 | Info icons that explain the impact and urgency levels (item 2) |
| 60f90c2 | Settings and module changes reach every server process |
| 7c98816, ae006a8, 8178233 | E2E scenarios; list columns show labels instead of 1..3 (found by the e2e run) |
| 36ec46e, 064b479, b944f8d | Redmine 5.1 run (test helper, info icon), before pictures, run together with the other GEOxyz plugins |

## Work list for the migration session

In this order: things that break, security, the GEOxyz changes, the open items, then the checks.

**Priority items**

1. Change request (include in this migration): helpdesk users may set only urgency and impact, never the priority; an operator can unlink the computed priority or change it. Build it on permissions (a new permission such as "override ITIL priority") and check how it combines with workflow field permissions (read-only/required per role and tracker) on priority_id, impact_id and urgency_id, so it also holds for issues created by mail (helpdesk) and through the REST API.
   **DONE** (03688e5, 211335d, with 33ea77e as prerequisite). Rules:
   - permission `override_itil_priority` (module ITIL priority). Without it, where ITIL is active for the issue's project and tracker, `priority_id` and `itil_priority_linked` are not safe attributes: the user sets impact and urgency, the priority follows the matrix. Core filters every assignment through safe attributes, so it holds for form, bulk edit, context menu, REST API and mail (tests and e2e for each).
   - workflow: `priority_id` read-only wins over the permission (no unlinking either). Impact and Urgency are now workflow fields of their own (read-only / required per role, tracker, status); "required" is dropped where ITIL is inactive for the issue.
   - the link is stored (`issues.itil_priority_linked`), so an operator's priority survives later edits by helpdesk users; only someone with the permission links it again (recalculates).
   - a priority set directly (context menu, bulk edit, API) that differs from the matrix unlinks the issue; with `itil_priority_linked=1` sent along, the matrix wins.
2. Nice to have: info icons next to impact and urgency that explain the levels, with the text manageable per instance, project and tracker (decide the storage: plugin settings for the instance, project settings tab, tracker-level override).
   **DONE** (027b909, 7c98816, 064b479). Storage: the settings the plugin already has, no new table: `help_impact` / `help_urgency` in the plugin settings (instance) and in the tracker's Custom mode on the project's ITIL priority tab (project + tracker; empty = generic text). Wiki-formatted, sanitized by Redmine. No text, no icon.
3. Webhooks: add impact_id/urgency_id to the webhook payload (core renders its own issues/show.api.rsb, not the plugin override).
   **DONE** (df287de): `Issue#webhook_payload_api_template` points at the plugin's show.api.rsb; payload has impact_id, urgency_id, itil_priority_linked. Proven by a unit test and by `test/e2e/webhook.mjs` (real delivery to a listener). Combines with redmine_view_issue_description's webhook patch (that one filters recipients).

**Open items from the analysis** (Dutch; where they conflict with a decision or a priority item above, those win)

4. issues/index.api.rsb en show.api.rsb overriden core; bij elke 7.0.x-update tegen core diffen (nu identiek op impact/urgency na)
   **DONE / blijvend**: `spec/views/issue_api_views_spec.rb` vergelijkt beide templates regel per regel met core van de Redmine waarin de tests lopen; enige toegestane extra regels: impact_id, urgency_id, itil_priority_linked en de 6.0-journalvelden. Groen op 7.0-stable-GEOxyz en 5.1-stable.
5. Webhooks (7.0) gebruiken core show.api.rsb: impact_id/urgency_id ontbreken in webhook-payload
   **DONE**: zie 3.

**Checks**

6. Run the plugin's whole test suite on Redmine 7.0-stable-GEOxyz with PostgreSQL AND MariaDB, and once on 5.1-stable if the branch is meant to stay 5.1-compatible.
   **DONE**, see "Result".
7. Verify every feature of the plugin by hand on a running Redmine 7 (screenshots).
   **DONE**, see "Inventory of functions" and "Result".

**Found and fixed during the session** (each with a test that fails without it)

8. Security: impact/urgency (and so the priority) were editable by users who may only add notes (840377d).
9. The unlinked state was not stored: the next edit relinked and recalculated the operator's priority (33ea77e; before picture `docs/e2e/before/issue_form-unlinked-reopened.png`).
10. Core's `Issue#priority_id=` shadows the plugin's (module included, not prepended): mapping a priority back to impact/urgency never ran in Redmine, only in the spec's fake class. Left as is (dead in Redmine, the spec keeps it); a directly set priority now unlinks instead (211335d). See open question 3.
11. Issue list columns, CSV and PDF showed 1..3 instead of labels: core's QueryColumn ignores a block (ae006a8).
12. Settings memo per process forever: other Puma/Passenger processes kept the old matrix; a project that got the module later had no filters until a restart (60f90c2).
13. Info icon unclickable behind the priority block (found by the e2e run, 7c98816); invisible on Redmine 5.1 (064b479).
14. Impact, urgency and the link were assignable through the REST API (or a bulk edit over mixed trackers) where ITIL is inactive; now not (OpenAI review finding).

**Decisions of 2026-10-07 and the run with all GEOxyz plugins**

19. alias_method replaced by prepend (Jan's general decision): IssueQuery#initialize_available_filters and #available_columns, MailHandler#issue_attributes_from_keywords (0aa2d54).
20. Project > Settings HTTP 500 with all plugins: prepending to ProjectsHelper was not enough, because redmine_mail_digest (loads later) alias-chains project_settings_tabs and copies a prepended method, whose super then has no target. The tab patch now sits on ProjectsController's helpers (26bafae), as redmine_ai_triage does.
21. Impact and Urgency missing from Workflow > Fields permissions with redmine_project_workflows: that plugin replaces WorkflowsController#permissions without super and loads later. Fixed here: the rows are added at render time (6ee3baf). **Still open in redmine_project_workflows**: its PermissionWriter whitelists only core field names (`Tracker::CORE_FIELDS_ALL` + custom fields), so with it installed a saved Impact/Urgency rule is dropped. That plugin must accept the field names WorkflowPermission accepts (e.g. by validating through WorkflowPermission).
22. Explanation per level (Jan's choice B), 1aa2729.

Recursions found with all GEOxyz plugins that are **not in this plugin** (alias chain mixed with prepends, each plugin's own session fixes it): redmine_extended_api `Issue#safe_attributes=` (fixed in that branch during this session), redmine_tint_issues `Issue#css_classes` (fixed during this session), redmine_issue_field_visibility `IssueQuery#initialize_available_filters` with redmine_agile (still open at the time of the run: stack overflow already in `rake redmine:load_default_data`, so it was left out of the combined run).

**Left (not done, with reason)**

15. The issue page (show) does not display impact and urgency, only the form does. Not asked; would be a small `view_issues_show_details_bottom` hook. Recommendation: add it in a follow-up if helpdesk users need to see them without opening the form.
16. Different labels per tracker are merged in filters across trackers (existing behaviour of `options_for`), unchanged.
17. `.codex/test_setup.sh` fails when run as root with `RMP_PROVISION_DB=1` (`$SUDO -u postgres` with an empty `$SUDO`). Worked around by creating the role by hand and `RMP_PROVISION_DB=0`; the script belongs to the migration kit, fix it there.
18. Migration kit: the manual CI workflow uploads `redmine/log/*.log` as an artifact; harmless with the throwaway test credentials, but better filtered or left out (OpenAI review, minor).

## GEOxyz changes to review or re-apply

Own plugin: all of it is GEOxyz code, so there is nothing to re-apply. While migrating, hold the code you touch to the rules below; list larger quality problems you find in the work list instead of fixing them in passing.

## After the upgrade (production)

Actions the person doing the upgrade must take, or know about, for this plugin:

- Run the plugin migrations (`rake redmine:plugins:migrate`): 003 adds `issues.itil_priority_linked` (boolean, default true, not null; existing issues stay linked, so they behave as before), 004 grants "Override ITIL priority" to every role with add_issues, edit_issues or edit_own_issues (builtin Non member and Anonymous included when they have those). Both are reversible (tested down to 0 and up on PostgreSQL and MariaDB).
- **Then remove "Override ITIL priority"** (Administration > Roles and permissions, module ITIL priority) from the roles of the people who must only classify: the helpdesk staff roles. Do **not** remove it from Anonymous: see the next step.
- **Helpdesk tickets from mail keep their configured priority** (Jan, 2026-10-07, round 2: "Helpdeskprioriteit behouden"). RedmineUP's helpdesk creates them as the anonymous user, so:
  1. Administration > Roles and permissions > **Anonymous** > section "ITIL priority": tick **Override ITIL priority**, Save (Redmine asks for your password again). Migration 004 only grants it to Anonymous if Anonymous can add or edit issues, so check it.
  2. Nothing per project: thanks to this plugin the Anonymous role's right counts while the helpdesk receives mail, also on private projects (where Redmine otherwise gives Anonymous no rights). Outside the helpdesk nothing changes for private projects.
  3. Check on public projects: there the anonymous web/API user gets the right too, but it only matters if Anonymous may add or edit issues there (GEOxyz: normally not).
  4. Verify: send a test mail to a helpdesk mailbox; the new ticket has the helpdesk's default priority (Project > Settings > Helpdesk), not Redmine's default.
- Optional: in Administration > Workflow > Fields permissions, make Impact and/or Urgency required or read-only where wanted.
- Optional: fill in the explanation texts (Administration > Plugins > ITIL priority, or per project and tracker in Custom mode).
- Webhooks: nothing to do; issue payloads now include impact_id, urgency_id and itil_priority_linked.
- Explanations: one text per level of impact and urgency (six fields) in the plugin settings, and per tracker in Custom mode on the project tab. Empty by default: no icon and no text until filled in.
- RedmineUP helpdesk: covered by the Anonymous step above.
- Issues whose priority was set by hand before the upgrade are stored as linked (the flag did not exist); the next edit through the form recalculates them, as it did before. Re-unlink them if needed.

## Inventory of functions

Screenshots in `docs/e2e/` (PostgreSQL run, Redmine 7.0-stable-GEOxyz, production mode); each `<scenario>.md` there lists them with user, URL and caption. "Before" pictures (master on Redmine 5.1) in `docs/e2e/before/`.

| function | how a user reaches it | scenario | screenshots |
|---|---|---|---|
| Global settings: default tracker mode, labels, matrix, help texts | Administration > Plugins > ITIL priority (admin) | settings.mjs, smoke | settings-global, settings-global-saved, smoke-11 |
| Project settings per tracker (inactive / generic / custom, own matrix, labels, help texts) | Project > Settings > ITIL priority (permission "Manage ITIL priority settings"); refused without | settings.mjs | settings-project-tab, settings-project-saved, settings-form-inactive, settings-form-custom, settings-reporter-refused |
| Issue form: impact x urgency gives the priority, live | new/edit issue | issue_form.mjs, core | issue_form-new-linked, -created, core-new-issue-form |
| Unlink / set priority by hand / link again (operator) | link icon on the form (permission "Override ITIL priority") | issue_form.mjs | issue_form-unlinked-edit, -unlinked-history, -unlinked-reopened, -relinked |
| Helpdesk user: impact and urgency only | form without the permission | issue_form.mjs | issue_form-helpdesk-edit, -helpdesk-saved, -helpdesk-new, -helpdesk-created |
| Explanation per level (Jan 2026-10-07): text of the chosen level under the field, all three behind the info icon; per instance and per tracker | issue form; plugin settings; project tab | issue_form.mjs, settings.mjs | issue_form-help-current, -help-impact, -help-helpdesk, settings-global, settings-project-tab, settings-form-custom |
| History labels and link Yes/No | issue page, history | issue_form.mjs, issue_list.mjs | issue_form-unlinked-history, -relinked, issue_list-context-menu-applied |
| Columns and filters Impact / Urgency | issue list, options and filters | issue_list.mjs | issue_list-columns-filter, -bulk-edit-result |
| Context menu Urgency / Impact | right click in the issue list; no Priority without the permission | issue_list.mjs, core | issue_list-context-menu-operator, -context-menu-helpdesk, -context-menu-applied, core-context-menu |
| Bulk edit Urgency / Impact | context menu > Bulk edit | issue_list.mjs | issue_list-bulk-edit-helpdesk, -bulk-edit-result |
| REST API: impact_id, urgency_id, itil_priority_linked on issues, with and without the permission | `/issues.json`, `/issues/:id.json` | rest_api.mjs | rest_api-calls, rest_api-issue |
| Settings API global (admin) and project (permission); 401/403 refusals | `/itil_priority/api/settings.json`, `/projects/:id/itil_priority/api/settings.json` | rest_api.mjs, smoke | rest_api-calls, smoke-13, smoke-14 |
| Incoming mail keywords Impact / Urgency / Priority / Itil priority linked | `POST /mail_handler` (rdm-mailhandler) | mail.mjs | mail-posted, mail-helpdesk, mail-operator, mail-unknown-label |
| Workflow field permissions Impact / Urgency (read-only, required) | Administration > Workflow > Fields permissions | workflow.mjs, smoke | workflow-permissions, -form, -required-error, -other-role, smoke-12 |
| Webhook payload (Redmine 7) | My account > Webhooks; issue created/updated | webhook.mjs | webhook-new-webhook, -webhook-list, -payloads |
| Outsider: private project invisible | non-member | issue_form.mjs, core | issue_form-outsider-refused, core-private-refused |
| Upgrade path: migrations 003/004 on an existing database | `rake redmine:plugins:migrate` | start_server on the baseline database, rollback test | (log, see Result) |

| RedmineUP helpdesk ticket from mail keeps the helpdesk priority when Anonymous has "Override ITIL priority" (Jan, 2026-10-07, round 2), default without; wrong key refused | `POST /helpdesk_mailer`; Administration > Roles > Anonymous | helpdesk_mail.mjs (skips without the helpdesk) | docs/e2e/all-plugins/helpdesk_mail-anonymous-role, -kept, -default, -posted |
| Together with all GEOxyz plugins: Project > Settings, issue list, issue page, inbound mail, REST API, webhook, workflow | every page, 41 other plugins installed | all scenarios | docs/e2e/all-plugins/ (README there), docs/e2e/all-plugins/without-dcf/ |

No rake tasks, cron jobs or macros in this plugin.

## Result (2026-10-07, after Jan's decisions)

PostgreSQL 16 only (Jan, 2026-10-07). Redmine 7.0-stable-GEOxyz.

| | this plugin alone | with 40 other GEOxyz plugins |
|---|---|---|
| minitest | 64 runs, 313 assertions, 0 failures | 63 runs, 310 assertions, 0 failures (before the last added test) |
| rspec | 60 examples, 0 failures | 60 examples, 0 failures |
| e2e | smoke 13, core 6, 7 scenarios, 59 screenshots, 0 problems (`docs/e2e/`) | all 42 except redmine_issue_field_visibility: 61 screenshots; 0 problems except Project > Settings 500 from redmine_depending_custom_fields (`docs/e2e/all-plugins/`); without that plugin too: smoke and settings 0 problems, Project > Settings 200 (`docs/e2e/all-plugins/without-dcf/`) |

Left out of the combined runs, not this plugin's problems: redmine_issue_field_visibility (alias chain on IssueQuery#initialize_available_filters recursing with redmine_agile, breaks already `rake redmine:load_default_data`), redmine_depending_custom_fields (its tab helper is missing from ProjectsController's helpers; Project > Settings 500 with or without this plugin's change).

## Result (2026-10-06)

Baseline before any change (7.0-stable-GEOxyz 8067e23, PostgreSQL 16): rspec 54 examples, 0 failures; e2e smoke 13 + core 6 screenshots, 0 problems.

| | Redmine 7.0-stable-GEOxyz, PostgreSQL 16.15 | Redmine 7.0-stable-GEOxyz, MariaDB 10.11.14 | Redmine 5.1-stable, PostgreSQL, Ruby 3.2 | 7.0 with 6 other GEOxyz plugins, PostgreSQL |
|---|---|---|---|---|
| minitest (test/, real Redmine) | 57 runs, 253 assertions, 0 failures | 57 runs, 253 assertions, 0 failures | 57 runs, 208 assertions, 0 failures, 2 skips (webhooks, SVG sprites: not in 5.1) | 57 runs, 253 assertions, 0 failures |
| rspec (spec/) | 59 examples, 0 failures | 59 examples, 0 failures | 59 examples, 0 failures | 59 examples, 0 failures |
| migrations down to 0 and up | OK | OK | n/a | n/a |
| e2e (real server, production mode) | smoke 14, core 6, 7 scenarios, 58 screenshots, 0 problems | same, 58 screenshots, 0 problems | smoke 14, core 6, 6 scenarios, 55 screenshots, 0 problems (webhook scenario n/a: no webhooks in 5.1) | 58 screenshots, 0 problems |

Numbers from the final code (after the review fix). The 5.1 and combined e2e runs are from b944f8d, before that last model-only change; their test suites were re-run on the final code.

Committed screenshots: the PostgreSQL run (`docs/e2e/`) and the before run (`docs/e2e/before/`); the MariaDB, 5.1 and combined runs were looked at and gave the same pictures, not committed.

Combined run: redmine70-migration branches of redmine_issue_field_visibility, redmine_parent_child_filters, redmine_view_issue_description, redmine_issue_view_columns, redmine_depending_custom_fields, custom_field_sql. Only interaction found: with redmine_view_issue_description a role needs its "view issue description" permission to open an issue at all (fixture roles in the tests, the seeded Reporter role in e2e). That is that plugin's design, not a conflict; the test helper grants it when present.

## Review

- Own adversarial review of the whole diff: findings 8 to 13 above came from tests and the e2e runs and are fixed; nothing open.
- OpenAI review (`./.codex/openai_review.sh`, gpt-5), two runs:
  - range 51cd4c0..b944f8d: "No findings" in both parts (`docs/reviews/openai-2026-10-06-b944f8d.md`).
  - range 51cd4c0..fae24d3 (after the docs): 3 major, 1 minor (`docs/reviews/openai-2026-10-06-fae24d3.md`, each with a Resolution line). Accepted and fixed: impact, urgency and the link were assignable through the API or a mixed bulk edit where ITIL is inactive (pre-existing), now dropped from the safe attributes there, with tests. Not needed: the context-menu finding (the hook already renders only when every selected issue has ITIL active). Not changed: the kit's CI workflow uploads redmine/log, which only holds throwaway test credentials; a point for the migration kit.
  - range 51cd4c0..b973017 (after the fix): the same minor CI-log point again, and one "major" on test/unit/settings_cache_test.rb that is a false positive (Redmine's Setting writes its YAML itself, no AR serialize; the test passes on both databases). Nothing new accepted, so the review loop stops here (`docs/reviews/openai-2026-10-06-b973017.md`).

- OpenAI review after Jan's decisions, two runs: 6d37772: two findings in tests (a test left a prepended module active for later tests; webhook scenario without a non-loopback address), both fixed in 3281330. 3281330: one claimed order dependence of impact/urgency on an inactive tracker, disproved with a test (core assigns tracker_id before filtering unsafe attributes), and the known CI-log point for the kit. Nothing new accepted. `docs/reviews/openai-2026-10-07-*.md`.

## Decided by Jan

All questions are answered; the record of 2026-10-07 is `docs/DECISIONS-2026-10-07.md` (from Jan's coordinating session).

1. **[Decided by Jan 2026-10-06: OK, as built]** **Migration 004 grants "Override ITIL priority" to every role that can add or edit issues.** Options: (a) grant on upgrade, remove from helpdesk roles afterwards (built: nobody loses anything on upgrade); (b) grant nothing, add it to the operator roles by hand (helpdesk users lose the priority at once, operators too until someone ticks it). Recommendation: (a).
2. **[Decided by Jan 2026-10-06: OK, as built]** **The link is stored in a new column `issues.itil_priority_linked`** (schema change not required by Redmine 7). Without it an operator's priority is undone by the next edit, so the change request cannot hold. Alternative: derive "unlinked" from "priority differs from the matrix" (no column, but every matrix change would mark old issues unlinked). Recommendation: keep the column.
3. **[Decided by Jan 2026-10-07: A, "Ontkoppelen, de gekozen prioriteit blijft (zo gebouwd)" (Zelfde resultaat als het link-icoon in het formulier; impact en urgentie blijven ongewijzigd.)]** Already built (211335d), kept. **A priority set directly on a linked issue (context menu, bulk edit, API) unlinks the issue.** The plugin's own code meant to map the priority back to impact and urgency instead, but that code never ran in Redmine (core's setter shadows it), and mapping back is ambiguous when several cells share a priority. Recommendation: keep unlinking.
4. **[Decided by Jan 2026-10-06: yes, as built]** **A helpdesk user who changes urgency on an issue an operator unlinked keeps the operator's priority** (impact/urgency are stored, the priority stays). Alternative: helpdesk changes recalculate and drop the operator's priority. Recommendation: keep it as built; the operator decided.
5. **[Decided by Jan 2026-10-07: B, "Een aparte tekst per niveau" (Preciezer, de uitleg kan bij het gekozen niveau verschijnen, maar zes velden per instantie en per tracker om te beheren.)]** Built in 1aa2729: six texts (help_impact_1..3, help_urgency_1..3) per instance and per tracker in Custom mode; the chosen level's text shows under the field, the info icon shows all three. Was: one text per field.
6. **[Decided by Jan 2026-10-07, round 2: "Helpdeskprioriteit behouden" (Dat account krijgt het recht, zodat helpdesktickets hun ingestelde prioriteit houden zoals vandaag.)]** RedmineUP helpdesk tickets from mail.
   - Measured on the combined installation: the helpdesk receives mail with `User.current = nil`, so new tickets are checked as the **anonymous** user (author: the sender's contact). Redmine gives the Anonymous role no rights on a private project, so on private helpdesk projects "give that account the right" could not work through roles alone (probe: Anonymous with the right, private project: still Normal).
   - Built: while the helpdesk receives mail (HelpdeskMailRecipient::IssueRecipient#receive, patched only when redmine_contacts_helpdesk is installed) the Anonymous role's "Override ITIL priority" counts on private projects too (`RedmineItilPriority.may_override_priority?`). Nowhere else. Tests: helpdesk_priority_test.rb (rule), helpdesk_mail_test.rb (a real helpdesk mail where the helpdesk is installed: Urgent with the right, default without; fails without the change), e2e `docs/e2e/all-plugins/helpdesk_mail-*` through `POST /helpdesk_mailer`.
   - A ticket created that way has no impact/urgency yet and stays linked: as soon as someone classifies it, the matrix decides (like any linked issue).
   - Still as before: the helpdesk mail-rule action "Issue priority" writes the priority directly (bypasses the permission, admin-configured) but does not unlink an existing issue, so the next form edit recalculates it. Left as is.

General decisions by Jan (2026-10-07), applied to this plan: GEOxyz goes straight to Redmine 7 (no 5.1 compatibility, no backports; `redmine70-migration` goes live), PostgreSQL 16 only (MariaDB runs no longer required), deface without a version constraint (not used by this plugin), core methods that other plugins patch too are patched with prepend (done, see work list 19 to 21), GitHub Actions manual only (unchanged).

## How to test

```sh
./.codex/redmine_clone.sh 7.0-stable-GEOxyz      # or 5.1-stable / 6.1-stable / 7.0-stable
./.codex/test_setup.sh                                 # RMP_DB=mariadb for MariaDB, RMP_PROVISION_DB=0 if a server runs
./.codex/test_plugin.sh                                # minitest + rspec of this plugin
```

```sh
./.codex/start_server.sh       # real Redmine (production mode) with this plugin, seeded users and projects
./.codex/e2e.sh                # browser: smoke over the plugin's pages, core issue flows, test/e2e/*.mjs
./.codex/openai_review.sh      # independent OpenAI review of the diff, only when OPENAI_API_KEY is set
```
Write one scenario per function in `test/e2e/<function>.mjs` (example at the top of
`.codex/e2e/lib.mjs`); screenshots and a table per scenario land in `docs/e2e/`. Users:
`admin`, `manager` (every permission), `reporter` (no plugin permissions), `outsider` (no
membership); password `Redmine7Test!`. Needs Node with Playwright and Chromium
(`npm install -g playwright && npx playwright install --with-deps chromium`).

On GitHub the same runs by hand only: Actions > "Redmine tests (manual)" > Run workflow (tick
"e2e" for the browser run; screenshots come back as an artifact).

The coordinator's harness (`plugin-check.sh` in the migration kit, kept outside this repo) adds a
browser smoke test of every page the plugin adds and runs all GEOxyz plugins together; the
results quoted in the analysis come from it.

## How the migration session works (same for every plugin)

1. **Start**: `git fetch && git checkout redmine70-migration && git pull`. Read this whole file,
   including the analysis report at the bottom. Do not reopen decisions recorded here.
2. **Baseline, before you change anything**:
   - the plugin's tests on Redmine 7.0-stable-GEOxyz with PostgreSQL;
   - a real running Redmine with this plugin (`./.codex/start_server.sh`) and the browser run
     (`./.codex/e2e.sh`: smoke over every page the plugin adds, plus the core issue flows).
   Write the numbers here. Something already broken now is a finding, not your regression.
3. **Inventory of functions**: list every function of the plugin in this file, in a table
   "function | how a user reaches it | scenario | screenshot". Take them from the README,
   `init.rb` (permissions, menus, settings, project modules), routes, hooks and view
   overrides, macros, mail handling, API endpoints, rake tasks and cron jobs. This table is the
   coverage list for step 8; a function that is not in it will not be tested.
4. **GEOxyz changes**: go through the table above, one item at a time. Each kept or re-made change
   is its own commit with a test that proves it. Record the verdict in the table.
5. **Work list**: then the numbered list, in order. One concern per commit.
6. **Database** (Jan, 2026-10-07): GEOxyz runs PostgreSQL 16 only. Tests and e2e run on
   PostgreSQL; keep SQL portable where that costs nothing, a MariaDB-only problem is a note, not a
   blocker. Migrations must be reversible and are run down and up on PostgreSQL.
7. **Together**: run with the other GEOxyz plugins installed (the migration kit's harness, or
   `RMP_EXTRA_PLUGINS`). A failure that only appears in combination is a finding to record here.
8. **End to end, visually, every function**: on the real Redmine from `start_server.sh`
   (production mode, the way GEOxyz runs it), write one scenario per function in
   `test/e2e/<function>.mjs` with `.codex/e2e/lib.mjs` and run them with `./.codex/e2e.sh`.
   - Each function as the users that matter: `admin`, `manager` (every permission, the
     plugin's included), `reporter` (member without the plugin's permissions), `outsider`
     (no membership, private project must stay invisible).
   - The failure paths too: setting off, permission absent, empty state, invalid input, the
     value that used to raise. A refusal that is shown is evidence as much as a success.
   - One screenshot per function and per path, with a caption saying what it proves. Open
     every screenshot and look at it: a picture nobody looked at proves nothing. Commit them
     in `docs/e2e/` and list them in the inventory table.
   - Functions without a page (mail in and out, REST API, rake tasks, cron, webhooks): exercise
     them against the same running instance (mails land in `redmine/tmp/mails`, `t.mails()`
     reads them; API through `t.page.request`) and record command and result.
   - Before pictures where behaviour or layout changes: the branch GEOxyz runs today, on
     Redmine 5.1, same scenarios, `RMP_E2E_OUT=docs/e2e/before`.
9. **Independent review**: first your own, adversarial: re-read the whole diff as if someone
   else wrote it and you are paid to reject it. Then, **when `OPENAI_API_KEY` is set in the
   session**, `./.codex/openai_review.sh`: it sends the diff of this branch to an OpenAI model
   and writes `docs/reviews/openai-<date>-<sha>.md`. Every finding gets a `Resolution:` line
   there (fixed in <commit>, with a test, or why not). Fix, re-run the tests and the e2e set,
   and run the review again until it has nothing new that you accept. Without the key: write
   "OpenAI review: skipped, no OPENAI_API_KEY" in the report; never send code anywhere else.
10. **After the upgrade**: anything the production upgrade must do for this plugin (data fixes,
    settings, cron, files, removed features) goes into the section "After the upgrade".
11. **Finish**: update "Status", the inventory and the work list in this file, push
    `redmine70-migration`, and report: what changed, test numbers on both databases, e2e
    numbers (scenarios, screenshots, problems), the review result, what is left, what needs Jan.

### Stop and ask Jan when
- a GEOxyz change would be lost or behave differently for users;
- a new gem, a new setting with user impact, or a schema change not required by Redmine 7 seems needed;
- the change would send data to an external service (the OpenAI review of the code diff is the
  one exception Jan approved, and only when the key is present);
- upstream and GEOxyz disagree on behaviour and both are defensible.

## Rules

- **Target**: Redmine 7.0-stable-GEOxyz (https://github.com/jcatrysse/redmine), Rails 8.1, Ruby 3.3+.
  Core sources for comparison: branches `5.1-stable`, `6.1-stable`, `7.0-stable`, `7.0-stable-GEOxyz`.
- **Evidence**: never report a test, lint, browser check or review as passed without having seen
  it. Quote the summary lines; list the screenshots. "Should work" is not a result, and a green
  test suite is not proof that a feature works in the browser.
- **Tests**: never skip, delete or weaken a test. A test that encodes Redmine 5 markup or
  behaviour is updated to Redmine 7, with the reason in the commit. Every fix gets a test that
  fails without it.
- **Minimal diffs** in the plugin's own style. No reformatting, no unrelated refactoring.
  Something wrong elsewhere: write it down here, do not fix it in passing.
- **Security**: authorization on every action and entry point; `safe_attributes`, never
  `to_unsafe_hash` into `update`; no SQL built from params; no secrets in logs; no `html_safe` on
  user input.
- **Webhooks (new in Redmine 7)**: core sends issue payloads (core `issues/show.api.rsb`, rendered
  as the webhook owner) to webhook endpoints, past plugin hooks and controller patches. If the
  plugin hides, adds or changes issue data, make webhooks consistent with that or record why not.
- **Redmine 7 conventions**: SVG icons through `sprite_icon` (the `icon icon-*` CSS is gone),
  Propshaft assets under `assets/` (`/assets/plugin_assets/<id>/...`), the new header and user menu,
  `ContextMenus::*Controller`, Loofah-based text formatting, Chart.js as an ES module, sudo mode
  (on by default: `t.sudo()` in a scenario). The breaker list is in the migration kit's CHECKLIST.md.
- **Locales**: keep the locales the plugin ships in sync; translate a new key by matching the
  closest existing key in the same file, not from scratch; do not add new languages.
- **Redmine 7 only** (Jan, 2026-10-07): GEOxyz goes straight to Redmine 7; no 5.1 compatibility,
  no backports, no code paths that exist only for 5.1. `redmine70-migration` is what goes live.
- **Patching core**: a core method that other installed plugins also patch is patched with
  `prepend` (or, for helpers, on the controller's helper chain), never with `alias_method`.
- **Git**: work on `redmine70-migration` only; never push to the default branch; never force-push
  a branch someone else uses. Descriptive commit messages (what and why). Push after every
  commit, together with the updated status in this file: a cloud session can stop at a usage
  limit, and work that is not pushed is lost with its container.
- **GitHub Actions**: manual only (`workflow_dispatch`). Do not add push, pull_request or schedule
  triggers.

## Definition of done

- All items of the work list are done or explicitly deferred with a reason, in this file.
- The plugin's tests are green on Redmine 7.0-stable-GEOxyz with PostgreSQL
  (numbers in this file); boot, production-like eager load, migrations up/down OK.
- Every function in the inventory exercised end to end on a real running Redmine, with and
  without permissions and on its failure paths; `./.codex/e2e.sh` green; screenshots looked at,
  committed in `docs/e2e/` and listed.
- Review done: your own, and the OpenAI review when the key is present, every finding resolved
  in `docs/reviews/`.
- No new failure when run together with the other GEOxyz plugins.
- "After the upgrade" lists every action production needs; "Status" is current.


## Analysis report (2026-10-06, Dutch)

# redmine_itil_priority
- Gebruikte branch: master @ a0e5f55 (2026-10-05) - plugin id redmine_itil_priority, versie 0.0.2
- Upstream: geen (eigen plugin, github.com/jcatrysse/redmine_itil_priority)
- Fork t.o.v. upstream: n.v.t.
- Andere relevante branches: geen.
- Migraties: 001_add_impact_and_urgency_to_issues, 002_add_impact_and_urgency_indexes_to_issues. Gemfile (test): `rspec`, `activesupport >= 6.1, < 9.0` (1dd4ae4 liet 8.x toe voor 7.0), `bigdecimal ~> 3.1`.

## 1. Werkt out of the box op Redmine 7?   JA
Harness `redmine_itil_priority@origin/master`, bijgewerkte harness (09:26), ROLLBACK=1 (1006-092706-s2):
- OK bundle, boot (0.0.2), eager load, plugin migrations dev+test
- OK rollback to 0 and back
- OK rspec: 54 examples, 0 failures
- OK smoke: 62/62 pages+actions zonder serverfout (2 plugin routes); geen deprecation warnings
(Eerdere Q1-run 1006-090652-s2 met rbenv-bin in PATH: identiek, 54 examples 0 failures, smoke 62/62.)

## 2. Upstream sync?   GEEN UPSTREAM

## 3. Werkt na sync op Redmine 7?   n.v.t.

## 4. Complexiteit en blokkers   score 1
- Blokkers: geen. a0e5f55 ("context menu and api issues on Redmine 6 and 7") heeft de API-templates al gelijkgetrokken met 7.0.
- Core view overrides (vervangen core-templates!): `app/views/issues/index.api.rsb` en `app/views/issues/show.api.rsb`. Diff t.o.v. core 7.0-stable: alleen `api.impact_id`/`api.urgency_id` toegevoegd, en in show een `if Redmine::VERSION::MAJOR >= 6` rond `updated_on`/`updated_by` van journals (op 7.0 dus identiek aan core). Bij elke 7.0.x-update opnieuw diffen tegen core.
- Stille breuken:
  - NIEUW in 7.0: webhooks (#29664) renderen `Rails.root/app/views/issues/show.api.rsb` (lib/redmine/acts/webhookable.rb:67-68), dus de core-template en niet de plugin-override: `impact_id`/`urgency_id` ontbreken in webhook-payloads. Alleen relevant als webhooks gebruikt worden.
- Gepatchte core-methodes 5.1 vs 7.0 (bestaan nog, zelfde signatuur): `IssueQuery#initialize_available_filters`/`#available_columns` (alias_method), `ProjectsHelper#project_settings_tabs` (alias_method), `MailHandler#issue_attributes_from_keywords(issue)` (alias_method), `Setting` after_save. Context menu-partial gebruikt `@safe_attributes`, `@priorities`, `@issue_ids`, `@can`, `@back` - allemaal nog gezet door `ContextMenus::IssuesController#issues` in 7.0.
- Overlap met Redmine 7 core: geen.
- Pairwise (statisch): `IssueQuery#initialize_available_filters`/`#available_columns` ook door redmine_issue_field_visibility (alias, laadt eerder) en redmine_parent_child_filters (prepend, laadt later) - volgorde veilig. `issues/show.api.rsb`-override vs redmine_view_issue_description (injecteert in de response na rendering) - compatibel. Hooks `view_issues_form_details_bottom` / `view_issues_bulk_edit_details_bottom` gedeeld met custom_field_sql; `view_issues_context_menu_end` met redmine_issue_view_columns. `ProjectsHelper#project_settings_tabs` keten met redmine_depending_custom_fields en redmine_issue_view_columns.
- Open werk voor ansif: geen voor de migratie; bij gebruik van webhooks impact/urgency in de payload toevoegen (bv. `Issue#webhook_payload` uitbreiden).

## Branch redmine70-migration
- Niet aangemaakt: geen fixes nodig.
- Eindresultaat harness: OK bundle/boot/eager/migrations, OK rollback, rspec 54 examples 0 failures, smoke 62/62.
- Rollback migraties: OK


## Aanvulling coordinator
Branch `redmine70-migration` is wel gepusht, als startpunt zonder commits: gelijk aan de gebruikte branch (a0e5f55). Fixes die hierboven als diff staan, zijn nog niet gecommit.

