import { test } from 'node:test';
import assert from 'node:assert/strict';
import vm from 'node:vm';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const dir = path.join(path.dirname(fileURLToPath(import.meta.url)), '../web/js');
function load() {
  const ctx = { TextEncoder, TextDecoder, btoa, atob, console };
  ctx.window = ctx; vm.createContext(ctx);
  for (const f of ['core.js', 'bank-3p.js', 'bank-6p.js', 'bank-9m.js']) vm.runInContext(fs.readFileSync(path.join(dir, f), 'utf8'), ctx, { filename: f });
  return ctx.M;
}
const M = load();
const same = (a, b) => assert.equal(JSON.stringify(a), JSON.stringify(b));

test('البنك: 9 مجموعات × 12 سؤالاً', () => {
  assert.equal(M.QUESTIONS.length, 108);
  for (const g of Object.keys(M.GRADES)) for (const s of Object.keys(M.SUBJECTS))
    assert.equal(M.QUESTIONS.filter((q) => q.g === g && q.s === s).length, 12, g + s);
});
test('البنك: سلامة كل سؤال', () => {
  const ids = new Set();
  for (const q of M.QUESTIONS) {
    assert.ok(!ids.has(q.id)); ids.add(q.id);
    assert.equal(q.o.length, 4, q.id);
    assert.equal(new Set(q.o).size, 4, 'خيارات مكررة ' + q.id);
    assert.ok(q.a >= 0 && q.a < 4);
    assert.ok(M.SKILLS[q.s][q.skill], 'مهارة غير معروفة ' + q.id);
    assert.ok([1, 2, 3].includes(q.lvl));
    if (q.passage) assert.ok(M.PASSAGES[q.passage] && M.PASSAGES[q.passage].g === q.g, q.id);
  }
});
test('البنك: توزيع موضع الإجابة الصحيحة متوازن', () => {
  const c = [0, 0, 0, 0];
  M.QUESTIONS.forEach((q) => c[q.a]++);
  c.forEach((n) => assert.ok(n >= 15, 'توزيع مائل: ' + c));
});
test('ثبات ترتيب الخيارات', () => {
  const again = load();
  same(again.QUESTIONS.map((q) => q.a), M.QUESTIONS.map((q) => q.a));
});
test('التصحيح', () => {
  const ids = M.QUESTIONS.filter((q) => q.g === '6p' && q.s === 'math').slice(0, 4).map((q) => q.id);
  const ans = ids.map((id, i) => (i < 3 ? M.QMAP[id].a : (M.QMAP[id].a + 1) % 4));
  const r = M.score(ids, ans);
  assert.equal(r.correct, 3); assert.equal(r.pct, 75); assert.equal(r.wrong.length, 1);
  assert.equal(M.score(ids, [null, null, null, null]).blank, 4);
});
test('التشفير ذهاباً وإياباً (عربي)', () => {
  const code = M.resultCode({ id: 'abc' }, 'أحمد محمد', [0, null, 3, 1], 125);
  const o = M.parseResultCode('رمزي: ' + code);
  assert.equal(o.n, 'أحمد محمد'); same(M.strToAns(o.a, 4), [0, null, 3, 1]);
  assert.throws(() => M.parseResultCode('xxx'));
});
test('إدخال الإجابات الورقية', () => {
  same(M.parsePaper('أبجد-', 6), [0, 1, 2, 3, null, null]);
  same(M.parsePaper('a b c d', 4), [0, 1, 2, 3]);
  same(M.parsePaper('1234', 2), [0, 1]);
});
test('مطابقة الأسماء', () => {
  const st = [{ id: 1, name: 'أحمد محمد العتيبي' }, { id: 2, name: 'خالد سعد' }];
  assert.equal(M.matchStudent('احمد محمد العتيبى', st).id, 1);
  assert.equal(M.matchStudent('خالد', st).id, 2);
  assert.equal(M.matchStudent('سارة', st), null);
});
test('الاختيار العشوائي: العدد والتوازن وترتيب النصوص', () => {
  const ids = M.pick({ g: '9m', s: 'ar', skills: [], n: 12 });
  assert.equal(ids.length, 12); assert.equal(new Set(ids).size, 12);
  const firstPassage = ids.findIndex((i) => M.QMAP[i].passage);
  assert.ok(ids.slice(firstPassage).every((i) => M.QMAP[i].passage));
  assert.equal(M.pick({ g: '3p', s: 'math', skills: ['geo'], n: 99 }).length, 3);
});
test('إحصاء الفصل', () => {
  const ids = M.pick({ g: '3p', s: 'math', skills: [], n: 10 });
  const perfect = ids.map((i) => M.QMAP[i].a), none = ids.map(() => null);
  const st = M.classStats({ qids: ids }, [{ answers: perfect }, { answers: none }]);
  assert.equal(st.avg, 50); assert.equal(st.max, 100); assert.equal(st.min, 0);
  assert.equal(st.items[0].pct, 50); assert.equal(st.dist[0], 1); assert.equal(st.dist[3], 1);
});
