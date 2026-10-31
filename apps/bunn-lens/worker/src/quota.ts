// منطق الحصة والمعدل (نقي، قابل للاختبار) + كائنات Durable Objects التي تغلّفه.
export const GUEST_LIMIT = 2;
export const MEMBER_MONTHLY = 5;
export const USER_PER_MIN = 3;
export const IP_PER_HOUR = 20;

/** الشهر بتوقيت UTC+3 بصيغة YYYY-MM. */
export const periodOf = (now: number) => new Date(now + 3 * 3600_000).toISOString().slice(0, 7);
export const dayOf = (now: number) => new Date(now + 3 * 3600_000).toISOString().slice(0, 10);

export interface UserState { period: string; used: number; guestUsed: number; hits: number[] }
export const emptyUser = (now: number): UserState => ({ period: periodOf(now), used: 0, guestUsed: 0, hits: [] });

export type UserVerdict = { ok: true; remaining: number } | { ok: false; reason: 'rate_limited' | 'quota_exhausted'; remaining: number };

const remainingOf = (s: UserState, isGuest: boolean) => (isGuest ? GUEST_LIMIT - s.guestUsed : MEMBER_MONTHLY - s.used);

/** يتحقق من المعدل والحصة دون خصم؛ يسجّل الطلب في نافذة المعدل. */
export function checkUser(s: UserState, isGuest: boolean, now: number): UserVerdict {
  if (s.period !== periodOf(now)) { s.period = periodOf(now); s.used = 0; }
  s.hits = s.hits.filter((t) => now - t < 60_000);
  const remaining = Math.max(0, remainingOf(s, isGuest));
  if (s.hits.length >= USER_PER_MIN) return { ok: false, reason: 'rate_limited', remaining };
  s.hits.push(now);
  if (remaining <= 0) return { ok: false, reason: 'quota_exhausted', remaining: 0 };
  return { ok: true, remaining };
}

/** خصم فحص ناجح؛ يعيد المتبقي. */
export function commitUser(s: UserState, isGuest: boolean, now: number): number {
  if (s.period !== periodOf(now)) { s.period = periodOf(now); s.used = 0; }
  if (isGuest) s.guestUsed++; else s.used++;
  return Math.max(0, remainingOf(s, isGuest));
}

interface Storage { get<T>(k: string): Promise<T | undefined>; put(k: string, v: unknown): Promise<void>; deleteAll(): Promise<void> }
interface State { storage: Storage }
const json = (o: unknown, status = 200) => new Response(JSON.stringify(o), { status, headers: { 'content-type': 'application/json' } });

/** كائن لكل uid. العمليات تُنفَّذ تسلسلياً داخل الـDO فلا سباق. */
export class UserQuota {
  constructor(private state: State, _env?: unknown) {}
  async fetch(req: Request): Promise<Response> {
    const { op, isGuest, now = Date.now() } = (await req.json()) as { op: string; isGuest: boolean; now?: number };
    if (op === 'delete') { await this.state.storage.deleteAll(); return json({ ok: true }); }
    const s = (await this.state.storage.get<UserState>('s')) ?? emptyUser(now);
    if (op === 'check') {
      const v = checkUser(s, isGuest, now);
      await this.state.storage.put('s', s);
      return json(v);
    }
    if (op === 'commit') {
      const remaining = commitUser(s, isGuest, now);
      await this.state.storage.put('s', s);
      return json({ remaining });
    }
    return json({ error: 'bad_op' }, 400);
  }
}

/** عدّاد عام: نافذة (ثوانٍ) وحد؛ للـIP (ساعة) وللسقف اليومي الكلي. المفتاح اسم الكائن. */
export class Limiter {
  constructor(private state: State, _env?: unknown) {}
  async fetch(req: Request): Promise<Response> {
    const { op, limit, windowKey, now = Date.now() } = (await req.json()) as { op: 'hit' | 'peek'; limit: number; windowKey: string; now?: number };
    const cur = (await this.state.storage.get<{ key: string; n: number }>('c')) ?? { key: windowKey, n: 0 };
    if (cur.key !== windowKey) { cur.key = windowKey; cur.n = 0; }
    if (cur.n >= limit) return json({ ok: false });
    if (op === 'hit') { cur.n++; await this.state.storage.put('c', cur); }
    return json({ ok: true, count: cur.n });
  }
}
