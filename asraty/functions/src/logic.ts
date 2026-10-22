// Pure domain logic shared by the callable functions. No Firebase imports here,
// so it can be unit-tested directly. Mirrors the reference logic in
// design/prototype.html (pk/dk/wk, tierOf, ranking, reportText, compDone).

export type Period = "daily" | "weekly";
/** Report / prize periods (day and week, plus month and year). */
export type Span = "daily" | "weekly" | "monthly" | "yearly";
export const SPANS: readonly Span[] = ["daily", "weekly", "monthly", "yearly"];
/** How a task repeats: every day, week, month or year, or once only. */
export type TaskRepeat = Span | "once";
export type Scope = "each" | "family";
export type Role = "owner" | "admin" | "member";

export const PERM_KEYS = ["addMembers", "approve", "tasks", "report", "comps", "viewReports"] as const;
export type PermKey = (typeof PERM_KEYS)[number];
export type Perms = Partial<Record<PermKey, boolean>>;

/** Portrait avatars (app/assets/avatars), then the older cartoon ones kept for existing accounts. */
export const AVATAR_KEYS = [
  "dad_shemagh", "dad_bisht", "grandpa", "grandpa2", "grandpa3", "mom_black", "mom_brown", "mom_green",
  "mom_purple", "woman_black", "grandma", "teen_shemagh", "teen_shemagh2", "teen_ghutra", "teen_ghutra2", "teen_hijab",
  "teen_brown", "teen_black", "girl_rose", "boy_shemagh", "boy_ghutra", "boy_kuma", "girl_curly", "girl_pink",
  "dad", "dad2", "mom", "mom2", "teen", "boy", "boy2", "girl", "girl2", "baby",
] as const;

/** Avatar value of a member who uploaded their own photo (stored in people/{id}.photo). */
export const PHOTO_AVATAR = "photo";

export const REWARD_EMOJI = ["🎁", "🏆", "🏞️", "🍔", "🎮", "🍦", "🎡", "📚", "🏖️", "💵", "🚲", "📱"];

// Asia/Riyadh is UTC+3 all year (no DST), so a fixed offset is exact.
const RIYADH_OFFSET_MS = 3 * 3600 * 1000;

const pad = (n: number) => String(n).padStart(2, "0");

/** Riyadh calendar date of `ms` as YYYY-MM-DD. */
export function dayKey(ms: number): string {
  const d = new Date(ms + RIYADH_OFFSET_MS);
  return `${d.getUTCFullYear()}-${pad(d.getUTCMonth() + 1)}-${pad(d.getUTCDate())}`;
}

/** Week key: "w" + the Riyadh date of the Sunday that starts the week. */
export function weekKey(ms: number): string {
  const d = new Date(ms + RIYADH_OFFSET_MS);
  const sunday = Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate() - d.getUTCDay());
  return "w" + dayKey(sunday - RIYADH_OFFSET_MS);
}

/** Month key for the honor board: "m" + Riyadh YYYY-MM. */
export function monthKey(ms: number): string {
  return "m" + dayKey(ms).slice(0, 7);
}

/** Year key for the honor board: "y" + Riyadh year. */
export function yearKey(ms: number): string {
  return "y" + dayKey(ms).slice(0, 4);
}

export function periodKey(period: TaskRepeat, ms: number): string {
  // A one-time task has a single period: done once, it stays done.
  if (period === "once") return "once";
  return { daily: dayKey, weekly: weekKey, monthly: monthKey, yearly: yearKey }[period](ms);
}

export function can(person: { role: Role; perms?: Perms } | undefined, perm: PermKey): boolean {
  if (!person) return false;
  if (person.role === "owner") return true;
  return person.role === "admin" && !!person.perms?.[perm];
}

/**
 * Who gets a push for a family notice: everyone it is addressed to ("all" or one
 * person), delegated admins included, except whoever sent it.
 */
export function noticeTargets<P extends { id: string }>(people: P[], to: string, senderId: string): P[] {
  return people.filter((p) => p.id !== senderId && (to === "all" || p.id === to));
}

/** Points for the n-th finisher (1-based) of a competition. */
export function competitionPoints(startPoints: number, rank: number): number {
  return Math.max(startPoints - (rank - 1), 1);
}

export interface Tier {
  id: string;
  name: string;
  emoji: string;
  threshold: number;
  period: Period;
  scope: Scope;
  /** Private reward: only this member can earn (and see) it. */
  personId?: string | null;
}

/** Highest tier whose threshold is reached, within the same period and scope (and person, for private rewards). */
export function tierOf(tiers: Tier[], pts: number, period: Period, scope: Scope, personId?: string): Tier | undefined {
  return tiers
    .filter((t) => t.period === period && t.scope === scope && pts >= t.threshold && (!t.personId || t.personId === personId))
    .sort((a, b) => b.threshold - a.threshold)[0];
}

export interface RankRow {
  name: string;
  points: number;
  count: number;
}

export const medal = (i: number): string => ["🥇", "🥈", "🥉"][i] ?? String(i + 1);

const AR_WEEKDAYS = ["الأحد", "الاثنين", "الثلاثاء", "الأربعاء", "الخميس", "الجمعة", "السبت"];
const AR_MONTHS = [
  "يناير", "فبراير", "مارس", "أبريل", "مايو", "يونيو",
  "يوليو", "أغسطس", "سبتمبر", "أكتوبر", "نوفمبر", "ديسمبر",
];

export function arabicDate(ms: number): string {
  const d = new Date(ms + RIYADH_OFFSET_MS);
  return `${AR_WEEKDAYS[d.getUTCDay()]}، ${d.getUTCDate()} ${AR_MONTHS[d.getUTCMonth()]}`;
}

export type ReportPeriod = Span;

/** Title of a ranking report for its period. */
export const REPORT_TITLE: Record<ReportPeriod, string> = {
  daily: "ترتيب إنجاز اليوم",
  weekly: "ترتيب إنجاز الأسبوع",
  monthly: "ترتيب إنجاز الشهر",
  yearly: "ترتيب إنجاز السنة",
};

/** Summary key a report period reads (the same keys addPoints writes). */
export function reportKey(period: ReportPeriod, ms: number): string {
  return { daily: dayKey, weekly: weekKey, monthly: monthKey, yearly: yearKey }[period](ms);
}

/** Ranking report text (same format as the app preview). */
export function reportText(rows: RankRow[], ms: number, period: ReportPeriod = "daily"): string {
  if (!rows.length) return "لا يوجد أعضاء بعد.";
  const sorted = [...rows].sort((a, b) => b.points - a.points);
  const total = sorted.reduce((a, r) => a + r.points, 0);
  return (
    `${REPORT_TITLE[period]} — ${arabicDate(ms)}\n\n` +
    sorted.map((r, i) => `${medal(i)} ${r.name}: ${r.points} نقطة (${r.count} إنجاز)`).join("\n") +
    `\n\nمجموع الأسرة: ${total} نقطة`
  );
}

export const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

export function normalizeEmail(v: unknown): string {
  return String(v ?? "").trim().toLowerCase();
}

export function cleanText(v: unknown, max: number): string {
  return String(v ?? "").trim().slice(0, max);
}

export function cleanPerms(v: unknown): Record<PermKey, boolean> {
  const src = (v && typeof v === "object" ? v : {}) as Record<string, unknown>;
  const out = {} as Record<PermKey, boolean>;
  for (const k of PERM_KEYS) out[k] = src[k] === true;
  return out;
}

/** Android notification channel created by the app (heads-up + sound). Keep in sync with app/lib/backend/push.dart. */
export const PUSH_CHANNEL = "asraty_alerts";

/**
 * FCM message body for a WhatsApp-style alert: a pop-up banner with the default
 * sound on Android (high-importance channel, high priority) and iOS (sound + banner).
 */
export function pushPayload(title: string, body: string, familyId: string) {
  const text = body.length > 180 ? body.slice(0, 177) + "…" : body;
  return {
    notification: { title, body: text },
    data: { familyId },
    android: {
      priority: "high" as const,
      notification: { channelId: PUSH_CHANNEL, sound: "default", priority: "max" as const, defaultVibrateTimings: true, icon: "ic_notification", color: "#2F6158" },
    },
    apns: {
      headers: { "apns-priority": "10", "apns-push-type": "alert" },
      payload: { aps: { sound: "default", "interruption-level": "active" as const } },
    },
  };
}
