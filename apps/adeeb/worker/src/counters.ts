import { DurableObject } from "cloudflare:workers";
import type { Env } from "./config";
import { nextUtcMidnight, utcDay } from "./time";

/**
 * العدّادات اليومية وقاطع الدائرة في Durable Object واحد مدعوم بـ SQLite
 * (ARCHITECTURE §8.3، D10). كل عملية متزامنة داخل `transactionSync` فهي ذرية،
 * والـ DO يعالج الطلبات واحداً تلو الآخر فلا يتجاوز طلبان متزامنان الحد.
 *
 * لا يُخزَّن معرّف الجهاز ولا IP خاماً؛ المفاتيح HMAC يحسبها الـ Worker.
 * الوقت يُمرَّر من الـ Worker (يسهّل اختبار تجدد اليوم)؛ المنبّه وحده يستخدم الساعة.
 */

export type Kind = "device" | "ip" | "global";

export interface Limits {
  device: number;
  ip: number;
  global: number;
}

export interface ReserveInput {
  day: string;
  nowMs: number;
  device: string;
  ip: string;
  limits: Limits;
}

export type ReserveResult =
  | { ok: true; remaining: number }
  | { ok: false; reason: "DEVICE" | "IP" | "GLOBAL" | "EXHAUSTED"; remaining: number };

const GLOBAL_KEY = "*";
const BREAKER = "gemini_exhausted_until";

export class CounterStore extends DurableObject<Env> {
  private readonly sql: SqlStorage;

  constructor(ctx: DurableObjectState, env: Env) {
    super(ctx, env);
    this.sql = ctx.storage.sql;
    this.sql.exec(
      `CREATE TABLE IF NOT EXISTS counters (
         day TEXT NOT NULL,
         kind TEXT NOT NULL,
         key_hash TEXT NOT NULL,
         count INTEGER NOT NULL,
         PRIMARY KEY (day, kind, key_hash)
       )`,
    );
    this.sql.exec(
      `CREATE TABLE IF NOT EXISTS flags (name TEXT PRIMARY KEY, value INTEGER NOT NULL)`,
    );
  }

  private count(day: string, kind: Kind, key: string): number {
    const row = this.sql
      .exec<{ count: number }>(
        "SELECT count FROM counters WHERE day = ? AND kind = ? AND key_hash = ?",
        day,
        kind,
        key,
      )
      .toArray()[0];
    return row?.count ?? 0;
  }

  private bump(day: string, kind: Kind, key: string, delta: 1 | -1): void {
    if (delta === 1) {
      this.sql.exec(
        `INSERT INTO counters (day, kind, key_hash, count) VALUES (?, ?, ?, 1)
         ON CONFLICT (day, kind, key_hash) DO UPDATE SET count = count + 1`,
        day,
        kind,
        key,
      );
    } else {
      this.sql.exec(
        `UPDATE counters SET count = MAX(count - 1, 0)
         WHERE day = ? AND kind = ? AND key_hash = ?`,
        day,
        kind,
        key,
      );
    }
  }

  private breakerUntil(): number {
    const row = this.sql
      .exec<{ value: number }>("SELECT value FROM flags WHERE name = ?", BREAKER)
      .toArray()[0];
    return row?.value ?? 0;
  }

  /** فحص الحدود الثلاثة وقاطع الدائرة وحجز سؤال واحد في معاملة واحدة. */
  async reserve(input: ReserveInput): Promise<ReserveResult> {
    const { day, device, ip, limits, nowMs } = input;
    const result = this.ctx.storage.transactionSync((): ReserveResult => {
      const deviceUsed = this.count(day, "device", device);
      const deviceLeft = Math.max(limits.device - deviceUsed, 0);
      if (this.breakerUntil() > nowMs) {
        return { ok: false, reason: "EXHAUSTED", remaining: deviceLeft };
      }
      if (deviceUsed >= limits.device) return { ok: false, reason: "DEVICE", remaining: 0 };
      if (this.count(day, "ip", ip) >= limits.ip) {
        return { ok: false, reason: "IP", remaining: 0 };
      }
      if (this.count(day, "global", GLOBAL_KEY) >= limits.global) {
        return { ok: false, reason: "GLOBAL", remaining: deviceLeft };
      }
      this.bump(day, "device", device, 1);
      this.bump(day, "ip", ip, 1);
      this.bump(day, "global", GLOBAL_KEY, 1);
      return { ok: true, remaining: deviceLeft - 1 };
    });
    if (result.ok) await this.ensureAlarm();
    return result;
  }

  /** استرداد سؤال محجوز (فشل Gemini). يعيد الباقي للجهاز بعد الاسترداد. */
  refund(input: { day: string; device: string; ip: string; dailyPerDevice: number }): number {
    const { day, device, ip } = input;
    return this.ctx.storage.transactionSync(() => {
      this.bump(day, "device", device, -1);
      this.bump(day, "ip", ip, -1);
      this.bump(day, "global", GLOBAL_KEY, -1);
      return Math.max(input.dailyPerDevice - this.count(day, "device", device), 0);
    });
  }

  /** الأسئلة المستهلكة للجهاز اليوم (بلا استهلاك). */
  used(day: string, device: string): number {
    return this.count(day, "device", device);
  }

  /** قاطع الدائرة: لا استدعاء لـ Gemini قبل [untilMs]. */
  tripBreaker(untilMs: number): void {
    this.sql.exec(
      `INSERT INTO flags (name, value) VALUES (?, ?)
       ON CONFLICT (name) DO UPDATE SET value = MAX(value, excluded.value)`,
      BREAKER,
      untilMs,
    );
  }

  /** يحذف عدّادات الأيام السابقة لـ [today] وعلامة القاطع المنتهية. */
  cleanup(today: string, nowMs: number): void {
    this.sql.exec("DELETE FROM counters WHERE day < ?", today);
    this.sql.exec("DELETE FROM flags WHERE name = ? AND value <= ?", BREAKER, nowMs);
  }

  /** عدد الصفوف (للاختبار ومراقبة التنظيف). */
  rowCount(): number {
    return this.sql.exec<{ n: number }>("SELECT COUNT(*) AS n FROM counters").one().n;
  }

  private async ensureAlarm(): Promise<void> {
    if ((await this.ctx.storage.getAlarm()) === null) {
      await this.ctx.storage.setAlarm(nextUtcMidnight(Date.now()) + 60_000);
    }
  }

  override async alarm(): Promise<void> {
    const now = Date.now();
    this.cleanup(utcDay(now), now);
    // لا إعادة جدولة هنا: أول حجز بعد التنظيف يضبط منبّه الليلة التالية.
  }
}
