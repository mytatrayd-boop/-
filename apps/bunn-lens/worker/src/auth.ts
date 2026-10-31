// التحقق من Firebase ID token وApp Check token (JWT RS256) بمفاتيح JWKS العامة عبر WebCrypto.
export const ID_JWKS = 'https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com';
export const APPCHECK_JWKS = 'https://firebaseappcheck.googleapis.com/v1/jwks';

export interface Verified { uid: string; isGuest: boolean }
type Fetch = typeof fetch;
const cache = new Map<string, { at: number; keys: JsonWebKey[] }>();
const TTL = 3600_000;

const b64 = (s: string) => Uint8Array.from(atob(s.replace(/-/g, '+').replace(/_/g, '/')), (c) => c.charCodeAt(0));
const parse = (p: string) => JSON.parse(new TextDecoder().decode(b64(p)));

async function jwks(url: string, f: Fetch, now: number): Promise<JsonWebKey[]> {
  const c = cache.get(url);
  if (c && now - c.at < TTL) return c.keys;
  const r = await f(url);
  if (!r.ok) throw new Error('jwks');
  const keys = ((await r.json()) as { keys: JsonWebKey[] }).keys;
  cache.set(url, { at: now, keys });
  return keys;
}
export const clearJwksCache = () => cache.clear();

async function verifySig(token: string, url: string, f: Fetch, now: number) {
  const [h, p, s] = token.split('.');
  if (!h || !p || !s) throw new Error('malformed');
  const header = parse(h);
  if (header.alg !== 'RS256') throw new Error('alg');
  const jwk = (await jwks(url, f, now)).find((k: any) => k.kid === header.kid);
  if (!jwk) throw new Error('kid');
  const key = await crypto.subtle.importKey('jwk', jwk, { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' }, false, ['verify']);
  const ok = await crypto.subtle.verify('RSASSA-PKCS1-v1_5', key, b64(s), new TextEncoder().encode(`${h}.${p}`));
  if (!ok) throw new Error('signature');
  return parse(p);
}

const checkTime = (c: any, nowSec: number) => {
  if (typeof c.exp !== 'number' || c.exp <= nowSec) throw new Error('expired');
  if (typeof c.iat === 'number' && c.iat > nowSec + 300) throw new Error('iat');
};

export async function verifyIdToken(token: string, projectId: string, f: Fetch = fetch, now = Date.now()): Promise<Verified> {
  const c = await verifySig(token, ID_JWKS, f, now);
  checkTime(c, now / 1000);
  if (c.aud !== projectId || c.iss !== `https://securetoken.google.com/${projectId}`) throw new Error('aud/iss');
  const uid = c.sub;
  if (typeof uid !== 'string' || !uid || uid.length > 128) throw new Error('sub');
  return { uid, isGuest: c.firebase?.sign_in_provider === 'anonymous' };
}

export async function verifyAppCheck(token: string, projectNumber: string, f: Fetch = fetch, now = Date.now()): Promise<void> {
  const c = await verifySig(token, APPCHECK_JWKS, f, now);
  checkTime(c, now / 1000);
  const aud: string[] = Array.isArray(c.aud) ? c.aud : [c.aud];
  if (c.iss !== `https://firebaseappcheck.googleapis.com/${projectNumber}` || !aud.includes(`projects/${projectNumber}`)) throw new Error('aud/iss');
}
