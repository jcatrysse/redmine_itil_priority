// Incoming mail (POST /mail_handler, the way rdm-mailhandler delivers): the
// keywords Impact, Urgency, Priority and "Itil priority linked". A helpdesk
// sender sets impact and urgency only; an operator may unlink and set the
// priority; a wrong key is refused.
import { e2e } from '../../.codex/e2e/lib.mjs';

const t = await e2e('mail');
const fail = (m) => t.problems.push(m);
const log = [];
const admin = { Authorization: 'Basic ' + Buffer.from('admin:' + (process.env.RMP_ADMIN_PASSWORD || 'Redmine7Test!')).toString('base64') };

async function receive(from, subject, body, key = 'e2e-mail-key') {
  const raw = [`From: ${from}`, 'To: redmine@example.net', `Subject: ${subject}`,
    `Message-ID: <${Date.now()}.${Math.random().toString(16).slice(2)}@example.net>`,
    'Date: ' + new Date().toUTCString(), 'Content-Type: text/plain; charset=utf-8', '', body, ''].join('\r\n');
  const res = await t.page.request.post(`${t.BASE}/mail_handler`, { form: {
    key, email: raw, 'issue[project]': 'e2e-project', 'issue[tracker]': 'Bug',
    allow_override: 'priority,impact,urgency,itil_priority_linked' } });
  log.push(`${from} "${subject}" key=${key} -> HTTP ${res.status()}\n${body}`);
  return res.status();
}
async function issueBySubject(subject) {
  const res = await t.page.request.get(`${t.BASE}/projects/e2e-project/issues.json?status_id=*&sort=id:desc&limit=50`, { headers: admin });
  return (await res.json()).issues.find((i) => i.subject === subject);
}

await t.anonymous();
const s1 = `Mail from helpdesk ${Date.now()}`;
if (await receive('reporter@example.net', s1, 'Printer on fire.\n\nImpact: Important impact\nUrgency: Urgent\nPriority: Low\nItil priority linked: 0') !== 201) fail('helpdesk mail not accepted');
const i1 = await issueBySubject(s1);
if (!i1) fail('helpdesk mail: no issue');
else if (i1.priority.name !== 'Urgent' || i1.impact_id !== 3 || i1.urgency_id !== 3 || i1.itil_priority_linked !== true) fail(`helpdesk mail: ${JSON.stringify([i1.priority.name, i1.impact_id, i1.urgency_id, i1.itil_priority_linked])}`);

const s2 = `Mail from operator ${Date.now()}`;
if (await receive('manager@example.net', s2, 'Planned work.\n\nImpact: Important impact\nUrgency: Urgent\nPriority: Low\nItil priority linked: 0') !== 201) fail('operator mail not accepted');
const i2 = await issueBySubject(s2);
if (!i2) fail('operator mail: no issue');
else if (i2.priority.name !== 'Low' || i2.itil_priority_linked !== false) fail(`operator mail: ${JSON.stringify([i2.priority.name, i2.itil_priority_linked])}`);

const s3 = `Mail with unknown label ${Date.now()}`;
await receive('reporter@example.net', s3, 'Unknown labels.\n\nImpact: Enormous\nUrgency: Normal');
const i3 = await issueBySubject(s3);
if (!i3 || i3.impact_id != null || i3.urgency_id !== 2) fail(`unknown impact label: ${JSON.stringify(i3 && [i3.impact_id, i3.urgency_id])}`);

const wrong = await receive('reporter@example.net', 'Wrong key', 'x', 'not-the-key');
if (wrong !== 403) fail(`wrong key: HTTP ${wrong}, expected 403`);

await t.login('manager');
await t.page.setContent(`<html><body style="font:13px monospace;white-space:pre-wrap;padding:12px"><h3>Mails posted to /mail_handler (mail.mjs)</h3>${log.map((l) => l.replace(/[<&]/g, (c) => ({ '<': '&lt;', '&': '&amp;' }[c]))).join('\n\n')}</body></html>`);
await t.shot('posted', 'The four mails with their keywords and the HTTP answers (201 created, 403 for a wrong key)');
if (i1) { await t.go(`/issues/${i1.id}`); await t.shot('helpdesk', 'Helpdesk mail: Priority: Low and "Itil priority linked: 0" ignored, the matrix gives Urgent'); }
if (i2) { await t.go(`/issues/${i2.id}/edit`); await t.shot('operator', 'Operator mail: priority Low by hand, unlinked (broken link, priority select visible)', { full: false }); }
if (i3) { await t.go(`/issues/${i3.id}/edit`); await t.shot('unknown-label', 'Unknown impact label: impact stays empty, the known urgency is set', { full: false }); }

await t.done();
