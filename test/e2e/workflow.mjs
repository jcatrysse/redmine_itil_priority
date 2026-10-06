// Workflow field permissions: Impact and Urgency are listed with core's
// fields; read-only and required apply to the issue form.
import { e2e } from '../../.codex/e2e/lib.mjs';

const t = await e2e('workflow');
const fail = (m) => t.problems.push(m);
const admin = { Authorization: 'Basic ' + Buffer.from('admin:' + (process.env.RMP_ADMIN_PASSWORD || 'Redmine7Test!')).toString('base64') };
const getJson = async (url) => (await t.page.request.get(t.BASE + url, { headers: admin })).json();

await t.anonymous();
const role = (await getJson('/roles.json')).roles.find((r) => r.name === 'Reporter').id;
const bug = (await getJson('/trackers.json')).trackers.find((x) => x.name === 'Bug').id;
const status = (await getJson('/issue_statuses.json')).issue_statuses.find((s) => s.name === 'New').id;
const issue = (await getJson('/projects/e2e-project/issues.json?tracker_id=' + bug + '&status_id=' + status + '&sort=id:desc')).issues[0];

async function setRules(urgency, impact) {
  await t.login('admin');
  await t.go(`/workflows/permissions?role_id=${role}&tracker_id=${bug}`);
  await t.sudo();
  await t.page.selectOption(`select[name="permissions[${status}][urgency_id]"]`, urgency);
  await t.page.selectOption(`select[name="permissions[${status}][impact_id]"]`, impact);
}

await setRules('readonly', 'required');
try {
await t.shot('permissions', 'Administration > Workflow > Fields permissions: Impact and Urgency listed with the core fields; for Reporter/Bug/New urgency read-only, impact required');
await t.page.click('#workflow_form input[type=submit]');
await t.settle();
t.check('save rules');

await t.login('reporter');
await t.go(`/issues/${issue.id}/edit`);
if (await t.page.locator('select#issue_urgency_id').count()) fail('read-only urgency is still a select');
if (!(await t.page.locator('span#issue_urgency_id.itil-value').count())) fail('read-only urgency not shown as text');
if (!/\*/.test(await t.page.locator('#itil_priority_field label.inline', { hasText: 'Impact' }).innerText())) fail('required impact has no star');
await t.page.selectOption('select#issue_impact_id', '');
await t.shot('form', 'Reporter on a new Bug: urgency read-only (text), impact required (red star), emptied');
await t.page.click('#issue-form input[name=commit]');
await t.settle();
t.check('save with empty impact');
if (!/Impact cannot be blank/.test(await t.page.locator('#errorExplanation').innerText().catch(() => ''))) fail('no "Impact cannot be blank" error');
await t.shot('required-error', 'Saving without impact is refused: "Impact cannot be blank"');

// manager (other role): no rules, both editable
await t.login('manager');
await t.go(`/issues/${issue.id}/edit`);
if (!(await t.page.locator('select#issue_urgency_id').count())) fail('manager: urgency not editable');
await t.shot('other-role', 'The manager\'s role has no rules: both fields editable', { full: false });

} finally {
  // back to no rules, also when a step above failed: the other scenarios need them gone
  await setRules('', '');
  await t.page.click('#workflow_form input[type=submit]');
  await t.settle();
  t.check('reset rules');
}

await t.done();
