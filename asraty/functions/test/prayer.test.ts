import { test } from "node:test";
import assert from "node:assert/strict";
import { graceFor, lateAfter, prayerPoints } from "../src/prayer";

const riyadh = (iso: string) => Date.parse(iso + "+03:00");

test("مهلة أداء الصلاة: بلا قيمة يبقى الافتراضي (٣٠ دقيقة، والعشاء حتى ١١ م)", () => {
  const dhuhr = { key: "dhuhr" as const, start: riyadh("2026-11-11T11:56:00") };
  assert.equal(lateAfter(dhuhr), dhuhr.start + 30 * 60e3);
  const isha = { key: "isha" as const, start: riyadh("2026-11-11T19:05:00") };
  assert.equal(lateAfter(isha), riyadh("2026-11-11T23:00:00"));
});

test("مهلة أداء الصلاة: الدقائق المعدّة تحدد انتهاء النقاط، حتى للعشاء", () => {
  const isha = { key: "isha" as const, start: riyadh("2026-11-11T19:05:00") };
  assert.equal(lateAfter(isha, 45), isha.start + 45 * 60e3);
  assert.equal(prayerPoints(isha, 5, isha.start + 44 * 60e3, 45), 5);
  assert.equal(prayerPoints(isha, 5, isha.start + 46 * 60e3, 45), 0);
});

test("مهلة الفرد تتقدم على مهلة الجميع، وبلا الاثنين undefined", () => {
  const s = { grace: { all: { fajr: 60, asr: 20 }, kid1: { fajr: 90 } } };
  assert.equal(graceFor(s, "kid1", "fajr"), 90);
  assert.equal(graceFor(s, "kid1", "asr"), 20);
  assert.equal(graceFor(s, "kid2", "fajr"), 60);
  assert.equal(graceFor(s, "kid2", "isha"), undefined);
  assert.equal(graceFor(undefined, "kid2", "isha"), undefined);
});
