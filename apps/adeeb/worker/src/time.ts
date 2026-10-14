const DAY_MS = 86_400_000;

/** اليوم بتوقيت UTC بصيغة YYYY-MM-DD (تتجدد الحصة 00:00 UTC، ARCHITECTURE §8.3). */
export function utcDay(nowMs: number): string {
  return new Date(nowMs).toISOString().slice(0, 10);
}

/** بداية اليوم التالي بتوقيت UTC (بالملّي ثانية). */
export function nextUtcMidnight(nowMs: number): number {
  return Math.floor(nowMs / DAY_MS) * DAY_MS + DAY_MS;
}

const pacific = new Intl.DateTimeFormat("en-US", {
  timeZone: "America/Los_Angeles",
  hourCycle: "h23",
  year: "numeric",
  month: "2-digit",
  day: "2-digit",
  hour: "2-digit",
  minute: "2-digit",
  second: "2-digit",
});

/** فرق توقيت المحيط الهادئ عن UTC عند لحظة معيّنة (سالب). */
function pacificOffsetMs(ms: number): number {
  const p: Record<string, number> = {};
  for (const part of pacific.formatToParts(new Date(ms))) {
    if (part.type !== "literal") p[part.type] = Number(part.value);
  }
  const asUtc = Date.UTC(p.year, p.month - 1, p.day, p.hour, p.minute, p.second);
  return Math.round((asUtc - Math.floor(ms / 1000) * 1000) / 60_000) * 60_000;
}

/** منتصف الليل التالي بتوقيت المحيط الهادئ (موعد تجدد حصة Gemini اليومية). */
export function nextPacificMidnight(nowMs: number): number {
  const localNow = nowMs + pacificOffsetMs(nowMs);
  const localNextMidnight = Math.floor(localNow / DAY_MS) * DAY_MS + DAY_MS;
  const guess = localNextMidnight - pacificOffsetMs(nowMs);
  // تصحيح عند تغيّر التوقيت الصيفي بين الآن ومنتصف الليل.
  return localNextMidnight - pacificOffsetMs(guess);
}
