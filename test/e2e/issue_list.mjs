// Issue list: the Impact and Urgency columns and filters, the context menu
// (Urgency/Impact submenus, with and without "override ITIL priority") and
// bulk edit.
import { e2e } from '../../.codex/e2e/lib.mjs';

const P = 'e2e-project';
const t = await e2e('issue_list');
const fail = (m) => t.problems.push(m);

await t.login('manager');
// columns and a filter through the URL, the way a saved query does it
await t.go(`/projects/${P}/issues?set_filter=1&f[]=status_id&op[status_id]=o&f[]=impact_id&op[impact_id]=*&c[]=tracker&c[]=subject&c[]=priority&c[]=impact_id&c[]=urgency_id&sort=id:desc`);
const header = await t.page.locator('table.issues thead').innerText();
if (!/Impact/.test(header) || !/Urgency/.test(header)) fail('list: Impact/Urgency columns missing');
const filterOptions = await t.page.locator('#add_filter_select option').allInnerTexts();
if (!filterOptions.includes('Impact') || !filterOptions.includes('Urgency')) fail('list: Impact/Urgency filters missing');
await t.shot('columns-filter', 'Issue list with the Impact and Urgency columns (labels, not numbers) and the filter "Impact: any"');

// context menu as operator: Priority, Urgency and Impact
await t.page.click('table.issues tr.issue td.tracker >> nth=0', { button: 'right' });
await t.page.waitForSelector('#context-menu ul');
await t.page.hover('#context-menu a.submenu:text-is("Urgency")');
const menu = await t.page.locator('#context-menu').innerText();
if (!/Priority/.test(menu)) fail('context menu (operator): no Priority');
if (!/Not urgent/.test(menu)) fail('context menu: Urgency submenu has no labels');
t.check('context menu operator');
await t.shot('context-menu-operator', 'Operator: the context menu has Priority, and Urgency/Impact with their labels and the submenu arrow', { full: false });
const firstId = await t.page.locator('table.issues tr.issue td.id >> nth=0').innerText();
await t.page.click('#context-menu li.folder:has(> a.submenu:text-is("Urgency")) a:text-is("Urgent")');
await t.settle();
t.check('context menu set urgency');
await t.go(`/issues/${firstId.trim()}`);
await t.shot('context-menu-applied', 'Urgency set through the context menu; history shows the change with its label');

// context menu as helpdesk: no Priority
await t.login('reporter');
await t.go(`/projects/${P}/issues`);
await t.page.click('table.issues tr.issue td.status >> nth=0', { button: 'right' });
await t.page.waitForSelector('#context-menu ul');
await t.page.hover('#context-menu a.submenu:text-is("Impact")');
const menu2 = await t.page.locator('#context-menu').innerText();
if (/\bPriority\b/.test(menu2)) fail('context menu (helpdesk): Priority present');
if (!/Urgency/.test(menu2) || !/Impact/.test(menu2)) fail('context menu (helpdesk): Urgency/Impact missing');
t.check('context menu helpdesk');
await t.shot('context-menu-helpdesk', 'Helpdesk user: no Priority in the context menu, Urgency and Impact are there', { full: false });

// bulk edit as helpdesk
await t.page.keyboard.press('Escape');
await t.go(`/projects/${P}/issues`);
await t.page.check('table.issues tr.issue >> nth=0 >> input[type=checkbox]');
await t.page.check('table.issues tr.issue >> nth=1 >> input[type=checkbox]');
await t.page.click('table.issues tr.issue.context-menu-selection td.status >> nth=0', { button: 'right' });
await t.page.waitForSelector('#context-menu ul');
await t.page.click('#context-menu a:has-text("Bulk edit")');
await t.settle();
t.check('bulk edit form');
if (await t.page.locator('select#issue_priority_id').count()) fail('bulk edit (helpdesk): priority present');
await t.page.selectOption('select[name="issue[impact_id]"]', '2');
await t.page.selectOption('select[name="issue[urgency_id]"]', '2');
await t.shot('bulk-edit-helpdesk', 'Bulk edit as helpdesk user: Urgency and Impact, no Priority');
await t.page.click('#bulk_edit_form input[type=submit]');
await t.settle();
t.check('bulk edit save');
await t.go(`/projects/${P}/issues?set_filter=1&f[]=impact_id&op[impact_id]==&v[impact_id][]=2&f[]=urgency_id&op[urgency_id]==&v[urgency_id][]=2&c[]=subject&c[]=priority&c[]=impact_id&c[]=urgency_id`);
const rows = await t.page.locator('table.issues tr.issue').count();
if (rows < 2) fail(`bulk edit: ${rows} issue(s) with Medium x Normal, expected at least 2`);
await t.shot('bulk-edit-result', 'After the bulk edit, filtered on Impact = Medium and Urgency = Normal: the issues have priority Normal from the matrix');

await t.done();
