# Redmine ITIL Priority

**ATTENTION: ALPHA STAGE**

This Redmine plugin replaces the single priority field with an ITIL style
**Impact × Urgency** matrix. The resulting priority is calculated from the
selected impact and urgency. Users with the permission "Override ITIL
priority" may unlink the automatic calculation by clicking the link icon next
to the priority field and choose a priority manually; the issue stays unlinked
until someone with that permission links it again.

## Features

- Global priority mapping between impact and urgency levels
- Per‑project configuration with per‑tracker modes: **Inactive**, **Use generic
  settings**, or **Custom** mapping
- Inactive mode hides the mapping table, while generic mode greys out fields
  preloaded from global defaults
- Global and per‑project settings can be read and updated through the REST API
- Issue form with impact and urgency fields and optional manual priority
  selection via the link icon
- Columns and filters for Impact × Urgency.
- Optional logging controlled by a toggle in `init.rb`.
- Priority selection is available in the context menu and bulk edit screens.
- Translations for English, French, German, Spanish, Dutch, Japanese, Italian and Portuguese.
- Priority can be set via incoming emails when allowed by configuration.
- Permission **Override ITIL priority** (project module ITIL priority): without
  it a user sets impact and urgency only and the priority follows the matrix.
  This holds for the issue form, bulk edit, context menu, REST API and incoming
  mail. A priority made read-only by the workflow cannot be unlinked either.
- Impact and Urgency in Administration > Workflow > Fields permissions:
  read-only or required per role, tracker and status, like core fields.
- Optional explanation of the impact and urgency levels, shown behind an info
  icon on the issue form: one text per instance (plugin settings), overridable
  per project and tracker in the tracker's Custom mode.
- Issue history and notification mails show the impact and urgency labels.
- Redmine 7 webhooks: the issue payload carries `impact_id`, `urgency_id` and
  `itil_priority_linked`.

## Supported languages

- English (en)
- French (fr)
- German (de)
- Spanish (es)
- Dutch (nl)
- Japanese (ja)
- Italian (it)
- Portuguese (pt)

## Installation

1. Copy the plugin into the `plugins` directory of your Redmine installation.
2. Install dependencies and migrate:

   ```bash
   bundle install
   RAILS_ENV=production bundle exec rake redmine:plugins
   ```

3. Restart Redmine.

## Configuration

Enable verbose plugin logging by setting `RedmineItilPriority.logging_enabled = true`
in `init.rb`. Logging is disabled by default.

## Testing

Run the test suite with RSpec (stand-alone specs) and minitest (against a
real Redmine with its fixtures):

```bash
RAILS_ENV=test bundle exec rspec plugins/redmine_itil_priority/spec
RAILS_ENV=test bundle exec ruby -Itest -e 'Dir["plugins/redmine_itil_priority/test/**/*_test.rb"].each { |f| require File.expand_path(f) }'
```

`./.codex/test_plugin.sh` runs both; `./.codex/e2e.sh` the browser scenarios
in `test/e2e/` (see CLAUDE.md).

## Screenshots

- [Generic settings](doc/generic_settings.png)
- [Project settings](doc/project_settings.png)
- [Issue form](doc/issue.png)
- [Context menu](doc/context_menu.png)

## API

### Global settings

- `GET /itil_priority/api/settings.json` – returns the plugin's global
  configuration. Requires administrator privileges.
- `PUT /itil_priority/api/settings.json` – updates the global configuration.
  Requires administrator privileges.

### Project settings

- `GET /projects/:id/itil_priority/api/settings.json` – returns effective
  settings for all trackers in the project. Trackers using generic settings
  include the merged global values, while inactive trackers return `null`.
  Requires the `manage_itil_priority_settings` permission in the project.
- `PUT /projects/:id/itil_priority/api/settings.json` – updates tracker
  settings for the project. Non‑custom modes discard mapping values. Requires
  the `manage_itil_priority_settings` permission.

### Example usage

```
curl -H "X-Redmine-API-Key: YOUR_KEY" \
     https://redmine.example.com/itil_priority/api/settings.json

# Update
curl -H "X-Redmine-API-Key: YOUR_KEY" \
     -H 'Content-Type: application/json' \
     -X PUT \
     -d '{"settings":{"label_impact_1":"Low"}}' \
     https://redmine.example.com/itil_priority/api/settings.json
```

### Project settings

```bash
# GET /projects/:id/itil_priority/api/settings.json
# Retrieve
curl -H "X-Redmine-API-Key: YOUR_KEY" \
     https://redmine.example.com/projects/42/itil_priority/api/settings.json

# Update
curl -H "X-Redmine-API-Key: YOUR_KEY" \
     -H 'Content-Type: application/json' \
     -X PUT \
     -d '{"tracker_settings":{"1":{"mode":"custom","priority_i1_u1":5}}}' \
     https://redmine.example.com/projects/42/itil_priority/api/settings.json
```

### Issue API

`impact_id`, `urgency_id` and `itil_priority_linked` are available in the
standard Redmine issue REST API. They can be supplied when creating or updating
an issue and are returned when fetching issues. `priority_id` and
`itil_priority_linked` are only accepted from users with the permission
"Override ITIL priority"; a `priority_id` that differs from the matrix unlinks
the issue, unless `itil_priority_linked: true` is sent with it.

## Setting Itil Priority Imapct × Urgency by email

Redmine's mail handler can set the ITIL Impact and Urgency fields when creating
issues. Include `impact`, `urgency` and `itil_priority_linked` in the
`--allow-override` option and specify the desired values in the email body:

```
Impact: Low impact
Urgency: Urgent
Itil priority linked: 0
```

The labels must match those configured for the project/tracker. This applies
only to issues where ITIL priority is enabled. `Priority` and
`Itil priority linked` are only applied when the sender has the permission
"Override ITIL priority".

## Upgrading from 0.0.2

Run the plugin migrations. Migration 003 adds `issues.itil_priority_linked`
(existing issues stay linked). Migration 004 grants "Override ITIL priority" to
every role that can add or edit issues, so nothing changes for users; then
remove it from the roles that must not set the priority (helpdesk, anonymous,
non member).

## Thank you

Many thanks to Jean-Baptiste BARTH who had the original idea behind this plugin.

## License

This plugin is released under the GNU GPL v3.
