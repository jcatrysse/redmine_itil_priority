# settings

Run 2026-10-06T20:36:55.525Z against http://127.0.0.1:3000.

| screenshot | user | URL | shows |
|---|---|---|---|
| ![](settings-global.png) | admin | `/settings/plugin/redmine_itil_priority` | Administration > Plugins > ITIL priority: default tracker mode, labels, matrix and the two help texts |
| ![](settings-global-saved.png) | admin | `/settings/plugin/redmine_itil_priority` | Saved: the urgency help text is stored |
| ![](settings-project-tab.png) | manager | `/projects/e2e-project/settings/itil_priority` | Project settings, tab ITIL priority: Bug generic (greyed), Feature custom (editable, own help text), Support inactive (hidden) |
| ![](settings-project-saved.png) | manager | `/projects/e2e-project/settings/itil_priority` | Saved, with the success notice; the modes are kept |
| ![](settings-form-inactive.png) | manager | `/projects/e2e-project/issues/new?issue[tracker_id]=3` | Support is inactive: the issue form has core's plain Priority field |
| ![](settings-form-custom.png) | manager | `/projects/e2e-project/issues/new?issue[tracker_id]=2` | Feature uses its custom matrix (Low x Not urgent = Immediate) and own impact text; the urgency text comes from the generic settings |
| ![](settings-reporter-refused.png) | reporter | `/projects/e2e-project/settings/itil_priority` | A member without "manage ITIL priority settings" is refused the project settings |
