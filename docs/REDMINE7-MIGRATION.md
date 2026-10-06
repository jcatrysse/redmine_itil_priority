# Redmine 7 migration: redmine_itil_priority

Start a Claude Code (or Codex) session on this repository, branch `redmine70-migration`, with:

> Read CLAUDE.md and docs/REDMINE7-MIGRATION.md, then carry out the Redmine 7 migration of this
> plugin as described there, on branch redmine70-migration. Report to me in Dutch at the end.

This file is the plan and the memory of that work. Update it as you go: verdicts, results,
what is left. Written 2026-10-06 from a measured analysis (report at the bottom).

## Status

| | |
|---|---|
| Plugin id | `redmine_itil_priority` |
| GEOxyz runs today | `master` |
| Upstream | geen |
| Runs on Redmine 7 as is | JA |
| Upstream sync | GEEN UPSTREAM |
| After sync | n.v.t. |
| Complexity (1 trivial .. 5 rewrite) | 1 |
| Measured on | Redmine 7.0.1 (7.0-stable-GEOxyz + latest 7.0-stable), Rails 8.1.3.1, Ruby 3.3.6, PostgreSQL 16 and MariaDB 10.11 |
| Branch head when this file was written | `a0e5f55` |

## Already on this branch

- nothing: the branch equals the branch GEOxyz runs today.

## Work list for the migration session

In this order: things that break, security, the GEOxyz changes, the open items, then the checks.

**Priority items**

1. Change request (include in this migration): helpdesk users may set only urgency and impact, never the priority; an operator can unlink the computed priority or change it. Build it on permissions (a new permission such as "override ITIL priority") and check how it combines with workflow field permissions (read-only/required per role and tracker) on priority_id, impact_id and urgency_id, so it also holds for issues created by mail (helpdesk) and through the REST API.
2. Nice to have: info icons next to impact and urgency that explain the levels, with the text manageable per instance, project and tracker (decide the storage: plugin settings for the instance, project settings tab, tracker-level override).
3. Webhooks: add impact_id/urgency_id to the webhook payload (core renders its own issues/show.api.rsb, not the plugin override).

**Open items from the analysis** (Dutch; where they repeat a priority item, the priority item wins)

4. issues/index.api.rsb en show.api.rsb overriden core; bij elke 7.0.x-update tegen core diffen (nu identiek op impact/urgency na)
5. Webhooks (7.0) gebruiken core show.api.rsb: impact_id/urgency_id ontbreken in webhook-payload

**Checks**

6. Run the plugin's whole test suite on Redmine 7.0-stable-GEOxyz with PostgreSQL AND MariaDB, and once on 5.1-stable if the branch is meant to stay 5.1-compatible.
7. Verify every feature of the plugin by hand on a running Redmine 7 (screenshots).

## GEOxyz changes to review or re-apply

Own plugin: all of it is GEOxyz code, so there is nothing to re-apply. While migrating, hold the code you touch to the rules below; list larger quality problems you find in the work list instead of fixing them in passing.

## After the upgrade (production)

Actions the person doing the upgrade must take, or know about, for this plugin:

- None known. Add here what the session finds.

## How to test

```sh
./.codex/redmine_clone.sh 7.0-stable-GEOxyz      # or 5.1-stable / 6.1-stable / 7.0-stable
./.codex/test_setup.sh                                 # RMP_DB=mariadb for MariaDB, RMP_PROVISION_DB=0 if a server runs
./.codex/test_plugin.sh                                # minitest + rspec of this plugin
```
On GitHub the same runs by hand only: Actions > "Redmine tests (manual)" > Run workflow.

The coordinator's harness (`plugin-check.sh` in the migration kit, kept outside this repo) adds a
browser smoke test of every page the plugin adds and runs all GEOxyz plugins together; the
results quoted in the analysis come from it.

## How the migration session works (same for every plugin)

1. **Start**: `git fetch && git checkout redmine70-migration && git pull`. Read this whole file,
   including the analysis report at the bottom. Do not reopen decisions recorded here.
2. **Baseline**: set up Redmine 7.0-stable-GEOxyz and run the plugin's tests on PostgreSQL and
   on MariaDB (see "How to test"). Write the numbers here before you change anything.
3. **GEOxyz changes**: go through the table above, one item at a time. Each kept or re-made change
   is its own commit with a test that proves it. Record the verdict in the table.
4. **Work list**: then the numbered list, in order. One concern per commit.
5. **Portability**: everything must run on Redmine's supported databases (PostgreSQL,
   MySQL/MariaDB; SQLite where the plugin already supports it). Migrations must be reversible and
   are run down and up on PostgreSQL and MariaDB.
6. **Browser**: start a Redmine 7 with this plugin, exercise every feature as admin and as a
   normal user with and without the plugin's permissions, and save screenshots (before on 5.1 or
   the old branch, after on 7.0) where behaviour or layout matters.
7. **Together**: run with the other GEOxyz plugins installed (the migration kit's harness, or
   `RMP_EXTRA_PLUGINS`). A failure that only appears in combination is a finding to record here.
8. **After the upgrade**: anything the production upgrade must do for this plugin (data fixes,
   settings, cron, files, removed features) goes into the section "After the upgrade".
9. **Finish**: update "Status" and the work list in this file, push `redmine70-migration`, and
   report: what changed, test numbers on both databases, what is left, what needs Jan.

### Stop and ask Jan when
- a GEOxyz change would be lost or behave differently for users;
- a new gem, a new setting with user impact, or a schema change not required by Redmine 7 seems needed;
- the change would send data to an external service;
- upstream and GEOxyz disagree on behaviour and both are defensible.

## Rules

- **Target**: Redmine 7.0-stable-GEOxyz (https://github.com/jcatrysse/redmine), Rails 8.1, Ruby 3.3+.
  Core sources for comparison: branches `5.1-stable`, `6.1-stable`, `7.0-stable`, `7.0-stable-GEOxyz`.
- **Evidence**: never report a test, lint or browser check as passed without having seen it.
  Quote the summary lines. "Should work" is not a result.
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
  `ContextMenus::*Controller`, Loofah-based text formatting, Chart.js as an ES module.
  The breaker list is in the migration kit's CHECKLIST.md.
- **Locales**: keep the locales the plugin ships in sync; translate a new key by matching the
  closest existing key in the same file, not from scratch; do not add new languages.
- **5.1 compatibility**: prefer fixes that also run on Redmine 5.1 so they can be merged early;
  say so when a fix cannot.
- **Git**: work on `redmine70-migration` only; never push to the default branch; never force-push
  a branch someone else uses. Descriptive commit messages (what and why).
- **GitHub Actions**: manual only (`workflow_dispatch`). Do not add push, pull_request or schedule
  triggers.

## Definition of done

- All items of the work list are done or explicitly deferred with a reason, in this file.
- The plugin's tests are green on Redmine 7.0-stable-GEOxyz with PostgreSQL and MariaDB
  (numbers in this file); boot, production-like eager load, migrations up/down OK.
- Every feature verified by hand on Redmine 7; screenshots listed.
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

