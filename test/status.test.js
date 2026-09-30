import { test } from 'node:test';
import assert from 'node:assert/strict';
import { statusLights } from '../server/status.js';

const now = Date.UTC(2026, 8, 30, 12); // الثلاثاء
const light = (st, key) => st.lights.find(l => l.key === key);

test('no keys → red demo badge, and a lookalike variable name is named in the fix', () => {
  const st = statusLights({ massiveKey: false, alphaKey: false, lookalikes: ['"massive_api_key"'], now });
  assert.equal(st.level, 'red');
  assert.equal(st.badge, 'تجريبي');
  assert.match(light(st, 'prices').fix, /massive_api_key.*MASSIVE_API_KEY/);
});

test('Massive key while backfilling → yellow with progress; sync error before ready → red', () => {
  const filling = statusLights({ massiveKey: true, alphaKey: true, persistentData: true, market: { ready: false, days: 12, progress: { date: '2026-08-01' } }, now });
  assert.equal(filling.level, 'yellow');
  assert.equal(filling.badge, 'يتجهز 12/60');
  const broken = statusLights({ massiveKey: true, alphaKey: true, persistentData: true, market: { ready: false, days: 0, error: 'Massive: المفتاح غير صالح' }, now });
  assert.equal(broken.level, 'red');
  assert.equal(broken.badge, 'المزامنة متوقفة');
  assert.match(light(broken, 'sync').fix, /غير صالح/);
});

test('ready and fresh → green; stale last day → yellow; missing volume and news stay out of the badge level', () => {
  const ok = statusLights({ massiveKey: true, alphaKey: false, persistentData: false, market: { ready: true, days: 60, lastDay: '2026-09-29' }, now });
  assert.equal(ok.level, 'green');
  assert.equal(ok.badge, 'حقيقي · 2026-09-29');
  assert.equal(light(ok, 'news').level, 'yellow');
  assert.equal(light(ok, 'storage').level, 'yellow');
  const stale = statusLights({ massiveKey: true, alphaKey: true, persistentData: true, market: { ready: true, days: 60, lastDay: '2026-09-21' }, now });
  assert.equal(stale.level, 'yellow');
});

test('Alpha Vantage only → yellow real prices for the list', () => {
  const st = statusLights({ massiveKey: false, alphaKey: true, now });
  assert.equal(st.level, 'yellow');
  assert.equal(st.badge, 'حقيقي · قائمتي');
});
