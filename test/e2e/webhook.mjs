// Redmine 7 webhooks: the issue payload carries impact_id, urgency_id and
// itil_priority_linked (core renders its own show.api.rsb, which lacks them;
// the plugin points the webhook at its template). A local listener plays the
// receiving end, on this host's own address: Redmine refuses loopback targets.
import http from 'node:http';
import os from 'node:os';
import { e2e } from '../../.codex/e2e/lib.mjs';

const t = await e2e('webhook');
const fail = (m) => t.problems.push(m);
const received = [];
const server = http.createServer((req, res) => {
  let body = '';
  req.on('data', (c) => { body += c; });
  req.on('end', () => { try { received.push(JSON.parse(body)); } catch { received.push({ raw: body }); } res.end('ok'); });
});
await new Promise((r) => server.listen(0, '0.0.0.0', r));
const port = server.address().port;
const host = Object.values(os.networkInterfaces()).flat().find((i) => i.family === 'IPv4' && !i.internal).address;

await t.login('manager');
await t.go('/webhooks/new');
await t.page.fill('#webhook_url', `http://${host}:${port}/itil`);
await t.page.check('#webhook_active');
await t.page.check('input[id="webhook_events_issue.updated"]');
await t.page.check('input[id="webhook_events_issue.created"]');
await t.page.check('#webhook_project_ids label:has-text("E2E project") input');
await t.shot('new-webhook', 'Manager creates a webhook for issue created/updated in E2E project, to a local listener');
await t.page.click('#content input[type=submit][name=commit]');
await t.settle();
await t.sudo();   // Redmine 7 asks for the password again before creating a webhook
await t.settle();
t.check('create webhook');
if (!(await t.page.locator(`text=${host}:${port}`).count())) fail('webhook not created');
await t.shot('webhook-list', 'After the sudo password the webhook is created and listed');

// an issue created and changed through the form
await t.go('/projects/e2e-project/issues/new');
await t.page.fill('#issue_subject', `Webhook ITIL ${Date.now()}`);
await t.page.selectOption('select#issue_impact_id', '3');
await t.page.selectOption('select#issue_urgency_id', '2');
await t.page.click('#issue-form input[name=commit]');
await t.settle();
const id = Number((t.page.url().match(/\/issues\/(\d+)/) || [])[1]);
await t.go(`/issues/${id}/edit`);
await t.page.selectOption('select#issue_urgency_id', '3');
await t.page.click('#issue-form input[name=commit]');
await t.settle();
t.check('issue changes');

for (let i = 0; i < 30 && received.filter((p) => p?.data?.issue?.id === id).length < 2; i++) await t.page.waitForTimeout(500);
const mine = received.filter((p) => p?.data?.issue?.id === id);
const created = mine.find((p) => p.type === 'issue.created');
const updated = mine.find((p) => p.type === 'issue.updated');
if (!created || !updated) fail(`payloads received for #${id}: ${mine.map((p) => p.type).join(', ') || 'none'}`);
if (created && (created.data.issue.impact_id !== 3 || created.data.issue.urgency_id !== 2 || created.data.issue.itil_priority_linked !== true)) fail('created payload: impact/urgency/link wrong or missing');
if (updated && (updated.data.issue.urgency_id !== 3 || updated.data.issue.priority?.name !== 'Urgent')) fail('updated payload: urgency 3 / priority Urgent expected');

await t.page.setContent(`<html><body style="font:13px monospace;white-space:pre-wrap;padding:12px"><h3>Payloads received by the listener for issue #${id}</h3>${mine.map((p) => JSON.stringify({ type: p.type, issue: { id: p.data.issue.id, priority: p.data.issue.priority, impact_id: p.data.issue.impact_id, urgency_id: p.data.issue.urgency_id, itil_priority_linked: p.data.issue.itil_priority_linked } }, null, 2)).join('\n\n')}</body></html>`);
await t.shot('payloads', 'The webhook payloads (created, updated) carry impact_id, urgency_id and itil_priority_linked');

// clean up the webhook
await t.go('/webhooks');
t.page.on('dialog', (d) => d.accept());
const del = t.page.locator(`tr:has-text("${host}:${port}") a.icon-del, tr:has-text("${host}:${port}") a[data-method=delete]`).first();
if (await del.count()) { await del.click(); await t.settle(); await t.sudo(); await t.settle(); }
t.check('delete webhook');
server.close();
await t.done();
