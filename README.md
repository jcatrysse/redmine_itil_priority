# Redmine ITIL Priority

**ATTENTION: ALPHA STAGE**

This Redmine plugin replaces the single priority field with an ITIL style
**Impact × Urgency** matrix. The resulting priority is calculated from the
selected impact and urgency. Users may temporarily unlink the automatic
calculation by clicking the link icon next to the priority field and choose a
priority manually.

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

Run the test suite with RSpec:

```bash
RAILS_ENV=test bundle exec rspec plugins/redmine_itil_priority/spec
```

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

`impact_id` and `urgency_id` are available in the standard Redmine issue REST
API. They can be supplied when creating or updating an issue and are returned
when fetching issues.

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
only to issues where ITIL priority is enabled.

## Thank you

Many thanks to Jean-Baptiste BARTH who had the original idea behind this plugin.

## License

This plugin is released under the GNU GPL v3.
