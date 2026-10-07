// REST API: impact, urgency and itil_priority_linked on issues, with and
// without "override ITIL priority"; the settings API (global: admin only,
// project: "manage ITIL priority settings") and its refusals.
import { e2e } from '../../.codex/e2e/lib.mjs';

const P = 'e2e-project';
const t = await e2e('rest_api');
const fail = (m) => t.problems.push(m);
const pw = { admin: process.env.RMP_ADMIN_PASSWORD || 'Redmine7Test!' };
const auth = (u) => ({ Authorization: 'Basic ' + Buffer.from(`${u}:${pw[u] || process.env.RMP_USER_PASSWORD || 'Redmine7Test!'}`).toString('base64'),
                       'Content-Type': 'application/json' });
const log = [];
async function call(user, method, url, data) {
  await t.page.waitForTimeout(1100); // Redmine 7 throttles repeated basic-auth logins
  const res = await t.page.request.fetch(t.BASE + url, { method, headers: user ? auth(user) : {}, data: data ? JSON.stringify(data) : undefined });
  const body = await res.text();
  log.push(`${user || 'anonymous'} ${method} ${url}${data ? ' ' + JSON.stringify(data) : ''} -> ${res.status()} ${body.slice(0, 160)}`);
  return { status: res.status(), json: body && body.startsWith('{') ? JSON.parse(body) : null };
}

await t.anonymous();
// helpdesk user creates an issue and tries to force the priority
let r = await call('reporter', 'POST', '/issues.json', { issue: { project_id: P, subject: 'API helpdesk', impact_id: 3, urgency_id: 2, priority_id: 5, itil_priority_linked: false } });
if (r.status !== 201) fail(`helpdesk create: HTTP ${r.status}`);
const id = r.json?.issue?.id;
r = await call('reporter', 'GET', `/issues/${id}.json`);
const a = r.json?.issue || {};
if (a.priority?.name !== 'High' || a.itil_priority_linked !== true || a.impact_id !== 3 || a.urgency_id !== 2) fail(`helpdesk create: got ${JSON.stringify([a.priority?.name, a.itil_priority_linked, a.impact_id, a.urgency_id])}, expected High, linked, 3, 2`);

// operator unlinks and sets Immediate
r = await call('manager', 'PUT', `/issues/${id}.json`, { issue: { priority_id: (await prio('Immediate')), itil_priority_linked: false } });
if (r.status !== 204) fail(`operator update: HTTP ${r.status}`);
r = await call('manager', 'GET', `/issues/${id}.json`);
if (r.json?.issue?.priority?.name !== 'Immediate' || r.json?.issue?.itil_priority_linked !== false) fail('operator update: not Immediate/unlinked');

// helpdesk changes urgency, may not relink: the operator's priority stays
r = await call('reporter', 'PUT', `/issues/${id}.json`, { issue: { urgency_id: 1, itil_priority_linked: true, priority_id: (await prio('Low')) } });
if (r.status !== 204) fail(`helpdesk update: HTTP ${r.status}`);
r = await call('reporter', 'GET', `/issues/${id}.json`);
if (r.json?.issue?.priority?.name !== 'Immediate' || r.json?.issue?.urgency_id !== 1) fail('helpdesk update: priority changed or urgency not saved');

// list API has the fields too
r = await call('manager', 'GET', `/issues.json?issue_id=${id}`);
if (!('impact_id' in (r.json?.issues?.[0] || {})) || !('itil_priority_linked' in (r.json?.issues?.[0] || {}))) fail('index API: fields missing');

// settings API
r = await call('admin', 'GET', '/itil_priority/api/settings.json');
if (r.status !== 200 || !r.json?.priority_i3_u3) fail(`global settings as admin: HTTP ${r.status}`);
r = await call('manager', 'GET', '/itil_priority/api/settings.json');
if (r.status !== 403) fail(`global settings as manager: HTTP ${r.status}, expected 403`);
r = await call(null, 'GET', '/itil_priority/api/settings.json');
if (r.status !== 401) fail(`global settings anonymous: HTTP ${r.status}, expected 401`);
r = await call('manager', 'GET', `/projects/${P}/itil_priority/api/settings.json`);
if (r.status !== 200 || !r.json?.tracker_settings) fail(`project settings as manager: HTTP ${r.status}`);
r = await call('reporter', 'GET', `/projects/${P}/itil_priority/api/settings.json`);
if (r.status !== 403) fail(`project settings as reporter: HTTP ${r.status}, expected 403`);
r = await call('outsider', 'GET', '/projects/e2e-private/itil_priority/api/settings.json');
if (r.status !== 403 && r.status !== 404) fail(`private project settings as outsider: HTTP ${r.status}, expected 403/404`);
r = await call('admin', 'PUT', '/itil_priority/api/settings.json', { settings: { help_urgency_2: 'API urgency text', evil_key: 'x' } });
if (r.status !== 200 || r.json?.help_urgency_2 !== 'API urgency text' || 'evil_key' in (r.json || {})) fail('global settings PUT: help text not stored or unknown key accepted');
await call('admin', 'PUT', '/itil_priority/api/settings.json', { settings: { help_urgency_2: '' } });   // back to the seed

// evidence page: the API answers rendered as text
await t.login('manager');
await t.page.setContent(`<html><body style="font:13px monospace;white-space:pre-wrap;padding:12px"><h3>REST API calls (rest_api.mjs)</h3>${log.map((l) => l.replace(/[<&]/g, (c) => ({ '<': '&lt;', '&': '&amp;' }[c]))).join('\n\n')}</body></html>`);
await t.shot('calls', 'Every REST call of this scenario with its HTTP status and the start of the answer');
await t.go(`/issues/${id}`);
await t.shot('issue', 'The issue changed through the API: priority Immediate kept after the helpdesk user changed the urgency and tried to relink');

await t.done();

async function prio(name) {
  const res = await t.page.request.get(`${t.BASE}/enumerations/issue_priorities.json`, { headers: auth('admin') });
  return (await res.json()).issue_priorities.find((p) => p.name === name).id;
}
