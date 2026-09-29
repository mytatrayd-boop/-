import { test } from "node:test";
import assert from "node:assert/strict";
import { can, competitionPoints, dayKey, periodKey, reportText, tierOf, weekKey, cleanPerms, Tier } from "../src/logic";

const riyadh = (iso: string) => Date.parse(iso + "+03:00");

test("dayKey uses Riyadh time", () => {
  assert.equal(dayKey(riyadh("2026-09-29T23:30:00")), "2026-09-29");
  assert.equal(dayKey(riyadh("2026-09-30T00:10:00")), "2026-09-30");
  // 22:00 UTC is already the next day in Riyadh
  assert.equal(dayKey(Date.parse("2026-09-29T22:00:00Z")), "2026-09-30");
});

test("weekKey starts on Sunday", () => {
  // 2026-09-27 is a Sunday
  assert.equal(weekKey(riyadh("2026-09-27T00:00:00")), "w2026-09-27");
  assert.equal(weekKey(riyadh("2026-09-29T12:00:00")), "w2026-09-27");
  assert.equal(weekKey(riyadh("2026-10-03T23:59:00")), "w2026-09-27");
  assert.equal(weekKey(riyadh("2026-10-04T00:00:00")), "w2026-10-04");
  // month / year boundaries
  assert.equal(weekKey(riyadh("2027-01-01T10:00:00")), "w2026-12-27");
  assert.equal(periodKey("daily", riyadh("2027-01-01T10:00:00")), "2027-01-01");
});

test("competition points decrease by one with a floor of 1", () => {
  assert.deepEqual([1, 2, 3].map((r) => competitionPoints(20, r)), [20, 19, 18]);
  assert.equal(competitionPoints(3, 10), 1);
});

test("tierOf picks the highest reached tier in the same period and scope", () => {
  const tiers: Tier[] = [
    { id: "a", name: "نزهة عائلية", emoji: "🏞️", threshold: 66, period: "weekly", scope: "each" },
    { id: "b", name: "وجبة خارجية", emoji: "🍔", threshold: 30, period: "weekly", scope: "each" },
    { id: "c", name: "ساعة ألعاب", emoji: "🎮", threshold: 15, period: "daily", scope: "each" },
  ];
  assert.equal(tierOf(tiers, 66, "weekly", "each")?.id, "a");
  assert.equal(tierOf(tiers, 40, "weekly", "each")?.id, "b");
  assert.equal(tierOf(tiers, 29, "weekly", "each"), undefined);
  assert.equal(tierOf(tiers, 100, "weekly", "family"), undefined);
});

test("permissions", () => {
  assert.ok(can({ role: "owner" }, "approve"));
  assert.ok(can({ role: "admin", perms: { approve: true } }, "approve"));
  assert.ok(!can({ role: "admin", perms: { tasks: true } }, "approve"));
  assert.ok(!can({ role: "member", perms: { approve: true } }, "approve"));
  assert.deepEqual(cleanPerms({ approve: true, evil: true, tasks: "yes" }), {
    addMembers: false, approve: true, tasks: false, report: false, comps: false, viewReports: false,
  });
});

test("reportText ranks members", () => {
  const t = reportText([{ name: "أصيل", points: 15, count: 2 }, { name: "لمى", points: 20, count: 1 }], riyadh("2026-09-29T12:00:00"));
  assert.match(t, /الثلاثاء، 29 سبتمبر/);
  assert.ok(t.indexOf("🥇 لمى") < t.indexOf("🥈 أصيل"));
  assert.match(t, /مجموع الأسرة: 35 نقطة/);
});
