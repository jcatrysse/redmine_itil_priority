// RedmineUP helpdesk tickets from mail (Jan, 2026-10-07: "Helpdeskprioriteit
// behouden"). The helpdesk creates them as the anonymous user, so the
// Anonymous role's "Override ITIL priority" decides whether a ticket keeps the
// helpdesk's configured priority (Urgent on e2e-private, a private project).
// Skipped where the helpdesk is not installed.
import { e2e } from '../../.codex/e2e/lib.mjs';

const t = await e2e('helpdesk_mail');
const fail = (m) => t.problems.push(m);
const admin = { Authorization: 'Basic ' + Buffer.from('admin:' + (process.env.RMP_ADMIN_PASSWORD || 'Redmine7Test!')).toString('base64') };
const log = [];

await t.anonymous();
if ((await t.page.request.get(`${t.BASE}/helpdesk_mailer`)).status() === 404) {
  console.log('helpdesk_mail: RedmineUP helpdesk not installed, nothing to check');
  await t.done();
  process.exit(0);
}

async function mail(key = 'e2e-mail-key') {
  const subject = `Helpdesk mail ${Date.now()}`;
  const raw = [`From: customer.${Date.now()}@example.org`, 'To: support@example.net', `Subject: ${subject}`,
    `Message-ID: <${Date.now()}.${Math.random().toString(16).slice(2)}@example.org>`, 'Date: ' + new Date().toUTCString(),
    'Content-Type: text/plain; charset=utf-8', '', 'The printer is on fire.', ''].join('\r\n');
  const res = await t.page.request.post(`${t.BASE}/helpdesk_mailer`, { form: { key, email: raw, 'issue[project]': 'e2e-private' } });
  const list = await (await t.page.request.get(`${t.BASE}/projects/e2e-private/issues.json?status_id=*&sort=id:desc&limit=10`, { headers: admin })).json();
  const issue = list.issues?.find((i) => i.subject === subject);
  log.push(`POST /helpdesk_mailer key=${key} -> HTTP ${res.status()}; ticket: ${issue ? `#${issue.id} priority ${issue.priority.name}, impact ${issue.impact_id}, linked ${issue.itil_priority_linked}` : 'none'}`);
  return { status: res.status(), issue };
}

async function anonymousOverride(on) {
  await t.login('admin');
  await t.go('/roles');
  await t.page.click('table.roles a:text-is("Anonymous")');   // built-in roles are not in /roles.json
  await t.settle();
  await t.sudo();
  const id = (t.page.url().match(/roles\/(\d+)/) || [])[1];
  const box = t.page.locator('input[type=checkbox][value=override_itil_priority]');
  if (on) await box.check(); else await box.uncheck();
  return id;
}

// with the right: the helpdesk's Urgent stays
await anonymousOverride(true);
await t.shot('anonymous-role', 'Administration > Roles > Anonymous: "Override ITIL priority" ticked, the account helpdesk mail is processed as', { full: false });
await t.page.click('#content input[type=submit][name=commit], #content input[type=submit]');
await t.settle();
t.check('save anonymous role');
let r = await mail();
if (r.status !== 201) fail(`with the right: HTTP ${r.status}`);
if (r.issue?.priority?.name !== 'Urgent') fail(`with the right: priority ${r.issue?.priority?.name}, expected Urgent (the helpdesk setting)`);
if (r.issue) { await t.go(`/issues/${r.issue.id}`); await t.shot('kept', 'Helpdesk ticket from mail on the private project keeps the helpdesk priority Urgent'); }

// without the right: Redmine's default priority
await anonymousOverride(false);
await t.page.click('#content input[type=submit][name=commit], #content input[type=submit]');
await t.settle();
t.check('save anonymous role');
r = await mail();
if (r.issue?.priority?.name !== 'Normal') fail(`without the right: priority ${r.issue?.priority?.name}, expected Normal (the default)`);
if (r.issue) { await t.go(`/issues/${r.issue.id}`); await t.shot('default', 'Without the right the ticket gets the default priority Normal'); }

// wrong key: refused
r = await mail('not-the-key');
if (r.status !== 403) fail(`wrong key: HTTP ${r.status}, expected 403`);

// the outsider cannot see the private project's tickets
await t.login('outsider');
await t.go('/projects/e2e-private/issues', { status: 403 });

await t.login('admin');
await t.page.setContent(`<html><body style="font:13px monospace;white-space:pre-wrap;padding:12px"><h3>Helpdesk mails (helpdesk_mail.mjs)</h3>${log.map((l) => l.replace(/[<&]/g, (c) => ({ '<': '&lt;', '&': '&amp;' }[c]))).join('\n\n')}</body></html>`);
await t.shot('posted', 'The three helpdesk mails and their outcome: Urgent with the right, Normal without, 403 for a wrong key');
await t.done();
