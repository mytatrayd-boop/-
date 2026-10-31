import { beforeEach, describe, expect, it } from 'vitest';
import { clearJwksCache, verifyAppCheck, verifyIdToken, ID_JWKS, APPCHECK_JWKS } from '../src/auth';
import { buildBody, parseCompletion, roundScore, analyze, GeminiBusy } from '../src/gemini';
import { checkUser, commitUser, emptyUser, periodOf, UserQuota, Limiter } from '../src/quota';
import { handle, MAX_BYTES, type Env, type Deps } from '../src/handler';

// ---------- أدوات ----------
const enc = (o: unknown) => btoa(JSON.stringify(o)).replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_');
const b64u = (b: ArrayBuffer) => btoa(String.fromCharCode(...new Uint8Array(b))).replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_');
async function keyPair() {
  const kp = (await crypto.subtle.generateKey({ name: 'RSASSA-PKCS1-v1_5', modulusLength: 2048, publicExponent: new Uint8Array([1, 0, 1]), hash: 'SHA-256' }, true, ['sign', 'verify'])) as CryptoKeyPair;
  const jwk = { ...((await crypto.subtle.exportKey('jwk', kp.publicKey)) as JsonWebKey), kid: 'k1', alg: 'RS256', use: 'sig' } as JsonWebKey;
  return { priv: kp.privateKey, jwk };
}
async function sign(priv: CryptoKey, claims: object, header: object = { alg: 'RS256', kid: 'k1' }) {
  const data = `${enc(header)}.${enc(claims)}`;
  return `${data}.${b64u(await crypto.subtle.sign('RSASSA-PKCS1-v1_5', priv, new TextEncoder().encode(data)))}`;
}
const NOW = Date.UTC(2026, 9, 31, 12);
const sec = NOW / 1000;
const jwksFetch = (map: Record<string, JsonWebKey>) => (async (u: any) => new Response(JSON.stringify({ keys: [map[String(u)]] }))) as typeof fetch;

// ---------- المصادقة ----------
describe('auth', () => {
  beforeEach(() => clearJwksCache());
  it('يقبل ID token صالحاً ويستنتج الضيف من الموفّر', async () => {
    const { priv, jwk } = await keyPair();
    const t = await sign(priv, { aud: 'p1', iss: 'https://securetoken.google.com/p1', sub: 'u1', exp: sec + 600, iat: sec, firebase: { sign_in_provider: 'anonymous' } });
    expect(await verifyIdToken(t, 'p1', jwksFetch({ [ID_JWKS]: jwk }), NOW)).toEqual({ uid: 'u1', isGuest: true });
  });
  it('يرفض: منتهٍ، مشروع خاطئ، توقيع مزوّر، alg مختلف', async () => {
    const a = await keyPair(); const b = await keyPair();
    const f = jwksFetch({ [ID_JWKS]: a.jwk });
    const ok = { aud: 'p1', iss: 'https://securetoken.google.com/p1', sub: 'u1', exp: sec + 600, iat: sec };
    await expect(verifyIdToken(await sign(a.priv, { ...ok, exp: sec - 1 }), 'p1', f, NOW)).rejects.toThrow();
    await expect(verifyIdToken(await sign(a.priv, { ...ok, aud: 'other' }), 'p1', f, NOW)).rejects.toThrow();
    await expect(verifyIdToken(await sign(b.priv, ok), 'p1', f, NOW)).rejects.toThrow();
    await expect(verifyIdToken(await sign(a.priv, ok, { alg: 'none', kid: 'k1' }), 'p1', f, NOW)).rejects.toThrow();
  });
  it('App Check: صالح ومرفوض بمشروع خاطئ', async () => {
    const { priv, jwk } = await keyPair();
    const f = jwksFetch({ [APPCHECK_JWKS]: jwk });
    const c = { iss: 'https://firebaseappcheck.googleapis.com/123', aud: ['projects/123'], exp: sec + 600, iat: sec, sub: 'app' };
    await expect(verifyAppCheck(await sign(priv, c), '123', f, NOW)).resolves.toBeUndefined();
    clearJwksCache();
    await expect(verifyAppCheck(await sign(priv, c), '999', f, NOW)).rejects.toThrow();
  });
});

// ---------- الحصة ----------
describe('quota', () => {
  it('الضيف: فحصان إجمالاً ثم تنفد', () => {
    const s = emptyUser(NOW);
    expect(checkUser(s, true, NOW)).toEqual({ ok: true, remaining: 2 });
    expect(commitUser(s, true, NOW)).toBe(1);
    checkUser(s, true, NOW + 61_000); expect(commitUser(s, true, NOW + 61_000)).toBe(0);
    expect(checkUser(s, true, NOW + 122_000)).toMatchObject({ ok: false, reason: 'quota_exhausted' });
    // لا تتجدد في الشهر التالي للضيف
    expect(checkUser(s, true, NOW + 40 * 86400_000)).toMatchObject({ ok: false, reason: 'quota_exhausted' });
  });
  it('المسجّل: 5 شهرياً وتتجدد بتغيّر الشهر (UTC+3)', () => {
    const s = emptyUser(NOW);
    for (let i = 0; i < 5; i++) { const t = NOW + i * 61_000; expect(checkUser(s, false, t).ok).toBe(true); commitUser(s, false, t); }
    expect(checkUser(s, false, NOW + 400_000)).toMatchObject({ ok: false, reason: 'quota_exhausted' });
    const next = NOW + 32 * 86400_000;
    expect(periodOf(next)).not.toBe(periodOf(NOW));
    expect(checkUser(s, false, next)).toEqual({ ok: true, remaining: 5 });
  });
  it('المعدل: 3 طلبات في الدقيقة ثم يُرفض الرابع', () => {
    const s = emptyUser(NOW);
    for (let i = 0; i < 3; i++) expect(checkUser(s, false, NOW + i).ok).toBe(true);
    expect(checkUser(s, false, NOW + 10)).toMatchObject({ ok: false, reason: 'rate_limited' });
    expect(checkUser(s, false, NOW + 61_000).ok).toBe(true);
  });
  it('غير المحسوب لا يُخصم (check وحده لا يغيّر الحصة)', () => {
    const s = emptyUser(NOW);
    checkUser(s, false, NOW);
    expect(s.used).toBe(0);
  });
});

// ---------- Gemini ----------
describe('gemini', () => {
  const body = (o: unknown) => ({ choices: [{ message: { content: JSON.stringify(o) } }] });
  it('يحلل الرد ويقرّب الدرجة لأقرب 5', async () => {
    const f = (async () => new Response(JSON.stringify(body({ status: 'ok', score: 73, notes: ['أ', 'ب', 'ج'] })))) as typeof fetch;
    expect((await analyze('k', 'm', 'bean', 'AAAA', f)).score).toBe(75);
    expect(roundScore(102)).toBe(100);
  });
  it('يرفض ملاحظات ليست 3 أو درجة خارج المدى', () => {
    expect(() => parseCompletion(body({ status: 'ok', score: 50, notes: ['أ'] }))).toThrow();
    expect(() => parseCompletion(body({ status: 'ok', score: 150, notes: ['أ', 'ب', 'ج'] }))).toThrow();
  });
  it('429 → GeminiBusy ولا يُرسل المفتاح في الرابط', async () => {
    let seen = '';
    const f = (async (u: any) => { seen = String(u); return new Response('', { status: 429 }); }) as typeof fetch;
    await expect(analyze('SECRET', 'm', 'coffee', 'AAAA', f)).rejects.toBeInstanceOf(GeminiBusy);
    expect(seen).not.toContain('SECRET');
    expect(JSON.stringify(buildBody('bean', 'm', 'x')).includes('temperature":0')).toBe(true);
  });
});

// ---------- المسار الكامل ----------
function fakeNs<T>(Cls: new (s: any) => T) {
  const objs = new Map<string, any>();
  return {
    idFromName: (n: string) => n,
    get: (id: string) => {
      if (!objs.has(id)) { const m = new Map<string, unknown>(); objs.set(id, new Cls({ storage: { get: async (k: string) => m.get(k), put: async (k: string, v: unknown) => { m.set(k, structuredClone(v)); }, deleteAll: async () => m.clear() } })); }
      return { fetch: (u: string, init: RequestInit) => objs.get(id).fetch(new Request(u, init)) };
    },
  } as unknown as DurableObjectNamespace;
}
const JPEG = new Uint8Array([0xff, 0xd8, 0xff, 0xe0, 1, 2, 3]);
function setup(over: Partial<Deps> = {}, envOver: Partial<Env> = {}) {
  let t = NOW;
  const env: Env = { USER_QUOTA: fakeNs(UserQuota), LIMITER: fakeNs(Limiter), GEMINI_API_KEY: 'k', GEMINI_MODEL: 'm', FIREBASE_PROJECT_ID: 'p', FIREBASE_PROJECT_NUMBER: '1', DAILY_CAP: '300', ...envOver };
  const deps: Deps = {
    verifyId: async (tok) => { if (tok === 'bad') throw new Error('x'); return { uid: tok, isGuest: tok.startsWith('g') }; },
    verifyAppCheck: async (tok) => { if (tok === 'bad') throw new Error('x'); },
    analyze: async () => ({ status: 'ok', score: 80, notes: ['أ', 'ب', 'ج'] }),
    now: () => t, ...over,
  };
  const post = (tok: string | null, body: BodyInit = JPEG, q = '?type=bean', ac: string | null = 'ac') =>
    handle(new Request(`https://w/analyze${q}`, { method: 'POST', body, headers: { ...(tok ? { authorization: `Bearer ${tok}` } : {}), ...(ac ? { 'x-firebase-appcheck': ac } : {}), 'cf-connecting-ip': '1.1.1.1' } }), env, deps);
  return { env, deps, post, tick: (ms: number) => { t += ms; } };
}

describe('handler', () => {
  it('نجاح: يعيد النتيجة ويخصم', async () => {
    const { post } = setup();
    const r = await post('u1');
    expect(r.status).toBe(200);
    expect(await r.json()).toMatchObject({ status: 'ok', score: 80, promptVersion: 'v2', tier: 'good', quota: { remaining: 4 } });
  });
  it('بلا توكن أو App Check أو توكن سيئ → 401', async () => {
    const { post } = setup();
    expect((await post(null)).status).toBe(401);
    expect((await post('bad')).status).toBe(401);
    expect((await post('u1', JPEG, '?type=bean', null)).status).toBe(401);
    expect((await post('u1', JPEG, '?type=bean', 'bad')).status).toBe(401);
  });
  it('نوع خاطئ 400، صورة ليست JPEG 400، كبيرة 413', async () => {
    const { post } = setup();
    expect((await post('u1', JPEG, '?type=x')).status).toBe(400);
    expect((await post('u1', new Uint8Array([1, 2, 3, 4]))).status).toBe(400);
    expect((await post('u1', new Uint8Array(MAX_BYTES + 1))).status).toBe(413);
  });
  it('unclear/not_coffee/أخطاء Gemini لا تُخصم', async () => {
    let mode = 'unclear';
    const { post, tick } = setup({ analyze: async () => { if (mode === 'busy') throw new GeminiBusy(); return { status: 'unclear', score: 0, notes: ['', '', ''] }; } });
    expect(await (await post('u1')).json()).toMatchObject({ status: 'unclear', quota: { remaining: 5 } });
    mode = 'busy'; tick(61_000);
    const r = await post('u1'); expect(r.status).toBe(503);
    mode = 'unclear'; tick(61_000);
    expect(await (await post('u1')).json()).toMatchObject({ quota: { remaining: 5 } });
  });
  it('الضيف: فحصان ثم 403 quota_exhausted', async () => {
    const { post, tick } = setup();
    expect((await post('g1')).status).toBe(200); tick(61_000);
    expect((await post('g1')).status).toBe(200); tick(61_000);
    const r = await post('g1');
    expect(r.status).toBe(403); expect(await r.json()).toEqual({ error: 'quota_exhausted' });
  });
  it('المعدل: الرابع في الدقيقة 429', async () => {
    const { post } = setup({ analyze: async () => ({ status: 'unclear', score: 0, notes: ['', '', ''] }) });
    for (let i = 0; i < 3; i++) expect((await post('u1')).status).toBe(200);
    expect((await post('u1')).status).toBe(429);
  });
  it('السقف اليومي الكلي يوقف الخدمة 503', async () => {
    const { post, tick } = setup({}, { DAILY_CAP: '2' });
    expect((await post('u1')).status).toBe(200); tick(61_000);
    expect((await post('u2')).status).toBe(200); tick(61_000);
    expect((await post('u3')).status).toBe(503);
  });
  it('حد IP: بعد 20 طلباً في الساعة 429', async () => {
    const { post, tick } = setup({ analyze: async () => ({ status: 'unclear', score: 0, notes: ['', '', ''] }) });
    let last = 200;
    for (let i = 0; i < 21; i++) { last = (await post(`u${i}`)).status; tick(1000); }
    expect(last).toBe(429);
  });
  it('DELETE /account يمسح الحصة', async () => {
    const { post, env, deps } = setup();
    await post('u1');
    const d = await handle(new Request('https://w/account', { method: 'DELETE', headers: { authorization: 'Bearer u1', 'x-firebase-appcheck': 'ac' } }), env, deps);
    expect(d.status).toBe(200);
    expect(await (await post('u1')).json()).toMatchObject({ quota: { remaining: 4 } });
  });
  it('مسار مجهول 404', async () => {
    const { env, deps } = setup();
    expect((await handle(new Request('https://w/x'), env, deps)).status).toBe(404);
  });
});
