import { describe, expect, it } from "vitest";
import { nextPacificMidnight, nextUtcMidnight, utcDay } from "../src/time";

describe("time", () => {
  it("اليوم وتجدده بتوقيت UTC", () => {
    const t = Date.UTC(2026, 9, 12, 23, 59, 59);
    expect(utcDay(t)).toBe("2026-10-12");
    expect(nextUtcMidnight(t)).toBe(Date.UTC(2026, 9, 13));
    expect(utcDay(Date.UTC(2026, 9, 13))).toBe("2026-10-13");
  });

  it("منتصف الليل بتوقيت المحيط الهادئ (صيفي PDT = UTC-7)", () => {
    // 2026-10-12 15:00 UTC = 08:00 PDT ← منتصف ليل 10-13 PDT = 07:00 UTC
    expect(nextPacificMidnight(Date.UTC(2026, 9, 12, 15))).toBe(Date.UTC(2026, 9, 13, 7));
    // 2026-10-13 06:30 UTC = 23:30 PDT من يوم 10-12
    expect(nextPacificMidnight(Date.UTC(2026, 9, 13, 6, 30))).toBe(Date.UTC(2026, 9, 13, 7));
  });

  it("منتصف الليل بتوقيت المحيط الهادئ (شتوي PST = UTC-8)", () => {
    expect(nextPacificMidnight(Date.UTC(2026, 11, 1, 12))).toBe(Date.UTC(2026, 11, 2, 8));
  });

  it("عبر تغيير التوقيت (نهاية الصيفي 2026-11-01)", () => {
    // 2026-10-31 20:00 UTC = 13:00 PDT ← منتصف ليل 11-01 ما زال PDT = 07:00 UTC
    expect(nextPacificMidnight(Date.UTC(2026, 9, 31, 20))).toBe(Date.UTC(2026, 10, 1, 7));
    // 2026-11-01 12:00 UTC = 04:00 PST ← منتصف ليل 11-02 PST = 08:00 UTC
    expect(nextPacificMidnight(Date.UTC(2026, 10, 1, 12))).toBe(Date.UTC(2026, 10, 2, 8));
  });
});
