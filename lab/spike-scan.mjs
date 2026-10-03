// انفجار السيولة — المسح الليلي: بعد إغلاق السوق الأمريكي، إشارات آخر يوم تداول للسوق كامل
// من lab/data/daily (spike-fetch.mjs) → lab/results/spikes-today.json (التطبيق يقرأه من GitHub بدون مفتاح).
// نفس scanSpikes و spikeCard اللي يستخدمها التطبيق للحساب المحلي.
import { writeFile, mkdir } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { SPIKE_DEFAULTS, marketDays, latestMarketDayIdx, scanSpikes, spikeCard, isoDay } from '../server/spike.js';
import { loadDaily } from './spike-backtest.mjs';

const HERE = path.dirname(fileURLToPath(import.meta.url));
const RESULTS = path.join(HERE, 'results');

// { generatedAt, day, source, universe, scanned, params, signals: [spikeCard…] }
export function buildSpikesToday({ barsBySym, names = {}, exchanges = {}, commonStocks = null, source = null, p = SPIKE_DEFAULTS, now = new Date() }) {
  const days = marketDays(barsBySym), di = latestMarketDayIdx(barsBySym, days);
  if (di < 0) return null;
  const t = days[di];
  let scanned = 0;
  for (const b of barsBySym.values()) if (b.t.includes(t)) scanned++;
  const sigs = scanSpikes(barsBySym, di, p, { days, commonStocks });
  return {
    generatedAt: now.toISOString(), day: isoDay(t), source, universe: barsBySym.size, scanned,
    params: { entry: p.entry, hold: p.hold, stop: p.stop, volMult: p.volMult, minChange: p.minChange, minPrice: p.minPrice, maxPrice: p.maxPrice },
    signals: sigs.map(s => spikeCard(s.sym, barsBySym.get(s.sym), s, { name: names[s.sym] || null, exchange: exchanges[s.sym] || null, p })),
  };
}

async function main() {
  const { meta, universe, barsBySym, names } = await loadDaily();
  if (!barsBySym.size) { console.log('ما فيه بيانات يومية — شغّل node lab/spike-fetch.mjs أولًا. تخطّي.'); return; }
  const commonStocks = universe && Array.isArray(universe.symbols) && meta.source === 'yahoo' ? new Set(universe.symbols) : null;
  const exchanges = {};
  if (universe && universe.info) for (const [s, x] of Object.entries(universe.info)) if (x && x.exchange) exchanges[s] = x.exchange;
  const out = buildSpikesToday({ barsBySym, names, exchanges, commonStocks, source: meta.source || null });
  if (!out) { console.log('ما فيه أيام سوق في البيانات. تخطّي.'); return; }
  await mkdir(RESULTS, { recursive: true });
  await writeFile(path.join(RESULTS, 'spikes-today.json'), JSON.stringify(out) + '\n');
  console.log(`يوم ${out.day}: ${out.signals.length} إشارة من ${out.scanned} سهم تداول ذاك اليوم${out.signals.length ? ' — ' + out.signals.map(s => `${s.sym} (+${s.chgPct}% ×${s.volMult})`).join('، ') : ''}`);
  console.log('→ lab/results/spikes-today.json');
}

if (process.argv[1] && import.meta.url === pathToFileURL(path.resolve(process.argv[1])).href) {
  main().catch(e => { console.error(e); process.exit(1); });
}
