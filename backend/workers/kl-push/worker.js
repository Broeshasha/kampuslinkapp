// KampusLink kl-push: server-side reminders (MOT-3). Cloudflare Worker, free plan.
// Every 15 min (Cron Trigger): asks Supabase push_batch() who needs a push, sends them through
// Firebase Cloud Messaging (HTTP v1), removes phones that are gone (push_dead_tokens).
// Settings (Worker > Settings > Variables and Secrets):
//   SB_URL     text    https://<project>.supabase.co
//   SB_SECRET  secret  the Supabase SECRET key (sb_secret_...)
//   FCM_SA     secret  the whole Firebase service-account JSON file
// Visiting the Worker URL only says "kl-push ok" (no data, no secrets).

const enc = new TextEncoder();
const b64url = (buf) =>
  btoa(String.fromCharCode(...new Uint8Array(buf))).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
const b64urlText = (s) => b64url(enc.encode(s));

let cached = { token: null, until: 0 };

async function googleToken(sa) {
  const now = Math.floor(Date.now() / 1000);
  if (cached.token && cached.until > now + 60) return cached.token;
  const header = b64urlText(JSON.stringify({ alg: 'RS256', typ: 'JWT' }));
  const claims = b64urlText(JSON.stringify({
    iss: sa.client_email,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600,
  }));
  const pem = sa.private_key.replace(/-----[^-]+-----/g, '').replace(/\s+/g, '');
  const der = Uint8Array.from(atob(pem), (c) => c.charCodeAt(0));
  const key = await crypto.subtle.importKey('pkcs8', der, { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' }, false, ['sign']);
  const sig = await crypto.subtle.sign('RSASSA-PKCS1-v1_5', key, enc.encode(`${header}.${claims}`));
  const res = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'content-type': 'application/x-www-form-urlencoded' },
    body: `grant_type=urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Ajwt-bearer&assertion=${header}.${claims}.${b64url(sig)}`,
  });
  if (!res.ok) throw new Error(`google token ${res.status}`);
  const j = await res.json();
  cached = { token: j.access_token, until: now + (j.expires_in || 3600) };
  return cached.token;
}

async function rpc(env, name, body) {
  const res = await fetch(`${env.SB_URL}/rest/v1/rpc/${name}`, {
    method: 'POST',
    headers: { apikey: env.SB_SECRET, 'content-type': 'application/json' },
    body: JSON.stringify(body),
  });
  if (!res.ok) throw new Error(`${name} ${res.status} ${(await res.text()).slice(0, 200)}`);
  return res.json();
}

async function run(env) {
  const sa = JSON.parse(env.FCM_SA);
  const batch = await rpc(env, 'push_batch', { p_limit: 300 });
  if (!Array.isArray(batch) || batch.length === 0) return { sent: 0, failed: 0, dead: 0 };
  const access = await googleToken(sa);
  const dead = [];
  let sent = 0, failed = 0;
  for (const m of batch) {
    for (const token of m.tokens || []) {
      const res = await fetch(`https://fcm.googleapis.com/v1/projects/${sa.project_id}/messages:send`, {
        method: 'POST',
        headers: { authorization: `Bearer ${access}`, 'content-type': 'application/json' },
        body: JSON.stringify({
          message: {
            token,
            notification: { title: m.title, body: m.body },
            data: { kind: String(m.kind || 'comeback') },
            android: {
              priority: 'high',
              ttl: '21600s',
              notification: { channel_id: 'study_reminders', icon: 'ic_stat_kampuslink', tag: 'kl_study' },
            },
          },
        }),
      });
      if (res.ok) { sent++; continue; }
      failed++;
      const txt = await res.text();
      if (res.status === 404 || txt.includes('UNREGISTERED') || txt.includes('INVALID_ARGUMENT')) dead.push(token);
    }
  }
  if (dead.length) await rpc(env, 'push_dead_tokens', { p_tokens: dead });
  return { sent, failed, dead: dead.length };
}

export default {
  async scheduled(event, env, ctx) {
    ctx.waitUntil(run(env).then((r) => console.log('kl-push', JSON.stringify(r)), (e) => console.log('kl-push error', String(e))));
  },
  async fetch() {
    return new Response('kl-push ok', { headers: { 'content-type': 'text/plain' } });
  },
};
