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

/** Half an hour after its adhan a prayer task closes: it disappears (Isha: see ISHA_UNTIL_HOUR). */
export const PRAYER_GRACE_MS = 30 * 60e3;

/** Isha stays open until this Riyadh hour (owner's decision, Oct 2026). */
export const ISHA_UNTIL_HOUR = 23;

/** When the prayer that started at `start` closes (mirrored in app/lib/core/models.dart lateFrom). */
export function lateAfter(w: { key?: PrayerKey; start: number }): number {
  const grace = w.start + PRAYER_GRACE_MS;
  if (w.key !== "isha") return grace;
  const d = new Date(w.start + RIYADH_OFFSET_MS);
  const until = Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate(), ISHA_UNTIL_HOUR) - RIYADH_OFFSET_MS;
  return Math.max(grace, until);
}

/** A prayer task exists only while it is open: from its adhan until half an hour later (Isha: until 11 pm). */
export const prayerOpen = (w: { key?: PrayerKey; start: number }, ms: number) => ms >= w.start && ms <= lateAfter(w);

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
