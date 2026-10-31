import { verifyAppCheck, verifyIdToken, type Verified } from './auth';
import { analyze, GeminiBusy } from './gemini';
import { PROMPT_VERSION, type ScanType } from './prompts';
import { IP_PER_HOUR } from './quota';
import { tierOf } from './prompts';
import { dayOf } from './quota';

export { UserQuota, Limiter } from './quota';

export interface Env {
  USER_QUOTA: DurableObjectNamespace; LIMITER: DurableObjectNamespace;
  GEMINI_API_KEY: string; GEMINI_MODEL: string;
  FIREBASE_PROJECT_ID: string; FIREBASE_PROJECT_NUMBER: string;
  DAILY_CAP: string; REQUIRE_APP_CHECK?: string;
}

export interface Deps {
  verifyId: (t: string) => Promise<Verified>;
  verifyAppCheck: (t: string) => Promise<void>;
  analyze: typeof analyze;
  now: () => number;
}

export const MAX_BYTES = 1_500_000;
const json = (o: unknown, status = 200) =>
  new Response(JSON.stringify(o), { status, headers: { 'content-type': 'application/json', 'cache-control': 'no-store' } });
const err = (code: string, status: number) => json({ error: code }, status);

const call = async (ns: DurableObjectNamespace, name: string, body: unknown) =>
  (await ns.get(ns.idFromName(name)).fetch('https://do/', { method: 'POST', body: JSON.stringify(body) })).json() as Promise<any>;

async function sha(s: string) {
  const d = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(s));
  return [...new Uint8Array(d)].slice(0, 12).map((b) => b.toString(16).padStart(2, '0')).join('');
}
function toBase64(buf: Uint8Array) {
  let s = '';
  for (let i = 0; i < buf.length; i += 0x8000) s += String.fromCharCode(...buf.subarray(i, i + 0x8000));
  return btoa(s);
}

async function authenticate(req: Request, env: Env, deps: Deps): Promise<Verified | Response> {
  const bearer = /^Bearer (.+)$/.exec(req.headers.get('authorization') ?? '')?.[1];
  if (!bearer) return err('unauthorized', 401);
  let user: Verified;
  try { user = await deps.verifyId(bearer); } catch { return err('unauthorized', 401); }
  if (env.REQUIRE_APP_CHECK !== 'false') {
    const ac = req.headers.get('x-firebase-appcheck');
    if (!ac) return err('unauthorized', 401);
    try { await deps.verifyAppCheck(ac); } catch { return err('unauthorized', 401); }
  }
  return user;
}

export async function handle(req: Request, env: Env, deps: Deps): Promise<Response> {
  const url = new URL(req.url);
  const now = deps.now();

  if (req.method === 'DELETE' && url.pathname === '/account') {
    const u = await authenticate(req, env, deps);
    if (u instanceof Response) return u;
    await call(env.USER_QUOTA, u.uid, { op: 'delete', now });
    return json({ ok: true });
  }

  if (req.method !== 'POST' || url.pathname !== '/analyze') return err('not_found', 404);
  const type = url.searchParams.get('type');
  if (type !== 'bean' && type !== 'coffee') return err('bad_request', 400);
  if (Number(req.headers.get('content-length') ?? 0) > MAX_BYTES) return err('too_large', 413);

  const u = await authenticate(req, env, deps);
  if (u instanceof Response) return u;

  const bytes = new Uint8Array(await req.arrayBuffer());
  if (bytes.length > MAX_BYTES) return err('too_large', 413);
  if (bytes.length < 4 || bytes[0] !== 0xff || bytes[1] !== 0xd8 || bytes[2] !== 0xff) return err('bad_request', 400);

  // حد IP (ساعة) ثم المعدل والحصة للمستخدم ثم السقف اليومي الكلي (بلا خصم بعد)
  const ip = await sha(req.headers.get('cf-connecting-ip') ?? 'unknown');
  const hourKey = new Date(now).toISOString().slice(0, 13);
  const ipv = await call(env.LIMITER, `ip:${ip}`, { op: 'hit', limit: IP_PER_HOUR, windowKey: hourKey, now });
  if (!ipv.ok) return err('busy', 429);

  const v = await call(env.USER_QUOTA, u.uid, { op: 'check', isGuest: u.isGuest, now });
  if (!v.ok) return v.reason === 'quota_exhausted' ? err('quota_exhausted', 403) : err('busy', 429);

  const day = dayOf(now);
  const cap = await call(env.LIMITER, 'global', { op: 'peek', limit: Number(env.DAILY_CAP) || 300, windowKey: day, now });
  if (!cap.ok) return err('busy', 503);

  let result;
  try {
    result = await deps.analyze(env.GEMINI_API_KEY, env.GEMINI_MODEL, type as ScanType, toBase64(bytes));
  } catch (e) {
    return e instanceof GeminiBusy ? err('busy', 503) : err('busy', 502);
  }

  let remaining = v.remaining;
  if (result.status === 'ok') {
    const c = await call(env.USER_QUOTA, u.uid, { op: 'commit', isGuest: u.isGuest, now });
    remaining = c.remaining;
    await call(env.LIMITER, 'global', { op: 'hit', limit: Number(env.DAILY_CAP) || 300, windowKey: day, now });
  }
  return json({ status: result.status, score: result.score, tier: result.status === 'ok' ? tierOf(result.score) : null, notes: result.notes, promptVersion: PROMPT_VERSION, quota: { remaining } });
}

export default {
  fetch: (req: Request, env: Env) => handle(req, env, {
    verifyId: (t) => verifyIdToken(t, env.FIREBASE_PROJECT_ID),
    verifyAppCheck: (t) => verifyAppCheck(t, env.FIREBASE_PROJECT_NUMBER),
    analyze, now: () => Date.now(),
  }),
};
