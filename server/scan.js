// تنسيق المسح: أسعار → بوابة السيولة + RSI → أخبار (بوابة لينة + تعزيز) → تنبيه أرباح → ترتيب.
// لا يعتمد على Node: الخادم يمرّر مزوّد Alpha Vantage، والنسخة المستقلة (بدون خادم) تمرّر المزوّد التجريبي.
import { scoreTicker, buildTrade, rankResults, applyYaqeen, newsEffect, sentimentLabel, upcomingEarnings, NEWS_DEFAULTS } from './engine.js';

export const MAX_TICKERS = 25;
const CHART_BARS = 60;
const EARNINGS_HORIZON_DAYS = 7; // أفق الصفقة أسبوع
const FATAL = new Set(['rate_limited']);
const num = (v, def, min, max) => { const x = Number(v); return Number.isFinite(x) ? Math.min(max, Math.max(min, x)) : def; };

// providers: { demo, bars(sym) → {bars, cached}, news(sym, newsP) → {news}, earnings(syms) → {calendar} }
export async function runScan(body, providers) {
  const tickers = [...new Set((Array.isArray(body.tickers) ? body.tickers : [])
    .map(s => String(s).trim().toUpperCase()).filter(s => /^[A-Z][A-Z0-9.\-]{0,9}$/.test(s)))];
  if (tickers.length === 0) return { status: 400, body: { error: 'القائمة فاضية.' } };
  if (tickers.length > MAX_TICKERS) return { status: 400, body: { error: `الحد الأقصى ${MAX_TICKERS} سهم لكل مسح.` } };

  const p = { volAvgDays: num(body.volAvgDays, 20, 5, 60), volMult: num(body.volMult, 1.5, 0.5, 10) };
  const tradeP = { slAtr: num(body.slAtr, 1.5, 0.2, 10), rr: num(body.rr, 1.5, 0.2, 10) };
  const yaqeen = body.yaqeen && typeof body.yaqeen === 'object' ? body.yaqeen : {};
  const { kept, excluded } = applyYaqeen(tickers, yaqeen, { excludeHaram: body.excludeHaram !== false, excludeMashbooh: !!body.excludeMashbooh });
  const newsP = {
    newsDays: num(body.newsDays, NEWS_DEFAULTS.newsDays, 1, 7), minRelevance: NEWS_DEFAULTS.minRelevance,
    newsBoost: num(body.newsBoost, NEWS_DEFAULTS.newsBoost, 0, 1), newsGate: num(body.newsGate, NEWS_DEFAULTS.newsGate, 0.15, 1),
    newsMax: Math.round(num(body.newsMax, 5, 0, MAX_TICKERS)),
  };
  const demo = !!providers.demo;

  // 1) الأسعار + بوابة السيولة + RSI
  const perTicker = {};
  let fatal = null;
  for (const sym of kept) {
    try {
      const { bars, cached } = await providers.bars(sym);
      const s = scoreTicker(bars, p);
      perTicker[sym] = { ok: true, bars, cached, yaqeen: yaqeen[sym] || 'غير معروف', ...s, baseScore: s.score, news: { status: 'skipped' } };
    } catch (err) {
      perTicker[sym] = { ok: false, error: err.message || 'خطأ غير معروف' };
      if (err && FATAL.has(err.code)) { fatal = err.message; break; }
    }
  }

  // 2) الأخبار — فقط لمن اجتاز بوابة السيولة (غيرهم نتيجته صفر أصلاً)، وبحد أقصى newsMax طلب لحماية الحصة.
  const gatePassed = Object.entries(perTicker).filter(([, d]) => d.ok && d.passesGate).sort((a, b) => b[1].baseScore - a[1].baseScore);
  let newsFatal = fatal;
  gatePassed.forEach(([sym, d], i) => {
    if (i >= newsP.newsMax) d.news = { status: 'capped' };
  });
  for (const [sym, d] of gatePassed.slice(0, newsP.newsMax)) {
    if (newsFatal) { d.news = { status: 'error', error: newsFatal }; continue; }
    try {
      const { news } = await providers.news(sym, newsP);
      const eff = newsEffect(news, d.direction, newsP);
      d.news = { status: 'ok', count: news.count, sentiment: news.sentiment, label: news.count ? sentimentLabel(news.sentiment) : 'لا يوجد خبر', articles: news.articles, ...eff };
      d.newsGated = eff.gated;
      d.score = eff.gated ? 0 : d.baseScore * eff.multiplier;
    } catch (err) {
      // فشل الأخبار لا يوقف المسح: السهم يبقى بنتيجته الأساسية ويُعلن أن الخبر لم يُفحص.
      d.news = { status: 'error', error: err.message || 'خطأ غير معروف' };
      if (err && FATAL.has(err.code)) newsFatal = err.message;
    }
  }

  // 3) تقويم الأرباح — طلب واحد للسوق كله، تنبيه مخاطرة فقط لا يغيّر النتيجة.
  let earningsError = null, calendar = null;
  if (gatePassed.length) {
    if (newsFatal && !demo) earningsError = newsFatal;
    else {
      try { calendar = (await providers.earnings(kept)).calendar; }
      catch (err) { earningsError = err.message || 'خطأ غير معروف'; }
    }
  }
  const earningsFor = d => calendar ? upcomingEarnings(calendar, d.sym, d.lastDate, EARNINGS_HORIZON_DAYS) : undefined;

  const { top, passed, gateRejected, newsRejected, failed } = rankResults(perTicker);
  const newsSummary = n => n.status === 'ok'
    ? { status: 'ok', count: n.count, sentiment: n.sentiment, label: n.label, aligned: n.aligned, multiplier: n.multiplier, gated: n.gated }
    : { status: n.status, error: n.error };
  const slim = ([sym, d]) => d.ok
    ? { sym, ok: true, passesGate: d.passesGate, newsGated: !!d.newsGated, liqRatio: d.liqRatio, rsi: d.rsiVal, direction: d.direction, baseScore: d.baseScore, score: d.score, lastClose: d.lastClose, yaqeen: d.yaqeen, cached: d.cached, news: newsSummary(d.news) }
    : { sym, ok: false, error: d.error };

  return { status: 200, body: {
    demo, fatal: newsFatal, scannedAt: new Date().toISOString(), params: { ...p, ...tradeP, ...newsP, earningsHorizonDays: EARNINGS_HORIZON_DAYS },
    counts: { requested: tickers.length, yaqeenExcluded: Object.keys(excluded).length, passed: passed.length, gateRejected: gateRejected.length, newsRejected: newsRejected.length, failed: failed.length },
    yaqeenExcluded: excluded,
    earnings: { ok: !!calendar, error: earningsError },
    picks: top.map(([sym, d], rank) => {
      const n = d.bars.c.length, from = Math.max(0, n - CHART_BARS);
      const cut = k => d.bars[k].slice(from);
      return {
        rank: rank + 1, sym, yaqeen: d.yaqeen, lastDate: d.lastDate, direction: d.direction,
        liqRatio: d.liqRatio, rsi: d.rsiVal, momentum: d.momentumStrength, atr: d.atr, baseScore: d.baseScore, score: d.score,
        trade: buildTrade(d, tradeP),
        // مصدر الترشيح — شرط أساسي: كل مصدر ظاهر بوضوح، وما لم يُفحص يُعلن أنه لم يُفحص.
        sources: {
          liquidity: { active: true, value: d.liqRatio },
          technical: { active: true, value: d.rsiVal },
          news: { ...newsSummary(d.news), articles: d.news.articles || [] },
          earnings: calendar ? earningsFor({ sym, lastDate: d.lastDate }) : { error: earningsError || 'لم يُفحص' },
        },
        bars: { t: cut('t'), o: cut('o'), h: cut('h'), l: cut('l'), c: cut('c') },
      };
    }),
    all: Object.entries(perTicker).map(slim).sort((a, b) => (b.score || 0) - (a.score || 0)),
  } };
}
