# فريق الاتجاهات — العقد المشترك (Rased Trend Lab contract)

This file is the single source of truth every team member codes against. Change it only through the
orchestrator. Plain Node 18+ ESM, **no npm dependencies**, same style as `server/` (short Arabic comments).

## The strategy in one paragraph
Long-only (no short selling — shariah filter + earlier backtest showed shorts lose). US stocks, **5-minute bars,
regular session only** (09:30–16:00 America/New_York, 78 bars/day). A trade can only be **opened on Monday**
(the first trading day of the week if Monday is a holiday). It is closed at the stop, at the target, or at the
**close of the last bar of Friday** (last trading day of the week) at the latest. One trade per symbol per week.
Signal = **break of a descending trendline (resistance)** drawn through recent swing highs, confirmed on bar close.
No look-ahead: every decision at bar `i` uses bars `0..i` only; the fill is at the **open of bar `i+1`**.

## Bars format (shared everywhere)
```js
{ t: [ms], o: [], h: [], l: [], c: [], v: [] }   // ascending, t = bar START time in epoch ms (UTC)
```
Only regular-session bars. Pre/post-market bars are dropped by the fetcher.

## `server/trend.js` — owner: مطور الاتجاهات (trend developer)
Pure, Node-free (runs in the Android WebView too). May import from `./engine.js` (`atrArr`, `smaArr`, `rsiArr`)
with a single-line `import { … } from './engine.js';` (the bundler only supports that form). No `process`, no `fs`.
```js
export const TREND_DEFAULTS = { /* every tunable number, documented */ };

// America/New_York calendar parts of a bar time (DST-aware, via Intl.DateTimeFormat)
export function etParts(ms)            // → { date: 'YYYY-MM-DD', weekday: 1..5 (Mon..Fri), minutes: 0..1439 }

// Groups bar indices by trading week (Mon–Fri ET). weekKey = date of the week's Monday (even if a holiday).
export function splitWeeks(bars)       // → [{ weekKey, start, end, firstDay: 'YYYY-MM-DD', lastDay: 'YYYY-MM-DD' }]  (end inclusive)

// Trendlines visible at bar endIdx (uses bars 0..endIdx only).
// Line = { i1, p1, i2, p2, slope }   price at index i = p1 + slope * (i - i1)   (slope in price per bar)
export function findTrendlines(bars, endIdx, p = TREND_DEFAULTS)   // → { resistance: Line|null, support: Line|null }

// Full simulation of one week for one symbol (backtester + app use the same function).
// history: bars before the week may be used for context (trendlines can start last week).
export function weeklyTrade(bars, week, p = TREND_DEFAULTS)
// → { weekKey, signal: null | { idx, t, entryIdx, entryT, entry, stop, target, line, reason },
//     exit: null | { idx, t, price, how: 'target' | 'stop' | 'friday' },
//     r: number|null,  pct: number|null }      // r = (exit-entry)/(entry-stop); pct = exit/entry-1
// Rules inside a bar: if a bar touches both stop and target, assume the STOP first (conservative).
// A gap through the stop/target fills at that bar's open.

// What the app shows right now for the current (possibly unfinished) week.
export function liveSignal(bars, p = TREND_DEFAULTS, nowMs = Date.now())
// → { state: 'no-data' | 'waiting' | 'entered' | 'closed' | 'no-signal' | 'week-over',
//     weekKey, line, signal?, exit?, last: { t, price } }
//   waiting   = it is Monday, no break yet (line is the current resistance to watch)
//   entered   = position open (shows entry/stop/target)
//   closed    = hit stop/target this week     no-signal = Monday passed with no break
```

## `lab/` — owner: مختبر الاستراتيجية (strategy tester)
- `lab/universe.json` — `{ "symbols": ["AAPL", …] }` ~80 liquid US common stocks (no ETFs).
- `lab/fetch.mjs` — downloads 5-minute bars into `lab/data/5m/SYM.json` (gitignored), in the bars format.
  Source order: `MASSIVE_API_KEY` env set → Massive/Polygon `/v2/aggs/ticker/SYM/range/5/minute/FROM/TO`
  (2 years, 12.5 s between calls on the free plan); otherwise Yahoo chart API (`interval=5m&range=60d`, no key).
  Drops non-regular-session bars. Writes `lab/data/meta.json` `{ source, fetchedAt, from, to, symbols: {SYM: barsCount} }`.
- `lab/backtest.mjs` — paper account over every week in the data, using `weeklyTrade` from `server/trend.js`.
  The strategy function is injected (`runBacktest({ barsBySym, strategy, params, account })`) so it is testable
  with a fake strategy. Writes `lab/results/backtest.json` (schema below).
- Paper account rules: start **$10,000**, risk **1% of equity per trade** (shares = floor(risk / (entry-stop))),
  position value capped at equity / maxPositions, **maxPositions = 5** open at once (take signals in time order),
  slippage 0.02% per side, no commission, fractional shares not allowed.
- `.github/workflows/rased-lab.yml` — on `workflow_dispatch`, every **Saturday 06:00 UTC**, and on push touching
  `lab/**` or `server/trend.js`: `npm test` → fetch → backtest → rank → report, then commits `lab/results/` back
  to the branch it ran on (`[skip ci]` in the message). Uses secret `MASSIVE_API_KEY` if present.

### `lab/results/backtest.json`
```js
{ generatedAt, source: 'massive'|'yahoo', dataFrom, dataTo, params, universe: [...],
  weeks: [{ weekKey, trades, wins, pnl, equityEnd, returnPct }],
  account: { start: 10000, end, returnPct, maxDrawdownPct, trades, winRate, avgR, profitFactor },
  trades: [{ sym, weekKey, entryT, entry, stop, target, exitT, exit, how, r, pct, shares, pnl }],
  perSymbol: { SYM: { weeks, signals, trades, wins, winRate, avgR, totalR, avgPct, bestR, worstR } } }
```

## `lab/rank.mjs`, `lab/report.mjs` — owner: مفلتر النتائج (results filter)
- `rank.mjs` reads `backtest.json`, scores how well each symbol historically *responds* to this setup, and writes
  `lab/results/top5.json`. Must penalise small samples (e.g. shrink win rate / avgR toward the universe mean,
  require a minimum number of trades) and must report an **out-of-sample** check: rank on the older half of the
  weeks, then show how those picks did in the newer half. Never rank on a single lucky trade.
- `top5.json`: `{ generatedAt, method, minTrades, top: [{ sym, score, trades, winRate, avgR, totalR, oos: { trades, avgR }, why }], all: [...] }`
- `report.mjs` writes `lab/results/REPORT.md` in **Arabic**: account summary, a weekly table (one row per week),
  the top 5 with the reason, the out-of-sample check, and plain caveats (sample size, data source, no costs).

## The Rased app — owner: مبرمج الاتجاهات على الشارت (chart programmer)
- Keep the live-price path exactly as it is: Massive key on the phone → `fetch` → Java bridge `RasedNative`
  (Android) / server key (Railway). Add 5-minute bars as a method on the existing Massive store so it shares the
  same rate-limit queue: `store.aggs5m(sym, fromMs, toMs)` → bars format (regular session only).
- New tab **«الاتجاهات»**: the top 5 from `top5.json` (bundled at build time from `lab/results/top5.json`, refreshed
  from `https://raw.githubusercontent.com/mytatrayd-boop/-/claude/mobile-app-design-gxh65v/lab/results/top5.json`
  — add `raw.githubusercontent.com` to the bridge allowlist), each with a 5-minute chart of the current week:
  candles, the trendline, and entry / stop / target lines from `liveSignal`, plus a state chip.
  Also a «الحساب الوهمي» view of `backtest.json` weeks (equity per week, wins/losses).
- Demo mode (no key) uses synthetic 5-minute bars, clearly labelled.
- Free Massive plan gives minute bars up to the previous close (not live intraday) — the UI must state the data
  time of the last bar honestly.

## Done means
`npm test` passes (new tests for every new module, no network in tests), and for the app: the Android page builds
(`node scripts/build-android.mjs`) and renders without page errors in headless Chromium.
