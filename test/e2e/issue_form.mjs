// Issue form: impact x urgency gives the priority; an operator ("manager",
// permission "override ITIL priority") unlinks and sets the priority by hand;
// a helpdesk user ("reporter", without that permission) sets impact and
// urgency only and cannot undo the operator's priority; info icon for impact.
import { e2e } from '../../.codex/e2e/lib.mjs';

const P = 'e2e-project';
const t = await e2e('issue_form');
const fail = (m) => t.problems.push(m);
const text = async (sel) => (await t.page.locator(sel).first().innerText()).trim();
const issueId = () => (t.page.url().match(/\/issues\/(\d+)/) || [])[1];

// --- operator creates an issue: the priority follows impact and urgency
await t.login('manager');
await t.go(`/projects/${P}/issues/new`);
await t.page.fill('#issue_subject', `ITIL form ${Date.now()}`);
if (await text('#real-priority-display') !== 'Normal') fail('new issue: default priority not shown as Normal');
await t.page.selectOption('select#issue_impact_id', '3');
await t.page.selectOption('select#issue_urgency_id', '3');
if (await text('#real-priority-display') !== 'Urgent') fail('new issue: Important x Urgent should show Urgent');
await t.shot('new-linked', 'Operator, new issue: Important impact x Urgent gives priority Urgent, calculated live; the link icon shows the priority is linked');
await t.page.click('#issue-form input[name=commit]');
await t.settle();
t.check('create');
const id = issueId();
if (!id) fail(`create: no issue id in ${t.page.url()}`);
if (await text('.issue .attributes .priority .value') !== 'Urgent') fail('created issue: priority is not Urgent');
await t.shot('created', 'The created issue has priority Urgent');

// --- operator unlinks and sets Immediate by hand
await t.go(`/issues/${id}/edit`);
await t.page.click('#itil_priority_link');
if (!(await t.page.isVisible('#itil_issue_priority_id'))) fail('unlink: the priority select did not appear');
await t.page.selectOption('#itil_issue_priority_id', { label: 'Immediate' });
await t.shot('unlinked-edit', 'Operator clicks the link icon: it breaks, and the priority can be chosen by hand (Immediate)', { full: false });
await t.page.click('#issue-form input[name=commit]');
await t.settle();
t.check('unlink');
if (await text('.issue .attributes .priority .value') !== 'Immediate') fail('unlink: priority is not Immediate');
const hist = await t.page.locator('#history').innerText();
if (!/Priority linked to impact and urgency changed from Yes to No/.test(hist)) fail('history: unlinking not shown as Yes to No');
await t.shot('unlinked-history', 'Saved: priority Immediate; the history says "Priority linked to impact and urgency changed from Yes to No"');

await t.go(`/issues/${id}/edit`);
if (!(await t.page.isVisible('#itil_issue_priority_id'))) fail('re-edit: an unlinked issue shows as linked again');
if (await t.page.inputValue('#itil_priority_linked') !== '0') fail('re-edit: link flag not 0');
await t.shot('unlinked-reopened', 'Opening the form again keeps the issue unlinked (before this change it was relinked and recalculated)', { full: false });

// --- helpdesk user: impact and urgency only, the operator's priority stays
await t.login('reporter');
await t.go(`/issues/${id}/edit`);
if (await t.page.locator('select[name="issue[priority_id]"]').count()) fail('helpdesk: a priority select is present');
if (await t.page.locator('input[name="issue[itil_priority_linked]"]').count()) fail('helpdesk: the link flag is in the form');
if (!(await t.page.locator('select#issue_urgency_id').count())) fail('helpdesk: no urgency select');
const title = await t.page.getAttribute('#itil_priority_link', 'title');
if (!/set by hand/.test(title || '')) fail(`helpdesk: link icon title is "${title}"`);
await t.page.click('#itil_priority_link');   // not clickable for them
if (await t.page.locator('select[name="issue[priority_id]"]').count()) fail('helpdesk: clicking the icon gave a priority select');
await t.page.selectOption('select#issue_urgency_id', '1');
await t.page.hover('#itil_priority_link');
await t.shot('helpdesk-edit', 'Helpdesk user (no "override ITIL priority"): impact and urgency editable, priority Immediate shown but not editable, broken link "set by hand"', { full: false });
await t.page.click('#issue-form input[name=commit]');
await t.settle();
t.check('helpdesk save');
if (await text('.issue .attributes .priority .value') !== 'Immediate') fail('helpdesk: the operator priority did not survive');
await t.shot('helpdesk-saved', 'After the helpdesk user changed the urgency the operator\'s priority Immediate stays');

// --- helpdesk user creates an issue: priority from the matrix
await t.go(`/projects/${P}/issues/new`);
await t.page.fill('#issue_subject', `ITIL helpdesk ${Date.now()}`);
await t.page.selectOption('select#issue_impact_id', '2');
await t.page.selectOption('select#issue_urgency_id', '3');
if (await text('#real-priority-display') !== 'High') fail('helpdesk new: Medium x Urgent should show High');
await t.shot('helpdesk-new', 'Helpdesk user, new issue: the ITIL field takes the priority\'s place after Status; Medium x Urgent gives High');
await t.page.click('#issue-form input[name=commit]');
await t.settle();
t.check('helpdesk create');
if (await text('.issue .attributes .priority .value') !== 'High') fail('helpdesk create: priority is not High');
await t.shot('helpdesk-created', 'Created by the helpdesk user with priority High from the matrix');

// --- operator links again: the priority is recalculated
await t.login('manager');
await t.go(`/issues/${id}/edit`);
await t.page.click('#itil_priority_link');
if (await text('#real-priority-display') !== 'Normal') fail('relink: Important x Not urgent should show Normal');
await t.page.click('#issue-form input[name=commit]');
await t.settle();
t.check('relink');
if (await text('.issue .attributes .priority .value') !== 'Normal') fail('relink: priority is not Normal');
await t.shot('relinked', 'Operator links again: the priority is recalculated (Important x Not urgent = Normal)');

// --- explanation per level (Jan, 2026-10-07): the chosen level under the field, all three behind the icon
await t.go(`/issues/${id}/edit`);
if (await t.page.locator('a.itil-help-toggle[data-target=itil_help_urgency]').count()) fail('help: urgency has an icon without text');
if (!/whole company/.test(await t.page.locator('#itil_help_current_impact').innerText())) fail('help: text of the chosen level (Important impact) not shown under the field');
await t.page.selectOption('select#issue_impact_id', '1');
if (!/One user/.test(await t.page.locator('#itil_help_current_impact').innerText())) fail('help: text did not follow the chosen level');
await t.shot('help-current', 'Explanation of the chosen impact level under the field; it follows the selection (Low impact: one user)', { full: false });
if (await t.page.isVisible('#itil_help_impact')) fail('help: overview visible before the click');
await t.page.click('a.itil-help-toggle[data-target=itil_help_impact]');
if (!(await t.page.isVisible('#itil_help_impact'))) fail('help: the click did not show the overview');
if ((await t.page.locator('#itil_help_impact .itil-help-level.selected').getAttribute('data-level')) !== '1') fail('help: chosen level not marked in the overview');
await t.shot('help-impact', 'Info icon next to Impact (none next to Urgency, it has no text): all three levels with their explanation, the chosen one marked', { full: false });

// the same for a helpdesk user, and the explanation of a read-only level
await t.login('reporter');
await t.go(`/issues/${id}/edit`);
if (!/whole company/.test(await t.page.locator('#itil_help_current_impact').innerText())) fail('helpdesk: level explanation missing');
await t.shot('help-helpdesk', 'A helpdesk user sees the same explanation for the impact level');
await t.login('manager');

// --- outsider: the private project stays invisible
await t.login('outsider');
await t.go('/projects/e2e-private/issues/new', { status: 403 });
await t.shot('outsider-refused', 'A non-member cannot open the issue form of the private project');

await t.done();
