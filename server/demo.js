// بيانات مصطنعة للوضع التجريبي فقط (بدون مفتاح). الواجهة توسمها بوضوح "تجريبي".
// ثابتة لكل (سهم، يوم) حتى يكون العرض قابلاً للتكرار.

function seedFrom(str) {
  let h = 2166136261;
  for (const ch of str) { h ^= ch.charCodeAt(0); h = Math.imul(h, 16777619); }
  return h >>> 0;
}
function rng(seed) {
  let a = seed;
  return () => { a |= 0; a = (a + 0x6D2B79F5) | 0; let t = Math.imul(a ^ (a >>> 15), 1 | a); t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t; return ((t ^ (t >>> 14)) >>> 0) / 4294967296; };
}

export function demoBars(symbol, days = 100) {
  const today = new Date().toISOString().slice(0, 10);
  const r = rng(seedFrom(symbol + today));
  const drift = (r() - 0.5) * 0.006;
  let price = 40 + r() * 400;
  const baseVol = 5e6 + r() * 5e7;
  const spike = r() < 0.5 ? 1.6 + r() * 1.8 : 0.7 + r() * 0.6; // نصف الأسهم تقريبًا فيها سيولة غير طبيعية
  const out = { t: [], o: [], h: [], l: [], c: [], v: [] };
  const end = Date.UTC(...today.split('-').map((x, i) => i === 1 ? x - 1 : +x));
  for (let i = 0; i < days; i++) {
    const open = price;
    const close = open * (1 + drift + (r() - 0.5) * 0.04);
    const hi = Math.max(open, close) * (1 + r() * 0.015);
    const lo = Math.min(open, close) * (1 - r() * 0.015);
    out.t.push(end - (days - 1 - i) * 86400000);
    out.o.push(open); out.h.push(hi); out.l.push(lo); out.c.push(close);
    out.v.push(Math.round(baseVol * (0.7 + r() * 0.6) * (i === days - 1 ? spike : 1)));
    price = close;
  }
  return out;
}

const DEMO_HEADLINES = ['تقرير محلل يرفع السعر المستهدف', 'صفقة استحواذ محتملة', 'تحقيق تنظيمي جديد', 'إطلاق منتج جديد', 'تراجع توقعات المبيعات'];

export function demoNews(symbol) {
  const today = new Date().toISOString().slice(0, 10);
  const r = rng(seedFrom('news' + symbol + today));
  const count = r() < 0.3 ? 0 : 1 + Math.floor(r() * 4);
  const now = Date.now(), articles = [];
  for (let i = 0; i < count; i++) {
    articles.push({ title: `[تجريبي] ${symbol}: ${DEMO_HEADLINES[Math.floor(r() * DEMO_HEADLINES.length)]}`, url: '', source: 'Demo', time: now - Math.floor(r() * 3 * 86400000), relevance: 0.3 + r() * 0.7, score: (r() - 0.45) * 0.9 });
  }
  const w = articles.reduce((s, a) => s + a.relevance, 0);
  const sentiment = w ? articles.reduce((s, a) => s + a.relevance * a.score, 0) / w : 0;
  return { count, sentiment, articles: articles.sort((a, b) => b.relevance - a.relevance).slice(0, 3) };
}

export function demoEarnings(symbols) {
  const today = new Date().toISOString().slice(0, 10), base = Date.parse(today + 'T00:00:00Z');
  const map = {};
  for (const s of symbols) {
    const r = rng(seedFrom('earn' + s + today));
    const d = base + Math.floor(r() * 60) * 86400000;
    map[s] = [{ date: d, reportDate: new Date(d).toISOString().slice(0, 10), estimate: null, timeOfTheDay: r() < 0.5 ? 'pre-market' : 'post-market' }];
  }
  return map;
}

// عيّنة من أسهم أمريكية عادية معروفة — بديل تجريبي عن «السوق كامل» (الحقيقي يأتي من Massive).
// الأسماء والبورصات حقيقية عشان تتعرف على السهم، أما الأسعار فمصطنعة ولا تطابق السوق.
const N = 'NASDAQ', Y = 'NYSE';
const DEMO_COMPANIES = {
  AAPL: ['Apple Inc.', N], MSFT: ['Microsoft Corp.', N], NVDA: ['NVIDIA Corp.', N], AMZN: ['Amazon.com Inc.', N],
  GOOGL: ['Alphabet Inc. (Class A)', N], META: ['Meta Platforms Inc.', N], TSLA: ['Tesla Inc.', N], AVGO: ['Broadcom Inc.', N],
  AMD: ['Advanced Micro Devices Inc.', N], NFLX: ['Netflix Inc.', N], JPM: ['JPMorgan Chase & Co.', Y], XOM: ['Exxon Mobil Corp.', Y],
  BA: ['Boeing Co.', Y], COST: ['Costco Wholesale Corp.', N], WMT: ['Walmart Inc.', N], HD: ['Home Depot Inc.', Y],
  PG: ['Procter & Gamble Co.', Y], KO: ['Coca-Cola Co.', Y], PEP: ['PepsiCo Inc.', N], MRK: ['Merck & Co. Inc.', Y],
  ABBV: ['AbbVie Inc.', Y], LLY: ['Eli Lilly and Co.', Y], UNH: ['UnitedHealth Group Inc.', Y], JNJ: ['Johnson & Johnson', Y],
  PFE: ['Pfizer Inc.', Y], CVX: ['Chevron Corp.', Y], COP: ['ConocoPhillips', Y], SLB: ['SLB N.V.', Y], ORCL: ['Oracle Corp.', Y],
  CRM: ['Salesforce Inc.', Y], ADBE: ['Adobe Inc.', N], INTC: ['Intel Corp.', N], QCOM: ['Qualcomm Inc.', N],
  TXN: ['Texas Instruments Inc.', N], MU: ['Micron Technology Inc.', N], AMAT: ['Applied Materials Inc.', N],
  LRCX: ['Lam Research Corp.', N], KLAC: ['KLA Corp.', N], PANW: ['Palo Alto Networks Inc.', N], CRWD: ['CrowdStrike Holdings Inc.', N],
  SNOW: ['Snowflake Inc.', Y], PLTR: ['Palantir Technologies Inc.', N], UBER: ['Uber Technologies Inc.', Y], ABNB: ['Airbnb Inc.', N],
  SHOP: ['Shopify Inc.', N], PYPL: ['PayPal Holdings Inc.', N], XYZ: ['Block Inc.', Y], COIN: ['Coinbase Global Inc.', N],
  V: ['Visa Inc.', Y], MA: ['Mastercard Inc.', Y], AXP: ['American Express Co.', Y], GS: ['Goldman Sachs Group Inc.', Y],
  MS: ['Morgan Stanley', Y], BAC: ['Bank of America Corp.', Y], C: ['Citigroup Inc.', Y], WFC: ['Wells Fargo & Co.', Y],
  SCHW: ['Charles Schwab Corp.', Y], BLK: ['BlackRock Inc.', Y], DIS: ['Walt Disney Co.', Y], CMCSA: ['Comcast Corp.', N],
  T: ['AT&T Inc.', Y], VZ: ['Verizon Communications Inc.', Y], TMUS: ['T-Mobile US Inc.', N], NKE: ['Nike Inc.', Y],
  SBUX: ['Starbucks Corp.', N], MCD: ["McDonald's Corp.", Y], CMG: ['Chipotle Mexican Grill Inc.', Y], LOW: ["Lowe's Companies Inc.", Y],
  TGT: ['Target Corp.', Y], CAT: ['Caterpillar Inc.', Y], DE: ['Deere & Co.', Y], GE: ['GE Aerospace', Y],
  HON: ['Honeywell International Inc.', N], LMT: ['Lockheed Martin Corp.', Y], RTX: ['RTX Corp.', Y], NOC: ['Northrop Grumman Corp.', Y],
  UPS: ['United Parcel Service Inc.', Y], FDX: ['FedEx Corp.', Y], DAL: ['Delta Air Lines Inc.', Y], UAL: ['United Airlines Holdings Inc.', N],
  CCL: ['Carnival Corp.', Y], F: ['Ford Motor Co.', Y], GM: ['General Motors Co.', Y], RIVN: ['Rivian Automotive Inc.', N],
  LCID: ['Lucid Group Inc.', N], NIO: ['NIO Inc.', Y], SOFI: ['SoFi Technologies Inc.', N], HOOD: ['Robinhood Markets Inc.', N],
  RBLX: ['Roblox Corp.', Y], DKNG: ['DraftKings Inc.', N], ROKU: ['Roku Inc.', N], ZM: ['Zoom Communications Inc.', N],
  DOCU: ['DocuSign Inc.', N], TWLO: ['Twilio Inc.', Y], NET: ['Cloudflare Inc.', Y], DDOG: ['Datadog Inc.', N],
  MDB: ['MongoDB Inc.', N], OKTA: ['Okta Inc.', N], ZS: ['Zscaler Inc.', N], SMCI: ['Super Micro Computer Inc.', N],
  ARM: ['Arm Holdings plc', N], DELL: ['Dell Technologies Inc.', Y], HPQ: ['HP Inc.', Y], IBM: ['International Business Machines Corp.', Y],
  CSCO: ['Cisco Systems Inc.', N], ANET: ['Arista Networks Inc.', Y], MRVL: ['Marvell Technology Inc.', N], ON: ['ON Semiconductor Corp.', N],
};
const DEMO_UNIVERSE = Object.keys(DEMO_COMPANIES);

export const demoProviders = {
  demo: true,
  universe: async ({ minPrice }) => {
    const last = new Date().toISOString().slice(0, 10);
    return { tickers: DEMO_UNIVERSE.filter(s => { const b = demoBars(s); return b.c[b.c.length - 1] >= minPrice; }), lastDay: last };
  },
  bars: async sym => ({ bars: demoBars(sym), cached: false }),
  profile: sym => DEMO_COMPANIES[sym] ? { name: DEMO_COMPANIES[sym][0], exchange: DEMO_COMPANIES[sym][1] } : null,
  news: async sym => ({ news: demoNews(sym) }),
  earnings: async syms => ({ calendar: demoEarnings(syms) }),
};
