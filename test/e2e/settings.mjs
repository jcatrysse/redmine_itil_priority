// Settings: the global matrix (admin), the project's ITIL priority tab per
// tracker (permission "manage ITIL priority settings"), and their effect on
// the issue form; refusals for users without the permission.
import { e2e } from '../../.codex/e2e/lib.mjs';

const P = 'e2e-project';
const t = await e2e('settings');
const fail = (m) => t.problems.push(m);
const tracker = (name) => `fieldset:has(> legend:text-is("${name}"))`;

// --- admin: global settings
await t.login('admin');
await t.go('/settings/plugin/redmine_itil_priority');
await t.sudo();
if (!(await t.page.locator('select[name="settings[priority_i3_u3]"]').count())) fail('global: no matrix');
await t.page.fill('textarea[name="settings[help_urgency_3]"]', 'Work stops.');
await t.shot('global', 'Administration > Plugins > ITIL priority: default tracker mode, labels, matrix and an explanation per level of urgency and impact');
await t.page.click('#settings input[type=submit], form input[name=commit]');
await t.settle();
t.check('save global');
if (await t.page.inputValue('textarea[name="settings[help_urgency_3]"]') !== 'Work stops.') fail('global: help text not saved');
await t.shot('global-saved', 'Saved: the urgency help text is stored');

// --- manager: project tab per tracker
await t.login('manager');
await t.go(`/projects/${P}/settings/itil_priority`);
await t.page.selectOption(`${tracker('Support')} select[id$="_mode"]`, 'inactive');
await t.page.selectOption(`${tracker('Feature')} select[id$="_mode"]`, 'custom');
await t.page.selectOption(`${tracker('Feature')} select[name$="[priority_i1_u1]"]`, { label: 'Immediate' });
await t.page.fill(`${tracker('Feature')} textarea[name$="[help_impact_3]"]`, 'Many customers ask for it.');
await t.shot('project-tab', 'Project settings, tab ITIL priority: Bug generic (greyed), Feature custom (editable, own explanation per level), Support inactive (hidden)');
await t.page.click('#tab-content-itil_priority input[type=submit], form[action$="itil_priority_settings"] input[type=submit]');
await t.settle();
t.check('save project');
if (await t.page.inputValue(`${tracker('Support')} select[id$="_mode"]`) !== 'inactive') fail('project: Support not saved inactive');
if (!(await t.page.locator('#flash_notice').count())) fail('project: no success notice');
await t.shot('project-saved', 'Saved, with the success notice; the modes are kept');

// effect on the issue form
await t.go(`/projects/${P}/issues/new?issue[tracker_id]=${await trackerId('Support')}`);
if (await t.page.locator('#itil_priority_field').count()) fail('inactive tracker: ITIL field shown');
if (!(await t.page.locator('select#issue_priority_id').count())) fail('inactive tracker: core priority missing');
await t.shot('form-inactive', 'Support is inactive: the issue form has core\'s plain Priority field');
await t.go(`/projects/${P}/issues/new?issue[tracker_id]=${await trackerId('Feature')}`);
await t.page.selectOption('select#issue_impact_id', '1');
await t.page.selectOption('select#issue_urgency_id', '1');
if ((await t.page.locator('#real-priority-display').innerText()).trim() !== 'Immediate') fail('custom tracker: Low x Not urgent should give Immediate');
await t.page.selectOption('select#issue_impact_id', '3');
await t.page.selectOption('select#issue_urgency_id', '3');
if (!/Many customers/.test(await t.page.locator('#itil_help_current_impact').innerText())) fail('custom tracker: own impact text not shown');
if (!/Work stops/.test(await t.page.locator('#itil_help_current_urgency').innerText())) fail('custom tracker: generic urgency text not inherited');
await t.page.selectOption('select#issue_impact_id', '1');
await t.page.selectOption('select#issue_urgency_id', '1');
await t.shot('form-custom', 'Feature uses its custom matrix (Low x Not urgent = Immediate); the explanations per level were checked for Important impact (own text) and Urgent (generic text)');

// --- reporter: no tab, settings refused
await t.login('reporter');
await t.go(`/projects/${P}/settings/itil_priority`, { status: 403 });
await t.shot('reporter-refused', 'A member without "manage ITIL priority settings" is refused the project settings');

// --- reset to generic for the other scenarios
await t.login('manager');
await t.go(`/projects/${P}/settings/itil_priority`);
for (const name of ['Bug', 'Feature', 'Support']) await t.page.selectOption(`${tracker(name)} select[id$="_mode"]`, 'default');
await t.page.click('form[action$="itil_priority_settings"] input[type=submit]');
await t.settle();
t.check('reset project');
await t.login('admin');
await t.go('/settings/plugin/redmine_itil_priority');
await t.sudo();
await t.page.fill('textarea[name="settings[help_urgency_3]"]', '');
await t.page.click('form input[name=commit], #settings input[type=submit]');
await t.settle();
t.check('reset global');

await t.done();

async function trackerId(name) {
  const res = await t.page.request.get(`${t.BASE}/trackers.json`, { headers: { Authorization: 'Basic ' + Buffer.from('admin:' + (process.env.RMP_ADMIN_PASSWORD || 'Redmine7Test!')).toString('base64') } });
  const json = await res.json();
  return json.trackers.find((x) => x.name === name).id;
}
