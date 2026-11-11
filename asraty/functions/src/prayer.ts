// Prayer times for the family's location (set by the owner), Umm al-Qura method.
// Mirrored in app/lib/core/prayer.dart, which schedules the reminders on each phone.
import { CalculationMethod, Coordinates, PrayerTimes } from "adhan";
import { dayKey } from "./logic";

export const PRAYERS = ["fajr", "dhuhr", "asr", "maghrib", "isha"] as const;
export type PrayerKey = (typeof PRAYERS)[number];

export const PRAYER_NAMES: Record<PrayerKey, string> = {
  fajr: "الفجر", dhuhr: "الظهر", asr: "العصر", maghrib: "المغرب", isha: "العشاء",
};

export interface PrayerSettings {
  enabled: boolean;
  lat: number;
  lng: number;
  points: number;
  /**
   * «مهلة أداء الصلاة» (owner's request, Nov 2026): minutes after the adhan a prayer keeps its points,
   * per prayer. `all` applies to every member; a member id overrides it for that member. A missing
   * value keeps the default (30 minutes; Isha until 11 pm).
   */
  grace?: PrayerGrace;
}

export type PrayerGrace = Record<string, Partial<Record<PrayerKey, number>>>;

/** Grace minutes the admin can pick (the window still closes at the next prayer). */
export const GRACE_MIN = 5;
export const GRACE_MAX = 240;

/** A member's grace for `key`: their own, else the family's, else undefined (the default rule). */
export function graceFor(s: Pick<PrayerSettings, "grace"> | undefined, personId: string, key: PrayerKey): number | undefined {
  return s?.grace?.[personId]?.[key] ?? s?.grace?.all?.[key];
}

const RIYADH_OFFSET_MS = 3 * 3600 * 1000;
const DAY = 86400e3;

/** Prayer times (epoch ms) on the Riyadh calendar day that contains `ms`. */
export function prayerTimes(lat: number, lng: number, ms: number): Record<PrayerKey, number> {
  const d = new Date(ms + RIYADH_OFFSET_MS);
  // adhan reads the local calendar fields of the date it is given.
  const day = new Date(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate());
  const t = new PrayerTimes(new Coordinates(lat, lng), day, CalculationMethod.UmmAlQura());
  return { fajr: t.fajr.getTime(), dhuhr: t.dhuhr.getTime(), asr: t.asr.getTime(), maghrib: t.maghrib.getTime(), isha: t.isha.getTime() };
}

/** Half an hour after its adhan a prayer is late: still a task, but worth no points. */
export const PRAYER_GRACE_MS = 30 * 60e3;

/** Isha keeps its points until this Riyadh hour (owner's decision, Oct 2026). */
export const ISHA_UNTIL_HOUR = 23;

/**
 * When a prayer that started at `start` becomes late (mirrored in app/lib/core/models.dart lateFrom).
 * `minutes` is the admin's grace for this member and prayer; without it, the default rule.
 */
export function lateAfter(w: { key?: PrayerKey; start: number }, minutes?: number): number {
  if (minutes !== undefined) return w.start + minutes * 60e3;
  const grace = w.start + PRAYER_GRACE_MS;
  if (w.key !== "isha") return grace;
  const d = new Date(w.start + RIYADH_OFFSET_MS);
  const until = Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate(), ISHA_UNTIL_HOUR) - RIYADH_OFFSET_MS;
  return Math.max(grace, until);
}

/** Points a prayer earns when marked done at `ms` (none once it is late). */
export const prayerPoints = (w: { key?: PrayerKey; start: number }, points: number, ms: number, minutes?: number) =>
  ms > lateAfter(w, minutes) ? 0 : points;

export interface PrayerWindow {
  key: PrayerKey;
  start: number;
  /** When the next prayer's time comes in: the window closes and its points are gone. */
  end: number;
  /** Riyadh day of the prayer, used as the completion period. */
  dayKey: string;
}

/** The prayer whose time is running at `ms` (from its adhan until the next one). */
export function currentPrayer(lat: number, lng: number, ms: number): PrayerWindow {
  const events: { key: PrayerKey; at: number }[] = [];
  for (const off of [-DAY, 0, DAY]) {
    const t = prayerTimes(lat, lng, ms + off);
    for (const k of PRAYERS) events.push({ key: k, at: t[k] });
  }
  events.sort((a, b) => a.at - b.at);
  let i = events.length - 2;
  while (i > 0 && events[i].at > ms) i--;
  const e = events[i];
  return { key: e.key, start: e.at, end: events[i + 1].at, dayKey: dayKey(e.at) };
}

/** Synthetic task id of a member's prayer: "prayer-<key>-<personId>". */
export const prayerTaskId = (key: PrayerKey, personId: string) => `prayer-${key}-${personId}`;

export function parsePrayerTaskId(id: string): { key: PrayerKey; personId: string } | null {
  const m = /^prayer-(fajr|dhuhr|asr|maghrib|isha)-([\w-]+)$/.exec(id);
  return m ? { key: m[1] as PrayerKey, personId: m[2] } : null;
}
