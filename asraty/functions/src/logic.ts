// Pure domain logic shared by the callable functions. No Firebase imports here,
// so it can be unit-tested directly. Mirrors the reference logic in
// design/prototype.html (pk/dk/wk, tierOf, ranking, reportText, compDone).

export type Period = "daily" | "weekly";
export type Scope = "each" | "family";
export type Role = "owner" | "admin" | "member";

export const PERM_KEYS = ["addMembers", "approve", "tasks", "report", "comps", "viewReports"] as const;
export type PermKey = (typeof PERM_KEYS)[number];
export type Perms = Partial<Record<PermKey, boolean>>;

export const AVATAR_KEYS = [
  "dad", "dad2", "grandpa", "mom", "mom2", "grandma",
  "teen", "boy", "boy2", "girl", "girl2", "baby",
] as const;

export const REWARD_EMOJI = ["🏞️", "🍔", "🎮", "🍦", "🎡", "🎁", "📚", "🏖️"];

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

export function periodKey(period: Period, ms: number): string {
  return period === "daily" ? dayKey(ms) : weekKey(ms);
}

export function can(person: { role: Role; perms?: Perms } | undefined, perm: PermKey): boolean {
  if (!person) return false;
  if (person.role === "owner") return true;
  return person.role === "admin" && !!person.perms?.[perm];
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
}

/** Highest tier whose threshold is reached, within the same period and scope. */
export function tierOf(tiers: Tier[], pts: number, period: Period, scope: Scope): Tier | undefined {
  return tiers
    .filter((t) => t.period === period && t.scope === scope && pts >= t.threshold)
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

/** Daily ranking report text (same format as the app preview). */
export function reportText(rows: RankRow[], ms: number): string {
  if (!rows.length) return "لا يوجد أعضاء بعد.";
  const sorted = [...rows].sort((a, b) => b.points - a.points);
  const total = sorted.reduce((a, r) => a + r.points, 0);
  return (
    `ترتيب إنجاز اليوم — ${arabicDate(ms)}\n\n` +
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
