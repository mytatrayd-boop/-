'use strict';

const DEFAULTS = {
  scope: 'market', // 'market' = السوق الأمريكي كامل (Massive) | 'list' = قائمتي
  minPrice: 5, minDollarVolM: 20, // فلتر كون السوق: أقل سعر ($) وأقل متوسط قيمة تداول يومية (مليون $)
  tickers: ['AAPL', 'MSFT', 'NVDA', 'TSLA', 'AMZN', 'GOOGL', 'META', 'AMD', 'NFLX', 'JPM', 'XOM', 'BA'],
  volAvgDays: 20, volMult: 1.5, slAtr: 1.5, rr: 1.5,
  newsDays: 3, newsBoost: 0.5, newsGate: 0.35, newsMax: 5,
  excludeHaram: true, excludeMashbooh: false,
  // snapshot يقين بتاريخ 2026-09-28 (الأسهم الأكثر بحثًا)
  yaqeen: { NVDA: 'شرعي', AAPL: 'محل نظر', TSLA: 'محل نظر', AMD: 'محل نظر' },
};
const VERDICTS = ['شرعي', 'محل نظر', 'غير شرعي'];
const QUOTA = 25;

const $ = s => document.querySelector(s);
const esc = s => String(s).replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const fmt = (v, d = 2) => Number(v).toLocaleString('en-US', { minimumFractionDigits: d, maximumFractionDigits: d });

/* ---------- storage (قد يكون غير متاح في وضع التصفح الخاص) ---------- */
function load(key, fallback) { try { const v = localStorage.getItem(key); return v ? JSON.parse(v) : fallback; } catch { return fallback; } }
function save(key, value) { try { localStorage.setItem(key, JSON.stringify(value)); } catch { /* تجاهل */ } }

let settings = { ...structuredClone(DEFAULTS), ...load('rased.settings', {}) };
let lastScan = load('rased.lastScan', null);
let listFilter = 'all';
const persist = () => save('rased.settings', settings);

/* ---------- navigation ---------- */
function show(view) {
  document.querySelectorAll('.view').forEach(v => v.classList.toggle('active', v.id === 'view-' + view));
  document.querySelectorAll('.tab').forEach(t => t.classList.toggle('active', t.dataset.view === view));
  $('#scanBtn').hidden = view === 'settings' || view === 'yaqeen' || view === 'trends';
  window.scrollTo({ top: 0 });
  if (view === 'home') requestAnimationFrame(drawCharts);
  if (view === 'trends') openTrends();
}
document.querySelectorAll('.tab').forEach(t => t.addEventListener('click', () => show(t.dataset.view)));

let toastTimer;
function toast(msg, kind = '') {
  const el = $('#toast'); el.textContent = msg; el.className = 'toast show ' + kind;
  clearTimeout(toastTimer); toastTimer = setTimeout(() => el.classList.remove('show'), 3800);
}

// اسم الشركة الكامل + البورصة: الرمز وحده قد يلتبس (رموز متشابهة في أسواق ثانية)
function companyLine(p) {
  if (!p.name && !p.exchange) return '';
  return `<div class="pick-co">${esc(p.name || '')}${p.exchange ? ` <span class="exch">${esc(p.exchange)}</span>` : ''}</div>`;
}
// صفحة السهم في Yahoo Finance بنفس الرمز الأمريكي (فئات الأسهم: BRK.B → BRK-B)
const quoteUrl = sym => `https://finance.yahoo.com/quote/${encodeURIComponent(String(sym).replace(/\./g, '-'))}`;

/* ---------- scan ---------- */
// النسخة المستقلة (بدون خادم) تعرّف window.RASED_LOCAL وتشغّل نفس منطق المسح محليًا ببيانات تجريبية.
const LOCAL = window.RASED_LOCAL || null;

async function scanRequest(req) {
  if (LOCAL) {
    const { status, body } = await LOCAL.runScan(req);
    if (status !== 200) throw new Error(body.error);
    return body;
  }
  const res = await fetch('api/scan', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(req) });
  const data = await res.json().catch(() => ({}));
  if (!res.ok) throw new Error(data.error || `الخادم رد بالحالة ${res.status}`);
  return data;
}

$('#scanBtn').addEventListener('click', async () => {
  const btn = $('#scanBtn');
  if (!settings.tickers.length) { toast('قائمة المسح فاضية — أضف أسهم من الإعدادات.', 'err'); return; }
  btn.disabled = true; btn.classList.add('busy'); btn.querySelector('.fab-label').textContent = 'يمسح…';
  $('#picks').innerHTML = '<div class="skeleton"></div><div class="skeleton"></div>';
  $('#summary').hidden = true;
  show('home');
  try {
    const req = {
        mode: settings.scope, minPrice: settings.minPrice, minDollarVol: settings.minDollarVolM * 1e6,
        tickers: settings.tickers, volAvgDays: settings.volAvgDays, volMult: settings.volMult, slAtr: settings.slAtr, rr: settings.rr,
        newsDays: settings.newsDays, newsBoost: settings.newsBoost, newsGate: settings.newsGate, newsMax: settings.newsMax,
        yaqeen: settings.yaqeen, excludeHaram: settings.excludeHaram, excludeMashbooh: settings.excludeMashbooh,
    };
    const data = await scanRequest(req);
    lastScan = data; save('rased.lastScan', data);
    refreshHealth();
    if (data.fatal) toast('⚠️ ' + data.fatal, 'err');
    else toast(`تم المسح: ${data.counts.passed} مؤهّل من ${data.counts.requested}${data.counts.newsRejected ? ` (${data.counts.newsRejected} استُبعد بخبر معاكس)` : ''}.`, 'ok');
  } catch (e) {
    toast('❌ ' + (e.message === 'Failed to fetch' ? 'ما قدرنا نوصل للخادم — تأكد من الاتصال.' : e.message), 'err');
  } finally {
    btn.disabled = false; btn.classList.remove('busy'); btn.querySelector('.fab-label').textContent = 'امسح السوق';
    renderHome(); renderList(); renderYaqeen();
  }
});

/* ---------- home ---------- */
const NEWS_STATUS = { capped: 'لم يُفحص (حد الحصة)', skipped: 'لم يُفحص', error: 'تعذّر الجلب' };
function newsCell(n) {
  if (n.status !== 'ok') return `<div class="src off" title="${esc(n.error || '')}"><div class="k"><i></i>خبر</div><div class="v">${NEWS_STATUS[n.status] || 'لم يُفحص'}</div></div>`;
  if (!n.count) return `<div class="src off"><div class="k"><i></i>خبر</div><div class="v">لا يوجد خبر</div></div>`;
  const against = n.aligned <= -0.15; // نفس حد "سلبي نسبيًا" عند Alpha Vantage
  return `<div class="src news ${against ? 'against' : ''}"><div class="k"><i></i>خبر · ${n.count}</div><div class="v">${esc(n.label)}</div></div>`;
}
function headlines(n) {
  if (n.status !== 'ok' || !n.articles || !n.articles.length) return '';
  return `<ul class="headlines">${n.articles.map(a => {
    const when = new Date(a.time).toISOString().slice(5, 16).replace('T', ' ');
    const title = esc(a.title);
    const safeUrl = /^https?:\/\//.test(a.url) ? esc(a.url) : '';
    return `<li><span class="dot ${a.score >= 0.15 ? 'pos' : a.score <= -0.15 ? 'neg' : ''}"></span>
      ${safeUrl ? `<a href="${safeUrl}" target="_blank" rel="noopener">${title}</a>` : `<span>${title}</span>`}
      <small class="mono">${esc(a.source)} · ${when}</small></li>`;
  }).join('')}</ul>`;
}
function earningsBanner(e) {
  if (e === null) return '';
  if (!e || e.error) return `<div class="earn off">📅 تقويم الأرباح: ${esc((e && e.error) || 'لم يُفحص')}</div>`;
  const when = e.daysAway === 0 ? 'اليوم' : e.daysAway === 1 ? 'بكرة' : e.daysAway === 2 ? 'بعد يومين' : `بعد ${e.daysAway} ${e.daysAway <= 10 ? 'أيام' : 'يوم'}`;
  const tod = e.timeOfTheDay === 'pre-market' ? 'قبل الافتتاح' : e.timeOfTheDay === 'post-market' ? 'بعد الإغلاق' : '';
  return `<div class="earn">⚠️ <b>أرباح ${when}</b> <span class="mono">${esc(e.reportDate)}</span>${tod ? ' · ' + tod : ''}<br><small>إعلان الأرباح داخل أسبوع الصفقة قد يسبب فجوة سعرية تتخطى وقف الخسارة. تنبيه فقط — لا يغيّر النتيجة.</small></div>`;
}
function yqClass(v) { return v === 'شرعي' ? 'ok' : v === 'محل نظر' ? 'warn' : v === 'غير شرعي' ? 'bad' : ''; }
const pct = (a, b) => ((b - a) / a * 100);

function renderHome() {
  const picks = $('#picks'), summary = $('#summary');
  if (!lastScan) {
    picks.innerHTML = `<div class="placeholder"><div class="big">🎯</div>اضغط "امسح السوق" تحت عشان نطلع لك أقوى سهمين.</div>`;
    summary.hidden = true; $('#lastScanLine').textContent = 'لم يتم أي مسح بعد';
    return;
  }
  const d = new Date(lastScan.scannedAt);
  const scope = lastScan.mode === 'market'
    ? `السوق كامل · <span class="mono">${lastScan.counts.requested.toLocaleString('en-US')}</span> سهم · آخر تداول <span class="mono">${esc(lastScan.marketLastDay || '')}</span>`
    : `قائمتي · <span class="mono">${lastScan.counts.requested}</span> سهم`;
  $('#lastScanLine').innerHTML = `${scope}<br>آخر مسح: <span class="mono">${d.toLocaleDateString('en-CA')} ${d.toLocaleTimeString('en-GB', { hour: '2-digit', minute: '2-digit' })}</span>${lastScan.demo ? ' · <b style="color:var(--news)">بيانات تجريبية</b>' : ''}`;

  if (!lastScan.picks.length) {
    picks.innerHTML = `<div class="placeholder"><div class="big">🔍</div>ما فيه أي سهم اجتاز بوابة السيولة اليوم.<br><span class="hint">جرّب تقلل "أقل مضاعف للدخول" أو توسّع القائمة.</span></div>`;
  } else {
    picks.innerHTML = lastScan.picks.map(p => {
      const buy = p.direction === 1, t = p.trade;
      return `
      <article class="pick">
        <div class="pick-head">
          <div>
            <div class="pick-sym"><span class="sym">${esc(p.sym)}</span><span class="rank">#${p.rank}</span></div>
            ${companyLine(p)}
            <div class="pick-price">آخر إغلاق <span class="mono">${fmt(t.entry)}</span> · <span class="mono">${new Date(p.lastDate).toISOString().slice(0, 10)}</span></div>
          </div>
          <span class="dir ${buy ? 'buy' : 'sell'}">${buy ? '▲ شراء' : '▼ بيع'}</span>
        </div>
        ${lastScan.demo ? '<div class="demo-warn">⚠️ السعر والأرقام هنا <b>مصطنعة للتجربة</b> ولا تطابق سعر السهم الحقيقي. الاسم والرمز حقيقيين.</div>' : ''}
        <div class="sources" aria-label="مصدر الترشيح">
          <div class="src liq"><div class="k"><i></i>سيولة</div><div class="v mono">×${fmt(p.liqRatio, 1)}</div></div>
          <div class="src tech"><div class="k"><i></i>فني RSI</div><div class="v mono">${fmt(p.rsi, 1)}</div></div>
          ${newsCell(p.sources.news)}
        </div>
        ${earningsBanner(p.sources.earnings)}
        ${headlines(p.sources.news)}
        <div class="levels">
          <div class="lvl en"><span class="lbl">الدخول</span><span class="val">${fmt(t.entry)}</span></div>
          <div class="lvl tp"><span class="lbl">الهدف · أسبوع</span><span class="val">${fmt(t.target)}</span><span class="pct">${pct(t.entry, t.target) >= 0 ? '+' : ''}${fmt(pct(t.entry, t.target), 1)}%</span></div>
          <div class="lvl sl"><span class="lbl">وقف الخسارة</span><span class="val">${fmt(t.stop)}</span><span class="pct">${pct(t.entry, t.stop) >= 0 ? '+' : ''}${fmt(pct(t.entry, t.stop), 1)}%</span></div>
        </div>
        <canvas class="chart" data-sym="${esc(p.sym)}"></canvas>
        <div class="pick-foot">
          <span class="yq ${yqClass(p.yaqeen)}">يقين: ${esc(p.yaqeen)}</span>
          <a class="link" href="${quoteUrl(p.sym)}" target="_blank" rel="noopener">📈 السعر الحقيقي</a>
          <a class="link" href="https://yaaqen.com/stocks/${encodeURIComponent(p.sym)}" target="_blank" rel="noopener">🔍 تحقق في يقين</a>
        </div>
        <p class="hint">${buy ? 'زخم صاعد' : 'زخم هابط'}، قوة الإشارة ${Math.round(p.momentum * 100)}% · حجم اليوم ${fmt(p.liqRatio, 1)}× متوسط ${lastScan.params.volAvgDays} يوم${p.sources.news.status === 'ok' && p.sources.news.count ? ` · أثر الخبر ×${fmt(p.sources.news.multiplier, 2)} على النتيجة` : ''}.</p>
      </article>`;
    }).join('');
  }

  const c = lastScan.counts;
  summary.hidden = false;
  summary.innerHTML = [
    ['مؤهّل', c.passed, ''], ['سيولة ضعيفة', c.gateRejected, ''], ['خبر معاكس', c.newsRejected || 0, ''],
    ['استبعاد يقين', c.yaqeenExcluded, ''], ['فشل الجلب', c.failed, c.failed ? 'bad' : ''],
  ].map(([l, n, cls]) => `<div class="stat ${cls}"><div class="n">${n}</div><div class="l">${l}</div></div>`).join('');
  requestAnimationFrame(drawCharts);
}

function drawCharts() {
  if (!lastScan) return;
  document.querySelectorAll('canvas.chart').forEach(cv => {
    const p = lastScan.picks.find(x => x.sym === cv.dataset.sym);
    if (p) drawChart(cv, p);
  });
}

function drawChart(canvas, p) {
  const rect = canvas.getBoundingClientRect();
  if (!rect.width) return;
  const dpr = window.devicePixelRatio || 1, w = rect.width, h = rect.height;
  canvas.width = w * dpr; canvas.height = h * dpr;
  const ctx = canvas.getContext('2d'); ctx.setTransform(dpr, 0, 0, dpr, 0, 0); ctx.clearRect(0, 0, w, h);

  const b = p.bars, { entry, stop, target } = p.trade;
  const count = Math.min(w < 380 ? 40 : 60, b.c.length), start = b.c.length - count;
  let lo = Math.min(stop, target), hi = Math.max(stop, target);
  for (let i = start; i < b.c.length; i++) { lo = Math.min(lo, b.l[i]); hi = Math.max(hi, b.h[i]); }
  const pad = (hi - lo) * 0.08 || 1; lo -= pad; hi += pad;
  const mL = 8, mR = 54, mT = 10, mB = 10, pw = w - mL - mR, ph = h - mT - mB;
  const x = i => mL + ((i - start + 0.5) / count) * pw;
  const y = v => mT + (1 - (v - lo) / (hi - lo)) * ph;
  const bw = Math.max(2, pw / count * 0.62);

  for (let i = start; i < b.c.length; i++) {
    const up = b.c[i] >= b.o[i];
    ctx.strokeStyle = ctx.fillStyle = up ? '#3fb950' : '#f0605a'; ctx.lineWidth = 1;
    ctx.beginPath(); ctx.moveTo(x(i), y(b.h[i])); ctx.lineTo(x(i), y(b.l[i])); ctx.stroke();
    const top = Math.min(y(b.o[i]), y(b.c[i]));
    ctx.fillRect(x(i) - bw / 2, top, bw, Math.max(Math.abs(y(b.c[i]) - y(b.o[i])), 1));
  }
  ctx.font = '600 10px "IBM Plex Mono", monospace'; ctx.textBaseline = 'middle';
  const line = (v, color, dashed) => {
    ctx.strokeStyle = color; ctx.lineWidth = 1.5; ctx.setLineDash(dashed ? [5, 4] : []);
    ctx.beginPath(); ctx.moveTo(mL, y(v)); ctx.lineTo(w - mR, y(v)); ctx.stroke(); ctx.setLineDash([]);
    const label = fmt(v); ctx.fillStyle = color;
    ctx.beginPath(); ctx.roundRect(w - mR + 3, y(v) - 8, mR - 5, 16, 4); ctx.fill();
    ctx.fillStyle = '#0a0d12'; ctx.textAlign = 'center'; ctx.fillText(label, w - mR / 2 + 1, y(v) + 0.5);
  };
  line(target, '#3fb950'); line(stop, '#f0605a'); line(entry, '#4fa3e3', true);
}
let resizeTimer;
window.addEventListener('resize', () => { clearTimeout(resizeTimer); resizeTimer = setTimeout(() => { drawCharts(); drawTrendCharts(); }, 120); });

/* ---------- all tickers list ---------- */
document.querySelectorAll('.seg-btn').forEach(b => b.addEventListener('click', () => {
  listFilter = b.dataset.filter;
  document.querySelectorAll('.seg-btn').forEach(x => x.classList.toggle('active', x === b));
  renderList();
}));

function renderList() {
  const el = $('#allList');
  if (!lastScan) { el.innerHTML = '<div class="empty">امسح السوق أولاً.</div>'; return; }
  const mult = lastScan.params.volMult;
  const rows = [
    ...lastScan.all.map(r => ({ ...r, kind: !r.ok ? 'err' : !r.passesGate ? 'rej' : r.newsGated ? 'newsrej' : 'pass' })),
    ...Object.entries(lastScan.yaqeenExcluded).map(([sym, v]) => ({ sym, kind: 'yq', verdict: v })),
  ].filter(r => listFilter === 'all' || (listFilter === 'passed' ? r.kind === 'pass' : r.kind !== 'pass'));
  if (!rows.length) { el.innerHTML = '<div class="empty">لا يوجد.</div>'; return; }
  const note = lastScan.allTruncated
    ? `<p class="hint">مسح السوق كامل: نعرض أعلى ${lastScan.all.length} سهم من <span class="mono">${lastScan.counts.requested.toLocaleString('en-US')}</span> — مؤهّل ${lastScan.counts.passed}، سيولة ضعيفة ${lastScan.counts.gateRejected.toLocaleString('en-US')}.</p>` : '';
  el.innerHTML = note + rows.map(r => {
    if (r.kind === 'err') return `<div class="row"><span class="sym">${esc(r.sym)}</span><div class="mid">${esc(r.error)}</div><span class="tag err">فشل</span></div>`;
    if (r.kind === 'yq') return `<div class="row"><span class="sym">${esc(r.sym)}</span><div class="mid">مستبعد بفلتر يقين: <b>${esc(r.verdict)}</b></div><span class="tag yq">يقين</span></div>`;
    const fill = Math.min(100, r.liqRatio / (mult * 2) * 100);
    return `<div class="row">
      <span class="sym">${esc(r.sym)}${r.name ? `<small class="co" title="${esc(r.name)}">${esc(r.name)}</small>` : ''}</span>
      <div class="mid">سيولة <b class="mono">×${fmt(r.liqRatio, 2)}</b> · RSI <b class="mono">${fmt(r.rsi, 1)}</b> ${r.direction === 1 ? '▲' : '▼'}${r.news && r.news.status === 'ok' ? ` · خبر: <b>${esc(r.news.label)}</b>${r.news.count ? ` <span class="mono">×${fmt(r.news.multiplier, 2)}</span>` : ''}` : ''}
        <div class="bar"><i class="${r.passesGate ? '' : 'under'}" style="width:${fill}%"></i></div></div>
      <span class="tag ${r.kind}">${{ pass: 'مؤهّل', rej: 'سيولة ضعيفة', newsrej: 'خبر معاكس' }[r.kind]}</span></div>`;
  }).join('');
}

/* ---------- yaqeen ---------- */
function renderYaqeen() {
  $('#excludeHaram').checked = settings.excludeHaram;
  $('#excludeMashbooh').checked = settings.excludeMashbooh;
  // الترشيحات أولاً (في مسح السوق كامل غالبًا أسهم خارج قائمتك)، ثم قائمتك، ثم أي سهم سبق وحكمت عليه
  const syms = [...new Set([...(lastScan ? lastScan.picks.map(p => p.sym) : []), ...settings.tickers, ...Object.keys(settings.yaqeen)])];
  $('#yaqeenRows').innerHTML = syms.map(sym => `
    <div class="yrow" data-sym="${esc(sym)}">
      <span class="sym">${esc(sym)}</span>
      <div class="vseg">${VERDICTS.map(v => `<button data-v="${v}" class="${settings.yaqeen[sym] === v ? 'on' : ''}">${v}</button>`).join('')}</div>
      <a href="https://yaaqen.com/stocks/${encodeURIComponent(sym)}" target="_blank" rel="noopener" aria-label="افتح ${esc(sym)} في يقين">↗</a>
    </div>`).join('') || '<div class="empty">أضف أسهم من الإعدادات.</div>';
}
$('#yaqeenRows').addEventListener('click', e => {
  const btn = e.target.closest('button[data-v]'); if (!btn) return;
  const sym = btn.closest('.yrow').dataset.sym, v = btn.dataset.v;
  if (settings.yaqeen[sym] === v) delete settings.yaqeen[sym]; else settings.yaqeen[sym] = v; // ضغطة ثانية = غير معروف
  persist(); renderYaqeen();
});
$('#excludeHaram').addEventListener('change', e => { settings.excludeHaram = e.target.checked; persist(); });
$('#excludeMashbooh').addEventListener('change', e => { settings.excludeMashbooh = e.target.checked; persist(); });

/* ---------- settings ---------- */
function renderSettings() {
  $('#chips').innerHTML = settings.tickers.map(s => `<span class="chip">${esc(s)}<button data-rm="${esc(s)}" aria-label="احذف ${esc(s)}">×</button></span>`).join('');
  const market = settings.scope === 'market';
  document.querySelectorAll('#scopeSeg .seg-btn').forEach(b => b.classList.toggle('active', b.dataset.scope === settings.scope));
  $('#marketCard').hidden = !market;
  $('#listCard').classList.toggle('dim', market);
  const n = settings.tickers.length;
  const news = Math.min(settings.newsMax, market ? settings.newsMax : n);
  const worst = (market ? 0 : n) + news + 1;
  $('#quotaHint').innerHTML = market
    ? `في مسح السوق كامل الأسعار تجي من مخزن Massive (بدون استهلاك وقت المسح). من حصة Alpha Vantage (~${QUOTA}/يوم): حتى <b class="mono">${news}</b> خبر + <b class="mono">1</b> تقويم أرباح = <b class="mono">${worst}</b> لكل مسح. هذه القائمة تُستخدم فقط في وضع «قائمتي».`
    : `⚠️ حصتك المجانية ~${QUOTA} طلب/يوم. أسوأ حالة لكل مسح: <b class="mono">${n}</b> سعر + <b class="mono">${news}</b> خبر + <b class="mono">1</b> تقويم أرباح = <b class="mono" style="color:${worst > QUOTA ? 'var(--sell)' : 'inherit'}">${worst}</b>. الخادم يخزّن النتائج مؤقتًا فتكرار المسح بنفس اليوم ما يستهلك.`;
  document.querySelectorAll('.stepper').forEach(st => {
    const k = st.dataset.key, dec = (st.dataset.step.split('.')[1] || '').length;
    st.innerHTML = `<button data-d="-1" aria-label="إنقاص">−</button><output class="mono">${settings[k].toFixed(dec)}</output><button data-d="1" aria-label="زيادة">+</button>`;
  });
}
$('#scopeSeg').addEventListener('click', e => {
  const b = e.target.closest('[data-scope]'); if (!b) return;
  settings.scope = b.dataset.scope; persist(); renderSettings();
});
$('#chips').addEventListener('click', e => {
  const s = e.target.dataset.rm; if (!s) return;
  settings.tickers = settings.tickers.filter(t => t !== s); persist(); renderSettings(); renderYaqeen();
});
$('#addTicker').addEventListener('submit', e => {
  e.preventDefault();
  const s = $('#newTicker').value.trim().toUpperCase();
  if (!/^[A-Z][A-Z0-9.\-]{0,9}$/.test(s)) { toast('رمز غير صالح.', 'err'); return; }
  if (settings.tickers.includes(s)) { toast('الرمز موجود.', 'err'); return; }
  if (settings.tickers.length >= QUOTA) { toast(`الحد ${QUOTA} سهم.`, 'err'); return; }
  settings.tickers.push(s); $('#newTicker').value = ''; persist(); renderSettings(); renderYaqeen();
});
document.querySelectorAll('.stepper').forEach(st => st.addEventListener('click', e => {
  const b = e.target.closest('button'); if (!b) return;
  const k = st.dataset.key, step = +st.dataset.step;
  const v = Math.round((settings[k] + step * +b.dataset.d) * 100) / 100;
  settings[k] = Math.min(+st.dataset.max, Math.max(+st.dataset.min, v)); persist(); renderSettings();
}));
// تأكيد داخل الصفحة بضغطتين (نوافذ confirm() لا تظهر في كل البيئات)
let resetArmed = null;
$('#resetBtn').addEventListener('click', e => {
  const btn = e.currentTarget;
  if (!resetArmed) {
    btn.textContent = 'اضغط مرة ثانية للتأكيد — تُمسح أحكام يقين أيضًا'; btn.classList.add('armed');
    resetArmed = setTimeout(() => { resetArmed = null; btn.textContent = 'استرجاع الإعدادات الافتراضية'; btn.classList.remove('armed'); }, 4000);
    return;
  }
  clearTimeout(resetArmed); resetArmed = null;
  btn.textContent = 'استرجاع الإعدادات الافتراضية'; btn.classList.remove('armed');
  settings = structuredClone(DEFAULTS); persist(); renderSettings(); renderYaqeen(); toast('تم الاسترجاع.', 'ok');
});

/* ---------- الاتجاهات: أفضل 5 من المختبر + شارت 5 دقائق ---------- */
// المصادر: مضمّنة وقت البناء (window.RASED_LAB) → آخر نسخة محفوظة → تحديث من الخادم أو GitHub وقت التشغيل.
const LAB_RAW = 'https://raw.githubusercontent.com/mytatrayd-boop/-/claude/mobile-app-design-gxh65v/lab/results/';
const DEMO_TREND_SYMS = ['AAPL', 'MSFT', 'NVDA', 'AMD', 'META'];
const TREND_TTL_MS = 10 * 60 * 1000;
const slimBacktest = b => b && typeof b === 'object' ? { generatedAt: b.generatedAt, source: b.source, dataFrom: b.dataFrom, dataTo: b.dataTo, weeks: Array.isArray(b.weeks) ? b.weeks : [], account: b.account || null } : null;
const okTop5 = t => !!(t && Array.isArray(t.top) && t.top.length);
const okBacktest = b => !!(b && (b.account || (b.weeks && b.weeks.length)));
const newer = (a, b) => !a ? b || null : !b ? a : String(b.generatedAt || '') > String(a.generatedAt || '') ? b : a;
const slimSpikeLab = d => d && typeof d === 'object' ? { generatedAt: d.generatedAt, source: d.source, dataFrom: d.dataFrom, dataTo: d.dataTo, defaultKey: d.defaultKey, default: d.default || null, account: d.account || null, walkForward: d.walkForward || null } : null;
const okSpikeLab = d => !!(d && d.default && Number.isFinite(+d.default.trades));
const okSpikesToday = d => !!(d && typeof d.day === 'string' && Array.isArray(d.signals));
// المسح الليلي: الأحدث بيوم السوق ثم بوقت التوليد
const newerDay = (a, b) => !a ? b || null : !b ? a : (b.day > a.day || (b.day === a.day && String(b.generatedAt || '') > String(a.generatedAt || ''))) ? b : a;
let lab = (() => {
  const e = window.RASED_LAB || {}, c = load('rased.lab', {}) || {};
  return {
    top5: newer(okTop5(e.top5) ? e.top5 : null, okTop5(c.top5) ? c.top5 : null),
    backtest: newer(okBacktest(e.backtest) ? slimBacktest(e.backtest) : null, okBacktest(c.backtest) ? c.backtest : null),
    spike: newer(okSpikeLab(e.spike) ? slimSpikeLab(e.spike) : null, okSpikeLab(c.spike) ? c.spike : null),
    spikesToday: newerDay(okSpikesToday(e.spikesToday) ? e.spikesToday : null, okSpikesToday(c.spikesToday) ? c.spikesToday : null),
  };
})();
let labRefreshedAt = 0;
let serverMode = null;            // وضع الخادم من /api/health: { demo, massive }
const trendData = new Map();      // sym → { status: 'loading'|'ok'|'error', data, error, code, at }
let trendQueue = [], trendBusy = false, trendObserver = null;

const trendsOpen = () => { const v = $('#view-trends'); return !!(v && v.classList.contains('active')); };
function trendMode() {
  // تطبيق الأندرويد: Massive بالمفتاح، وإلا Yahoo بدون مفتاح (والتجريبي فقط لو فشل Yahoo — موسوم على البطاقة)
  if (LOCAL && LOCAL.keys) return { demo: false, massive: true, yahoo: !LOCAL.keys().massive };
  if (LOCAL) return { demo: true, massive: false };   // النسخة المستقلة: تجريبية دائمًا
  return serverMode || { demo: false, massive: true }; // قبل وصول /api/health نحاول ونعرض الخطأ إن وُجد
}
function trendSymbols() {
  if (okTop5(lab.top5)) return lab.top5.top.slice(0, 5).map(x => String(x.sym).toUpperCase());
  const m = trendMode();
  return m.demo || m.yahoo ? DEMO_TREND_SYMS : []; // معاينة (Yahoo بدون مفتاح يكفي) — Massive المجاني نوفّر طلباته
}

async function fetchJson(url) {
  const res = await fetch(url, { cache: 'no-store' });
  if (!res.ok) throw new Error('HTTP ' + res.status);
  return res.json();
}
// نجرب كل مصدر بالترتيب؛ أي فشل صامت (المختبر قد لا يكون كتب نتائج بعد)
async function refreshLab() {
  if (Date.now() - labRefreshedAt < TREND_TTL_MS) return;
  labRefreshedAt = Date.now();
  const bases = LOCAL ? [LAB_RAW] : ['api/lab/', LAB_RAW];
  const get = async which => {
    for (const base of bases) {
      try { return await fetchJson(base + (base === LAB_RAW ? which + '.json' : which)); } catch { /* المصدر التالي */ }
    }
    return null;
  };
  const [t, b, sp, st] = await Promise.all([get('top5'), get('backtest'), get('spike'), get('spikes-today')]);
  let changed = false, spikesChanged = false;
  const ssp = okSpikeLab(sp) ? slimSpikeLab(sp) : null;
  if (ssp && newer(lab.spike, ssp) === ssp && ssp !== lab.spike) { lab.spike = ssp; changed = spikesChanged = true; }
  if (okSpikesToday(st) && newerDay(lab.spikesToday, st) === st && st !== lab.spikesToday) { lab.spikesToday = st; changed = spikesChanged = true; }
  if (spikesChanged && spikesOpen()) loadSpikes();
  if (okTop5(t) && newer(lab.top5, t) === t && t !== lab.top5) { lab.top5 = t; changed = true; }
  const sb = okBacktest(b) ? slimBacktest(b) : null;
  if (sb && newer(lab.backtest, sb) === sb && sb !== lab.backtest) { lab.backtest = sb; changed = true; }
  if (changed) { save('rased.lab', lab); if (trendsOpen() && trendsSub === 'trend') renderTrends(); }
}

async function trendRequest(sym) {
  if (LOCAL) {
    if (!LOCAL.trend) throw Object.assign(new Error('هذي النسخة ما فيها شارت الاتجاهات.'), { code: 'unsupported' });
    return LOCAL.trend(sym);
  }
  const res = await fetch('api/trend?sym=' + encodeURIComponent(sym), { cache: 'no-store' });
  const data = await res.json().catch(() => ({}));
  if (!res.ok) throw Object.assign(new Error(data.error || `الخادم رد بالحالة ${res.status}`), { code: data.code });
  return data;
}

// طابور واحد: سهم بعد سهم (الخطة المجانية 5 طلبات/دقيقة، مشتركة مع المزامنة اليومية)
function queueTrend(sym, front = false) {
  const cur = trendData.get(sym);
  // الخطأ لا يُعاد تلقائيًا عند التمرير (زر «إعادة المحاولة» أو إعادة فتح التبويب)
  if (cur && (cur.status === 'loading' || cur.status === 'error' || (cur.status === 'ok' && Date.now() - cur.at < TREND_TTL_MS))) return;
  trendQueue = trendQueue.filter(s => s !== sym);
  if (front) trendQueue.unshift(sym); else trendQueue.push(sym);
  pumpTrends();
}
async function pumpTrends() {
  if (trendBusy) return;
  const sym = trendQueue.shift();
  if (!sym) return;
  trendBusy = true;
  trendData.set(sym, { status: 'loading', at: Date.now() });
  updateTrendCard(sym);
  try {
    const data = await trendRequest(sym);
    trendData.set(sym, { status: 'ok', data, at: Date.now() });
  } catch (e) {
    const msg = e.message === 'Failed to fetch' ? 'ما قدرنا نوصل للخادم — تأكد من الاتصال.' : e.message;
    trendData.set(sym, { status: 'error', error: msg, code: e.code, at: Date.now() });
    if (e.code === 'no_massive') { trendQueue = []; if (!LOCAL) serverMode = { demo: false, massive: false }; }
  } finally {
    trendBusy = false;
    if (trendData.get(sym).code === 'no_massive') renderTrends(); else updateTrendCard(sym);
    pumpTrends();
  }
}

let trendsSub = load('rased.trendsSub', 'spikes') === 'trend' ? 'trend' : 'spikes';
function setTrendsSub(sub) {
  trendsSub = sub; save('rased.trendsSub', sub);
  document.querySelectorAll('.sub-btn').forEach(b => { const on = b.dataset.sub === sub; b.classList.toggle('active', on); b.setAttribute('aria-selected', String(on)); });
  $('#spikePane').classList.toggle('active', sub === 'spikes');
  $('#trendPane').classList.toggle('active', sub === 'trend');
}
document.querySelectorAll('.sub-btn').forEach(b => b.addEventListener('click', () => { setTrendsSub(b.dataset.sub); openTrends(); }));
function openTrends() {
  setTrendsSub(trendsSub);
  if (trendsSub === 'spikes') loadSpikes();
  else {
    for (const [sym, st] of trendData) if (st.status === 'error') trendData.delete(sym);
    renderTrends();
  }
  refreshLab();
}

/* --- تنسيق --- */
const AR_DAYS = { Mon: 'الاثنين', Tue: 'الثلاثاء', Wed: 'الأربعاء', Thu: 'الخميس', Fri: 'الجمعة', Sat: 'السبت', Sun: 'الأحد' };
let etFmt = null;
function etInfo(ms) {
  if (!etFmt) etFmt = new Intl.DateTimeFormat('en-US', { timeZone: 'America/New_York', weekday: 'short', year: 'numeric', month: '2-digit', day: '2-digit', hour: '2-digit', minute: '2-digit', hourCycle: 'h23' });
  const q = {};
  for (const x of etFmt.formatToParts(new Date(ms))) q[x.type] = x.value;
  return { date: `${q.year}-${q.month}-${q.day}`, day: AR_DAYS[q.weekday] || q.weekday, wd: q.weekday, time: `${q.hour === '24' ? '00' : q.hour}:${q.minute}` };
}
const rateTxt = x => Number.isFinite(+x) && x !== null ? fmt(+x <= 1 ? +x * 100 : +x, 0) + '%' : '—';
const rTxt = x => Number.isFinite(+x) && x !== null ? (+x > 0 ? '+' : '') + fmt(+x, 2) + 'R' : '—';
const usdTxt = (x, d = 0) => Number.isFinite(+x) && x !== null ? (+x < 0 ? '-$' : '$') + fmt(Math.abs(+x), d) : '—';
const pctTxt = x => Number.isFinite(+x) && x !== null ? (+x > 0 ? '+' : '') + fmt(+x, 1) + '%' : '—';

function trendChip(live) {
  if (!live) return ['none', '—'];
  switch (live.state) {
    case 'waiting': return ['wait', 'ينتظر الكسر (الاثنين)'];
    case 'entered': return ['in', 'دخلنا الصفقة'];
    case 'closed': return live.exit && live.exit.how === 'target' ? ['win', 'ضرب الهدف ✓'] : ['loss', 'ضرب الوقف ✗'];
    case 'no-signal': return ['none', 'ما فيه كسر هذا الأسبوع'];
    case 'week-over': return ['over', 'انتهى الأسبوع'];
    default: return ['none', 'ما فيه بيانات'];
  }
}

/* --- الرسم --- */
function renderTrends() {
  const mode = trendMode(), syms = trendSymbols(), hasTop = okTop5(lab.top5);
  const keyMissing = !mode.demo && !mode.massive;
  const t = lab.top5;
  $('#trendsMeta').innerHTML = hasTop
    ? `أفضل 5 أسهم استجابت لهذي الصيغة في المختبر · نتائج <span class="mono">${esc(String(t.generatedAt || '').slice(0, 10))}</span>${t.minTrades ? ` · أقل عدد صفقات ${esc(t.minTrades)}` : ''}`
    : 'أفضل 5 أسهم استجابت لهذي الصيغة في المختبر — شموع 5 دقائق، دخول الاثنين فقط';
  let notice = '';
  if (mode.demo) notice += '<div class="demo-warn">⚠️ <b>وضع تجريبي:</b> شموع الـ5 دقائق هنا <b>مصطنعة</b> عشان تشوف شكل الشارت — ما تطابق السعر الحقيقي. أضف مفتاح Massive للبيانات الحقيقية.</div>';
  if (keyMissing) notice += `<div class="tnotice"><div class="big">🔑</div><div><b>الشارت يحتاج مفتاح Massive — الإعدادات ← المفاتيح</b><div class="hint">نتائج المختبر تظهر تحت، لكن شموع الـ5 دقائق تجي من Massive بس.${LOCAL && LOCAL.setKeys ? '' : ' في الخادم: أضف MASSIVE_API_KEY في متغيرات Railway.'}</div>${LOCAL && LOCAL.setKeys ? '<button type="button" class="btn-sm" data-go="settings">افتح الإعدادات</button>' : ''}</div></div>`;
  $('#trendsNotice').innerHTML = notice;

  const cards = $('#trendCards');
  let html = '';
  if (!hasTop) {
    html += `<div class="placeholder"><div class="big">🧪</div>ما فيه نتائج اختبار بعد — المختبر يشتغل كل سبت.<br><span class="hint">أول ما يخلص الاختبار التاريخي تظهر هنا أفضل 5 أسهم مع شارت الأسبوع.</span></div>`;
    if (syms.length) html += '<div class="tsection">معاينة تجريبية — أسهم عشوائية، مو نتائج المختبر</div>';
  }
  html += syms.map((sym, i) => `<article class="pick tcard" data-sym="${esc(sym)}" data-rank="${hasTop ? i + 1 : ''}"></article>`).join('');
  cards.innerHTML = html;
  syms.forEach(updateTrendCard);
  renderPaper();

  if (keyMissing) return;
  // تحميل كسول: الطابور يبدأ بفتح التبويب، والبطاقة الظاهرة تتقدم الطابور
  if (trendObserver) trendObserver.disconnect();
  if ('IntersectionObserver' in window) {
    trendObserver = new IntersectionObserver(es => es.forEach(e => { if (e.isIntersecting) queueTrend(e.target.dataset.sym, true); }), { rootMargin: '120px' });
    cards.querySelectorAll('.tcard').forEach(c => trendObserver.observe(c));
  }
  syms.forEach(s => queueTrend(s));
}

function updateTrendCard(sym) {
  const card = document.querySelector(`.tcard[data-sym="${CSS.escape(sym)}"]`);
  if (!card) return;
  const st = trendData.get(sym), d = st && st.status === 'ok' ? st.data : null, live = d && d.live;
  const entry = okTop5(lab.top5) ? lab.top5.top.find(x => String(x.sym).toUpperCase() === sym) : null;
  const mode = trendMode(), keyMissing = !mode.demo && !mode.massive;
  const [chipCls, chipTxt] = d ? trendChip(live) : st && st.status === 'error' ? ['err', 'تعذّر الجلب'] : keyMissing ? ['none', 'بدون شارت'] : ['load', 'يحمّل…'];
  const name = d && d.profile && d.profile.name;
  const rank = card.dataset.rank;
  const stats = entry ? `<div class="tstats">
      <div><span class="n mono">${esc(entry.trades ?? '—')}</span><span class="l">صفقات</span></div>
      <div><span class="n mono">${rateTxt(entry.winRate)}</span><span class="l">نسبة الربح</span></div>
      <div><span class="n mono ${+entry.avgR > 0 ? 'pos' : +entry.avgR < 0 ? 'neg' : ''}">${rTxt(entry.avgR)}</span><span class="l">متوسط R</span></div>
      <div><span class="n mono">${entry.oos && entry.oos.trades ? rTxt(entry.oos.avgR) : '—'}</span><span class="l">خارج العينة${entry.oos && entry.oos.trades ? ` · ${esc(entry.oos.trades)}` : ''}</span></div>
    </div>${entry.why ? `<p class="hint twhy">${esc(entry.why)}</p>` : ''}` : '';

  let body;
  if (d) {
    const s = live.signal, x = live.exit;
    const levels = s ? `<div class="levels">
        <div class="lvl en"><span class="lbl">الدخول</span><span class="val">${fmt(s.entry)}</span><span class="pct">${esc(etInfo(s.entryT).day)} ${esc(etInfo(s.entryT).time)}</span></div>
        <div class="lvl tp"><span class="lbl">الهدف</span><span class="val">${fmt(s.target)}</span><span class="pct">${pctTxt(pct(s.entry, s.target))}</span></div>
        <div class="lvl sl"><span class="lbl">الوقف</span><span class="val">${fmt(s.stop)}</span><span class="pct">${pctTxt(pct(s.entry, s.stop))}</span></div>
      </div>` : '';
    let note = '';
    if (x) note = `خرجنا ${x.how === 'target' ? 'عند الهدف' : x.how === 'stop' ? 'عند الوقف' : 'بإغلاق الجمعة'} <span class="mono">${fmt(x.price)}</span> · النتيجة <b class="mono ${live.r > 0 ? 'pos' : 'neg'}">${rTxt(live.r)}</b> (<span class="mono">${pctTxt(live.pct * 100)}</span>)`;
    else if (s) note = `صفقة مفتوحة · آخر سعر <span class="mono">${fmt(live.last.price)}</span> (<span class="mono">${pctTxt(pct(s.entry, live.last.price))}</span>)`;
    else if (live.pendingBreak) note = `كسر على آخر شمعة (إغلاق <span class="mono">${fmt(live.pendingBreak.close)}</span> فوق الخط <span class="mono">${fmt(live.pendingBreak.lineValue)}</span>) — الدخول بافتتاح الشمعة التالية`;
    else if (live.line) note = `خط المقاومة الآن عند <span class="mono">${fmt(live.line.p1 + live.line.slope * (d.bars.t.length - 1 - live.line.i1))}</span> · ${esc(live.line.touches || 2)} لمسات`;
    else note = 'ما فيه خط هابط واضح على الشموع الحالية.';
    let asOf = '';
    if (d.dataAsOf) {
      const a = etInfo(d.dataAsOf), today = etInfo(Date.now()).date;
      asOf = a.date === today
        ? `آخر شمعة: ${esc(a.day)} <span class="mono">${a.date} ${a.time}</span> بتوقيت نيويورك`
        : `آخر بيانات: ${esc(a.day)} <span class="mono">${a.date} ${a.time}</span> بتوقيت نيويورك${d.demo || d.source === 'yahoo' ? '' : ' — الخطة المجانية ما فيها بيانات لحظية'}`;
      if (d.source === 'yahoo') asOf += ' · Yahoo (متأخر ~15 دقيقة)';
    }
    body = `<div class="tchart-wrap"><canvas class="tchart" data-sym="${esc(sym)}"></canvas></div>
      <div class="tlegend"><span class="lg line">خط المقاومة</span>${s ? '<span class="lg en">دخول</span><span class="lg sl">وقف</span><span class="lg tp">هدف</span>' : ''}</div>
      ${levels}
      ${d.fallback ? `<div class="demo-warn">⚠️ ${esc(d.fallback)}</div>` : ''}
      <p class="tnote">${note}</p>
      <div class="tfoot">${d.demo ? '<span class="tag yq">تجريبي</span>' : ''}<span>${asOf || 'ما فيه شموع بعد'}</span></div>`;
  } else if (st && st.status === 'error') {
    body = `<div class="tchart-wrap msg err"><div>⚠️ ${esc(st.error)}</div>${st.code === 'no_massive' ? '' : `<button type="button" class="btn-sm" data-retry="${esc(sym)}">إعادة المحاولة</button>`}</div>`;
  } else if (keyMissing) {
    body = `<div class="tchart-wrap msg"><div>الشارت يحتاج مفتاح Massive — الإعدادات ← المفاتيح</div></div>`;
  } else {
    body = `<div class="tchart-wrap msg loading"><div class="spin"></div><div>${st && st.status === 'loading' ? 'يجلب شموع 5 دقائق…' : 'بالدور — نجلب سهم سهم عشان حد الطلبات'}</div></div>`;
  }
  card.innerHTML = `
    <div class="pick-head">
      <div>
        <div class="pick-sym"><span class="sym">${esc(sym)}</span>${rank ? `<span class="rank">#${rank}</span>` : ''}</div>
        ${name ? `<div class="pick-co">${esc(name)}${d.profile.exchange ? ` <span class="exch">${esc(d.profile.exchange)}</span>` : ''}</div>` : ''}
      </div>
      <span class="tchip ${chipCls}">${chipTxt}</span>
    </div>
    ${stats}
    ${body}`;
  if (d) requestAnimationFrame(() => { const cv = card.querySelector('canvas.tchart'); if (cv) drawTrendChart(cv, d); });
}
$('#view-trends').addEventListener('click', e => {
  const r = e.target.closest('[data-retry]');
  if (r) { trendData.delete(r.dataset.retry); queueTrend(r.dataset.retry, true); return; }
  const g = e.target.closest('[data-go]');
  if (g) show(g.dataset.go);
});

function drawTrendCharts() {
  document.querySelectorAll('canvas.tchart').forEach(cv => { const st = trendData.get(cv.dataset.sym); if (st && st.data) drawTrendChart(cv, st.data); });
  const eq = document.querySelector('canvas.equity'); if (eq && lab.backtest) drawEquity(eq, lab.backtest);
  drawSpikeCharts();
}
const cssVar = (n, fb) => (getComputedStyle(document.documentElement).getPropertyValue(n) || '').trim() || fb;

function canvas2d(canvas) {
  const rect = canvas.getBoundingClientRect();
  if (!rect.width) return null;
  const dpr = window.devicePixelRatio || 1, w = rect.width, h = rect.height;
  canvas.width = Math.round(w * dpr); canvas.height = Math.round(h * dpr);
  const ctx = canvas.getContext('2d'); ctx.setTransform(dpr, 0, 0, dpr, 0, 0); ctx.clearRect(0, 0, w, h);
  return { ctx, w, h };
}
// ملصقات الأسعار على الهامش الأيمن بدون تداخل
function priceLabels(ctx, items, x0, wLab, top, bottom) {
  items.sort((a, b) => a.y - b.y);
  for (let i = 1; i < items.length; i++) if (items[i].y - items[i - 1].y < 16) items[i].y = items[i - 1].y + 16;
  const over = items.length ? items[items.length - 1].y - (bottom - 8) : 0;
  if (over > 0) items.forEach(it => { it.y -= over; });
  items.forEach(it => { if (it.y < top + 8) it.y = top + 8; });
  ctx.font = '600 10px "IBM Plex Mono", monospace'; ctx.textBaseline = 'middle'; ctx.textAlign = 'center';
  for (const it of items) {
    ctx.fillStyle = it.color; ctx.beginPath(); ctx.roundRect(x0, it.y - 8, wLab, 16, 4); ctx.fill();
    ctx.fillStyle = '#0a0d12'; ctx.fillText(it.text, x0 + wLab / 2, it.y + 0.5);
  }
}

function drawTrendChart(canvas, d) {
  const c2 = canvas2d(canvas); if (!c2) return;
  const { ctx, w, h } = c2, b = d.bars, live = d.live || {}, n = b.t ? b.t.length : 0;
  const C = { buy: cssVar('--buy', '#3fb950'), sell: cssVar('--sell', '#f0605a'), info: cssVar('--info', '#4fa3e3'), news: cssVar('--news', '#f2b134'), muted: cssVar('--muted2', '#5b6674'), border: cssVar('--border', '#232a36'), text: cssVar('--muted', '#8b96a5') };
  if (!n) { ctx.fillStyle = C.text; ctx.font = '13px "IBM Plex Sans Arabic", sans-serif'; ctx.textAlign = 'center'; ctx.fillText('ما فيه شموع', w / 2, h / 2); return; }
  // الأسبوع الأخير (+ ذيل الأسبوع الماضي إذا بدأ الخط هناك)
  const info = b.t.map(etInfo);
  const mondayKey = i => { const [y, m, dd] = info[i].date.split('-').map(Number); const k = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'].indexOf(info[i].wd); return new Date(Date.UTC(y, m - 1, dd) - k * 86400000).toISOString().slice(0, 10); };
  const lastKey = mondayKey(n - 1);
  let start = n - 1;
  while (start > 0 && mondayKey(start - 1) === lastKey) start--;
  const L = live.line, s = live.signal, x = live.exit;
  if (L && L.i1 < start) start = Math.max(0, L.i1 - 4);
  const count = n - start;
  const lineAt = i => L.p1 + L.slope * (i - L.i1);
  let lo = Infinity, hi = -Infinity;
  for (let i = start; i < n; i++) { lo = Math.min(lo, b.l[i]); hi = Math.max(hi, b.h[i]); }
  if (L) for (const i of [Math.max(start, L.i1), n - 1]) { const v = lineAt(i); if (v > 0) { lo = Math.min(lo, v); hi = Math.max(hi, v); } }
  if (s) { lo = Math.min(lo, s.stop); hi = Math.max(hi, s.target); }
  const padY = (hi - lo) * 0.06 || 1; lo -= padY; hi += padY;
  const mL = 6, mR = 56, mT = 18, mB = 8, pw = w - mL - mR, ph = h - mT - mB;
  const X = i => mL + ((i - start + 0.5) / count) * pw;
  const Y = v => mT + (1 - (v - lo) / (hi - lo)) * ph;
  const bw = Math.max(1, (pw / count) * 0.7);

  // فواصل الأيام وأسماؤها
  ctx.font = '10px "IBM Plex Sans Arabic", sans-serif'; ctx.textBaseline = 'middle'; ctx.textAlign = 'center';
  let dayStart = start;
  for (let i = start; i <= n; i++) {
    if (i < n && info[i].date === info[dayStart].date) continue;
    if (dayStart > start) { ctx.strokeStyle = C.border; ctx.lineWidth = 1; ctx.setLineDash([2, 3]); ctx.beginPath(); ctx.moveTo(X(dayStart) - pw / count / 2, mT - 4); ctx.lineTo(X(dayStart) - pw / count / 2, h - mB); ctx.stroke(); ctx.setLineDash([]); }
    const mid = (X(dayStart) + X(i - 1)) / 2;
    if (X(i - 1) - X(dayStart) > 34) { ctx.fillStyle = mondayKey(dayStart) === lastKey ? C.text : C.muted; ctx.fillText(info[dayStart].day, mid, 8); }
    dayStart = i;
  }

  // الشموع
  for (let i = start; i < n; i++) {
    const up = b.c[i] >= b.o[i];
    ctx.strokeStyle = ctx.fillStyle = up ? C.buy : C.sell; ctx.lineWidth = 1;
    if (bw > 2) { ctx.beginPath(); ctx.moveTo(X(i), Y(b.h[i])); ctx.lineTo(X(i), Y(b.l[i])); ctx.stroke(); }
    const top = Math.min(Y(b.o[i]), Y(b.c[i]));
    if (bw > 2) ctx.fillRect(X(i) - bw / 2, top, bw, Math.max(Math.abs(Y(b.c[i]) - Y(b.o[i])), 1));
    else ctx.fillRect(X(i) - bw / 2, Y(b.h[i]), bw, Math.max(Y(b.l[i]) - Y(b.h[i]), 1)); // شموع كثيفة: عمود المدى فقط
  }

  const labels = [];
  // خط المقاومة: صلب بين نقطتيه، متقطع امتداده حتى آخر شمعة
  if (L) {
    const a = Math.max(start, L.i1);
    ctx.save(); ctx.beginPath(); ctx.rect(mL, mT - 2, pw, ph + 4); ctx.clip();
    ctx.strokeStyle = C.news; ctx.lineWidth = 2;
    ctx.beginPath(); ctx.moveTo(X(a), Y(lineAt(a))); ctx.lineTo(X(L.i2), Y(lineAt(L.i2))); ctx.stroke();
    ctx.setLineDash([6, 4]); ctx.beginPath(); ctx.moveTo(X(L.i2), Y(lineAt(L.i2))); ctx.lineTo(X(n - 1), Y(lineAt(n - 1))); ctx.stroke(); ctx.setLineDash([]);
    ctx.fillStyle = C.news;
    for (const i of [L.i1, L.i2]) if (i >= start) { ctx.beginPath(); ctx.arc(X(i), Y(L.p1 + L.slope * (i - L.i1)), 3.5, 0, Math.PI * 2); ctx.fill(); }
    ctx.restore();
    if (!s) labels.push({ y: Y(lineAt(n - 1)), color: C.news, text: fmt(lineAt(n - 1)) });
  }
  // الدخول / الوقف / الهدف من شمعة الإشارة حتى النهاية
  if (s) {
    const from = X(Math.max(start, s.idx));
    const hline = (v, color, dash) => { ctx.strokeStyle = color; ctx.lineWidth = 1.5; ctx.setLineDash(dash ? [5, 4] : []); ctx.beginPath(); ctx.moveTo(from, Y(v)); ctx.lineTo(w - mR, Y(v)); ctx.stroke(); ctx.setLineDash([]); labels.push({ y: Y(v), color, text: fmt(v) }); };
    hline(s.target, C.buy); hline(s.stop, C.sell); hline(s.entry, C.info, true);
    // علامة الدخول: مثلث تحت شمعة الدخول + نقطة على سعر الدخول
    const ex = X(s.entryIdx), ey = Y(s.entry), by = Math.min(h - mB - 1, Y(b.l[s.entryIdx]) + 12);
    ctx.fillStyle = C.info; ctx.beginPath(); ctx.moveTo(ex, by - 8); ctx.lineTo(ex - 6, by + 2); ctx.lineTo(ex + 6, by + 2); ctx.closePath(); ctx.fill();
    ctx.strokeStyle = '#0a0d12'; ctx.lineWidth = 1.5; ctx.beginPath(); ctx.arc(ex, ey, 4.5, 0, Math.PI * 2); ctx.fill(); ctx.stroke();
    if (x) {
      const xc = x.how === 'target' ? C.buy : x.how === 'stop' ? C.sell : C.text;
      ctx.fillStyle = xc; ctx.beginPath(); ctx.arc(X(x.idx), Y(x.price), 4.5, 0, Math.PI * 2); ctx.fill(); ctx.stroke();
    }
  } else if (live.pendingBreak) {
    ctx.strokeStyle = C.news; ctx.lineWidth = 2; ctx.beginPath(); ctx.arc(X(live.pendingBreak.idx), Y(live.pendingBreak.close), 6, 0, Math.PI * 2); ctx.stroke();
  }
  if (!s) labels.push({ y: Y(b.c[n - 1]), color: C.text, text: fmt(b.c[n - 1]) });
  priceLabels(ctx, labels, w - mR + 3, mR - 5, mT, h - mB);
}

/* --- الحساب الوهمي --- */
function renderPaper() {
  const el = $('#paperAccount'), bt = lab.backtest;
  if (!okBacktest(bt)) {
    el.innerHTML = `<h2 class="view-title">الحساب الوهمي</h2><div class="placeholder small"><div class="big">📒</div>ما فيه نتائج اختبار بعد — المختبر يشتغل كل سبت.</div>`;
    return;
  }
  const a = bt.account || {}, weeks = bt.weeks || [];
  const dd = Number.isFinite(+a.maxDrawdownPct) && a.maxDrawdownPct !== null ? '-' + fmt(Math.abs(+a.maxDrawdownPct), 1) + '%' : '—';
  const span = bt.dataFrom && bt.dataTo ? `<span class="mono">${esc(String(bt.dataFrom).slice(0, 10))}</span> ← <span class="mono">${esc(String(bt.dataTo).slice(0, 10))}</span>` : '';
  el.innerHTML = `
    <h2 class="view-title">الحساب الوهمي</h2>
    <p class="hint">اختبار تاريخي: ${usdTxt(a.start ?? 10000)} بداية، مخاطرة 1% لكل صفقة، حتى 5 صفقات مع بعض${span ? ' · ' + span : ''}${bt.source ? ` · المصدر ${esc(bt.source)}` : ''}</p>
    <div class="pstats">
      <div class="stat wide"><div class="n">${usdTxt(a.start ?? 10000)} <span class="arrow">←</span> <b class="${+a.end >= +(a.start ?? 10000) ? 'pos' : 'neg'}">${usdTxt(a.end)}</b></div><div class="l">رأس المال: البداية ← النهاية</div></div>
      <div class="stat"><div class="n ${+a.returnPct > 0 ? 'pos' : +a.returnPct < 0 ? 'neg' : ''}">${pctTxt(a.returnPct)}</div><div class="l">العائد</div></div>
      <div class="stat"><div class="n neg">${dd}</div><div class="l">أقصى تراجع</div></div>
      <div class="stat"><div class="n">${rateTxt(a.winRate)}</div><div class="l">نسبة الربح${a.trades ? ` · ${esc(a.trades)} صفقة` : ''}</div></div>
    </div>
    ${weeks.length ? `<div class="card"><div class="card-title">رأس المال نهاية كل أسبوع</div><canvas class="equity"></canvas></div>
    <div class="card wtable-card"><div class="card-title">الأسابيع (${weeks.length})</div><div class="wtable" role="table">
      <div class="wrow wh" role="row"><span>الأسبوع</span><span>صفقات</span><span>رابحة</span><span>الربح/الخسارة</span></div>
      ${weeks.slice().reverse().map(wk => `<div class="wrow" role="row"><span class="mono">${esc(String(wk.weekKey || '').slice(0, 10))}</span><span class="mono">${esc(wk.trades ?? 0)}</span><span class="mono">${esc(wk.wins ?? 0)}</span><span class="mono ${+wk.pnl > 0 ? 'pos' : +wk.pnl < 0 ? 'neg' : ''}">${+wk.pnl > 0 ? '+' : ''}${usdTxt(wk.pnl)}</span></div>`).join('')}
    </div></div>` : ''}`;
  requestAnimationFrame(() => { const cv = el.querySelector('canvas.equity'); if (cv) drawEquity(cv, bt); });
}

function drawEquity(canvas, bt) {
  const c2 = canvas2d(canvas); if (!c2) return;
  const { ctx, w, h } = c2, weeks = bt.weeks || [], start = +((bt.account && bt.account.start) ?? 10000);
  const pts = [start, ...weeks.map(wk => +wk.equityEnd)].filter(Number.isFinite);
  if (pts.length < 2) return;
  const liq = cssVar('--liq', '#2dd4bf'), muted = cssVar('--muted2', '#5b6674'), text = cssVar('--muted', '#8b96a5'), sell = cssVar('--sell', '#f0605a');
  let lo = Math.min(...pts), hi = Math.max(...pts); const pad = (hi - lo) * 0.1 || start * 0.01; lo -= pad; hi += pad;
  const mL = 8, mR = 58, mT = 8, mB = 18, pw = w - mL - mR, ph = h - mT - mB;
  const X = i => mL + (i / (pts.length - 1)) * pw, Y = v => mT + (1 - (v - lo) / (hi - lo)) * ph;
  // خط البداية
  ctx.strokeStyle = muted; ctx.setLineDash([4, 4]); ctx.lineWidth = 1; ctx.beginPath(); ctx.moveTo(mL, Y(start)); ctx.lineTo(w - mR, Y(start)); ctx.stroke(); ctx.setLineDash([]);
  // مساحة + خط
  const g = ctx.createLinearGradient(0, mT, 0, h - mB); g.addColorStop(0, 'rgba(45,212,191,.28)'); g.addColorStop(1, 'rgba(45,212,191,0)');
  ctx.beginPath(); pts.forEach((v, i) => i ? ctx.lineTo(X(i), Y(v)) : ctx.moveTo(X(i), Y(v))); ctx.lineTo(X(pts.length - 1), h - mB); ctx.lineTo(X(0), h - mB); ctx.closePath(); ctx.fillStyle = g; ctx.fill();
  ctx.beginPath(); pts.forEach((v, i) => i ? ctx.lineTo(X(i), Y(v)) : ctx.moveTo(X(i), Y(v))); ctx.strokeStyle = liq; ctx.lineWidth = 2; ctx.stroke();
  const last = pts[pts.length - 1];
  ctx.fillStyle = last >= start ? liq : sell; ctx.beginPath(); ctx.arc(X(pts.length - 1), Y(last), 3.5, 0, Math.PI * 2); ctx.fill();
  priceLabels(ctx, [{ y: Y(last), color: last >= start ? liq : sell, text: '$' + fmt(last, 0) }, { y: Y(start), color: muted, text: '$' + fmt(start, 0) }], w - mR + 3, mR - 5, mT, h - mB);
  ctx.fillStyle = text; ctx.font = '10px "IBM Plex Mono", monospace'; ctx.textBaseline = 'middle';
  const first = weeks[0] && String(weeks[0].weekKey || '').slice(0, 10), end = weeks[weeks.length - 1] && String(weeks[weeks.length - 1].weekKey || '').slice(0, 10);
  ctx.textAlign = 'left'; if (first) ctx.fillText(first, mL, h - 7);
  ctx.textAlign = 'right'; if (end) ctx.fillText(end, w - mR, h - 7);
}

/* ---------- انفجار السيولة ---------- */
// المصدر: حساب محلي من مخزن Massive (إن وُجد بأيام كافية) ← المسح الليلي spikes-today.json (مضمّن / محدّث من GitHub)
// ← سوق تجريبي (بدون أي بيانات). فلتر يقين بنفس قاعدة المسح الرئيسي (applyYaqeen في server/).
let spikeState = null; // { data } | { error }
let spikeSeq = 0;
const spikesOpen = () => trendsOpen() && trendsSub === 'spikes';
const AR_WD = ['الأحد', 'الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت'];
const dayAr = d => { const t = Date.parse(String(d) + 'T12:00:00Z'); return Number.isFinite(t) ? `${AR_WD[new Date(t).getUTCDay()]} <span class="mono">${esc(d)}</span>` : esc(d || '—'); };
const px = v => { const x = +v; return !Number.isFinite(x) ? '—' : x < 1 ? fmt(x, 4) : x < 10 ? fmt(x, 3) : fmt(x, 2); };
const bigNum = v => { const x = +v; return !Number.isFinite(x) ? '—' : x >= 1e9 ? fmt(x / 1e9, 1) + 'B' : x >= 1e6 ? fmt(x / 1e6, 1) + 'M' : x >= 1e3 ? fmt(x / 1e3, 0) + 'K' : fmt(x, 0); };

async function spikesRequest() {
  const req = { yaqeen: settings.yaqeen, excludeHaram: settings.excludeHaram, excludeMashbooh: settings.excludeMashbooh, nightly: lab.spikesToday || null };
  if (LOCAL) {
    if (!LOCAL.spikes) throw new Error('هذي النسخة ما فيها انفجار السيولة.');
    return LOCAL.spikes(req);
  }
  const res = await fetch('api/spikes', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(req), cache: 'no-store' });
  const data = await res.json().catch(() => ({}));
  if (!res.ok) throw new Error(data.error || `الخادم رد بالحالة ${res.status}`);
  return data;
}

async function loadSpikes() {
  const seq = ++spikeSeq;
  if (!spikeState) $('#spikeCards').innerHTML = '<div class="skeleton"></div>';
  renderSpikeLab();
  try {
    const data = await spikesRequest();
    if (seq !== spikeSeq) return;
    spikeState = { data };
  } catch (e) {
    if (seq !== spikeSeq) return;
    spikeState = { error: e.message === 'Failed to fetch' ? 'ما قدرنا نوصل للخادم — تأكد من الاتصال.' : e.message };
  }
  renderSpikes();
}

function renderSpikeLab() {
  const el = $('#spikeLab'), sp = lab.spike;
  if (!sp || !sp.default) { el.innerHTML = ''; return; }
  const d = sp.default, wf = sp.walkForward, out = wf && wf.defaults && wf.defaults.outSample;
  el.innerHTML = `<section class="spike-lab" aria-label="نتيجة المختبر">
    <div class="t">🧪 نتيجة المختبر للصيغة الافتراضية (دخول بالافتتاح، ${esc(sp.defaultKey ? (sp.defaultKey.match(/-h(\d+)-/) || [])[1] || '3' : '3')} أيام، وقف تحت أدنى يوم الإشارة) · بيانات <span class="mono">${esc(sp.dataFrom || '?')}</span> → <span class="mono">${esc(sp.dataTo || '?')}</span></div>
    <div class="tstats">
      <div><span class="n mono">${rateTxt(d.winRate)}</span><span class="l">نسبة الربح</span></div>
      <div><span class="n mono ${+d.avgRet > 0 ? 'pos' : +d.avgRet < 0 ? 'neg' : ''}">${Number.isFinite(+d.avgRet) && d.avgRet !== null ? pctTxt(d.avgRet * 100) : '—'}</span><span class="l">متوسط العائد</span></div>
      <div><span class="n mono">${esc(d.trades ?? '—')}</span><span class="l">صفقات</span></div>
    </div>
    ${out && out.trades ? `<p class="hint">خارج العينة (الأشهر الأحدث): <span class="mono">${esc(out.trades)}</span> صفقة · ربح <span class="mono">${rateTxt(out.winRate)}</span> · متوسط <span class="mono">${pctTxt(out.avgRet * 100)}</span></p>` : ''}
    <p class="hint">قبل الانزلاق والعمولات. فيها انحياز بقاء (الأسهم المشطوبة غير موجودة) — الواقع غالبًا أسوأ.</p>
  </section>`;
}

function renderSpikes() {
  renderSpikeLab();
  const meta = $('#spikesMeta'), notice = $('#spikesNotice'), cards = $('#spikeCards');
  if (!spikeState) return;
  if (spikeState.error) {
    notice.innerHTML = '';
    cards.innerHTML = `<div class="placeholder"><div class="big">⚠️</div>${esc(spikeState.error)}<br><button type="button" class="btn-sm" data-spike-retry>إعادة المحاولة</button></div>`;
    return;
  }
  const d = spikeState.data;
  let n = '';
  if (d.source === 'demo') n += '<div class="demo-warn">⚠️ <b>وضع تجريبي:</b> هذي رموز وأسعار <b>مصطنعة</b> (DSP…) عشان تشوف شكل الإشارة — مو السوق الحقيقي. الإشارات الحقيقية تجي من المسح الليلي بعد كل إغلاق.</div>';
  if (d.day && d.source !== 'demo') {
    const age = Math.floor((Date.now() - Date.parse(d.day + 'T21:00:00Z')) / 86400000);
    if (age > 4) n += `<div class="demo-warn">⚠️ آخر بيانات من <span class="mono">${esc(d.day)}</span> (قبل ${age} أيام) — المسح الليلي ما تحدّث. الإشارات قديمة؛ لا تدخل على أساسها.</div>`;
  }
  notice.innerHTML = n;
  const src = d.source === 'local' ? 'محسوب على جهازك من أيام السوق المخزّنة (Massive)'
    : d.source === 'nightly' ? `من المسح الليلي على GitHub (${esc(d.dataSource === 'massive' ? 'Massive' : 'Yahoo')})`
    : d.source === 'demo' ? 'بيانات تجريبية' : '';
  meta.innerHTML = d.day
    ? `إشارات إغلاق ${dayAr(d.day)} · ${src}${d.generatedAt && d.source === 'nightly' ? ` · حُدّث <span class="mono">${esc(String(d.generatedAt).slice(0, 16).replace('T', ' '))} UTC</span>` : ''}`
    : 'أسهم صغيرة رخيصة انفجر حجمها وكسرت قاعدتها — شراء فقط، والخروج بالوقت';
  if (d.source === 'none' || !d.day) {
    cards.innerHTML = `<div class="placeholder"><div class="big">🌙</div>ما فيه بيانات بعد.<br><span class="hint">المسح الليلي يشتغل بعد كل إغلاق للسوق الأمريكي (الإثنين–الجمعة، ~12:30 ليلًا بتوقيت السعودية) ويحدّث هذي الصفحة تلقائيًا — بدون أي مفتاح.</span></div>`;
    return;
  }
  const ex = Object.keys(d.yaqeenExcluded || {}).length;
  const exLine = ex ? `<p class="hint">استُبعد ${ex} سهم بفلتر يقين: ${Object.entries(d.yaqeenExcluded).map(([s, v]) => `<span class="mono">${esc(s)}</span> (${esc(v)})`).join('، ')}</p>` : '';
  if (!d.signals.length) {
    cards.innerHTML = `<div class="placeholder"><div class="big">🔍</div>ما فيه سهم انفجرت سيولته بالشروط كاملة بإغلاق ${dayAr(d.day)}.<br><span class="hint">هذا طبيعي — الإشارة نادرة (قد تمر أيام بدون أي سهم).</span></div>${exLine}`;
    return;
  }
  cards.innerHTML = `<div class="sdate">${d.signals.length} ${d.signals.length === 1 ? 'إشارة' : d.signals.length === 2 ? 'إشارتين' : 'إشارات'} · الأعلى مضاعف حجم أولاً</div>`
    + d.signals.map((s, i) => spikeCardHtml(s, i, d)).join('') + exLine;
  requestAnimationFrame(drawSpikeCharts);
}

function spikeCardHtml(s, i, d) {
  const yq = s.yaqeen && s.yaqeen !== 'غير معروف' ? `<span class="yq ${yqClass(s.yaqeen)}">يقين: ${esc(s.yaqeen)}</span>` : '';
  const stop = d.params && d.params.stop === false ? '' : `، حماية تحت <b class="mono">${px(s.lowD)}</b>`;
  return `<article class="pick scard" data-i="${i}">
    <div class="pick-head">
      <div>
        <div class="pick-sym"><span class="sym">${esc(s.sym)}</span><span class="rank">#${i + 1}</span></div>
        ${s.name || s.exchange ? `<div class="pick-co">${esc(s.name || '')}${s.exchange ? ` <span class="exch">${esc(s.exchange)}</span>` : ''}</div>` : ''}
      </div>
      <span class="tchip win"><span class="mono">+${fmt(s.chgPct, 1)}%</span></span>
    </div>
    <div class="stats5">
      <div><span class="n pos">${pctTxt(s.chgPct)}</span><span class="l">تغير اليوم</span></div>
      <div><span class="n">×${fmt(s.volMult, 0)}</span><span class="l">مضاعف الحجم</span></div>
      <div><span class="n">${px(s.close)}</span><span class="l">الإغلاق</span></div>
      <div><span class="n hi">${px(s.highD)}</span><span class="l">أعلى اليوم</span></div>
      <div><span class="n lo">${px(s.lowD)}</span><span class="l">أدنى اليوم</span></div>
      <div><span class="n">${bigNum(s.volume)}</span><span class="l">الحجم</span></div>
    </div>
    <div class="plan">ادخل عند افتتاح يوم ${dayAr(s.entryDate)}، اخرج بإغلاق يوم ${dayAr(s.exitDate)}${stop}</div>
    <canvas class="schart" data-i="${i}" aria-label="شارت يومي آخر 40 يوم لـ ${esc(s.sym)}"></canvas>
    <div class="sfoot">
      <a class="chip-link" href="https://yaaqen.com/stocks/${encodeURIComponent(s.sym)}" target="_blank" rel="noopener">☪︎ تحقق في يقين ↗</a>
      ${yq}
      <a class="chip-link" href="${quoteUrl(s.sym)}" target="_blank" rel="noopener">Yahoo ↗</a>
      ${d.source === 'demo' ? '<span class="tag yq">تجريبي</span>' : ''}
    </div>
  </article>`;
}

$('#spikePane').addEventListener('click', e => { if (e.target.closest('[data-spike-retry]')) { spikeState = null; loadSpikes(); } });

function drawSpikeCharts() {
  if (!spikeState || !spikeState.data) return;
  document.querySelectorAll('canvas.schart').forEach(cv => { const s = spikeState.data.signals[+cv.dataset.i]; if (s) drawSpikeChart(cv, s); });
}

// شموع يومية (آخر 40 يوم) + حجم تحت، يوم الإشارة مظلل، وخطا أعلى/أدنى يوم الإشارة
function drawSpikeChart(canvas, s) {
  const c2 = canvas2d(canvas); if (!c2) return;
  const { ctx, w, h } = c2, b = s.bars40 || {}, n = b.c ? b.c.length : 0;
  const C = { buy: cssVar('--buy', '#3fb950'), sell: cssVar('--sell', '#f0605a'), info: cssVar('--info', '#4fa3e3'), news: cssVar('--news', '#f2b134'), muted: cssVar('--muted2', '#5b6674'), text: cssVar('--muted', '#8b96a5') };
  if (!n) { ctx.fillStyle = C.text; ctx.font = '13px "IBM Plex Sans Arabic", sans-serif'; ctx.textAlign = 'center'; ctx.fillText('ما فيه شموع', w / 2, h / 2); return; }
  const mL = 6, mR = 58, mT = 10, mB = 16, volH = Math.round((h - mT - mB) * 0.22), pw = w - mL - mR, ph = h - mT - mB - volH - 6;
  let lo = Infinity, hi = -Infinity, vmax = 0;
  for (let i = 0; i < n; i++) { lo = Math.min(lo, b.l[i]); hi = Math.max(hi, b.h[i]); vmax = Math.max(vmax, (b.v && b.v[i]) || 0); }
  const pad = (hi - lo) * 0.06 || hi * 0.02 || 1; lo -= pad; hi += pad;
  const X = i => mL + ((i + 0.5) / n) * pw, Y = v => mT + (1 - (v - lo) / (hi - lo)) * ph;
  const bw = Math.max(2, (pw / n) * 0.62), vy0 = h - mB;
  // يوم الإشارة: عمود مظلل
  const sx = X(n - 1);
  ctx.fillStyle = 'rgba(242,177,52,.14)'; ctx.fillRect(sx - pw / n / 2 - 1, mT, pw / n + 2, vy0 - mT);
  for (let i = 0; i < n; i++) {
    const up = b.c[i] >= b.o[i], col = up ? C.buy : C.sell;
    ctx.strokeStyle = ctx.fillStyle = col; ctx.lineWidth = 1;
    ctx.beginPath(); ctx.moveTo(X(i), Y(b.h[i])); ctx.lineTo(X(i), Y(b.l[i])); ctx.stroke();
    const top = Math.min(Y(b.o[i]), Y(b.c[i]));
    ctx.fillRect(X(i) - bw / 2, top, bw, Math.max(Math.abs(Y(b.c[i]) - Y(b.o[i])), 1));
    if (b.v && vmax > 0) {
      const vh = Math.max(1, Math.sqrt(b.v[i] / vmax) * volH); // جذر: يوم الانفجار ما يخفي باقي الأيام
      ctx.globalAlpha = i === n - 1 ? 0.95 : 0.45; ctx.fillRect(X(i) - bw / 2, vy0 - vh, bw, vh); ctx.globalAlpha = 1;
    }
  }
  const hline = (v, color) => { ctx.strokeStyle = color; ctx.lineWidth = 1.2; ctx.setLineDash([5, 4]); ctx.beginPath(); ctx.moveTo(mL, Y(v)); ctx.lineTo(w - mR, Y(v)); ctx.stroke(); ctx.setLineDash([]); };
  hline(s.highD, C.info); hline(s.lowD, C.sell);
  // سهم فوق شمعة الإشارة
  ctx.fillStyle = C.news; ctx.beginPath(); const ay = Math.max(mT + 2, Y(b.h[n - 1]) - 10);
  ctx.moveTo(sx, ay + 7); ctx.lineTo(sx - 5, ay); ctx.lineTo(sx + 5, ay); ctx.closePath(); ctx.fill();
  priceLabels(ctx, [{ y: Y(s.highD), color: C.info, text: px(s.highD) }, { y: Y(s.lowD), color: C.sell, text: px(s.lowD) }], w - mR + 3, mR - 5, mT, mT + ph);
  ctx.fillStyle = C.text; ctx.font = '10px "IBM Plex Mono", monospace'; ctx.textBaseline = 'middle';
  const dstr = t => new Date(t).toISOString().slice(5, 10);
  ctx.direction = 'ltr';
  ctx.textAlign = 'left'; ctx.fillText(dstr(b.t[0]), mL, h - 7);
  ctx.textAlign = 'right'; ctx.fillStyle = C.news; ctx.fillText(dstr(b.t[n - 1]), w - mR, h - 7);
  const dw = ctx.measureText(dstr(b.t[n - 1])).width;
  ctx.font = '10px "IBM Plex Sans Arabic", sans-serif'; ctx.direction = 'rtl'; ctx.textAlign = 'right';
  ctx.fillText('يوم الإشارة', w - mR - dw - 6, h - 7);
}

/* ---------- keys (تطبيق الأندرويد) ---------- */
function renderKeys() {
  if (!LOCAL || !LOCAL.setKeys) return;
  const k = LOCAL.keys();
  $('#keysCard').hidden = false;
  $('#massiveKeyState').textContent = k.massive ? '· محفوظ ✓' : '· غير موجود';
  $('#alphaKeyState').textContent = k.alpha ? '· محفوظ ✓' : '· غير موجود';
}
$('#keysCard').addEventListener('submit', e => {
  e.preventDefault();
  const m = $('#massiveKey').value.trim(), a = $('#alphaKey').value.trim();
  if (!m && !a) return toast('الصق مفتاح واحد على الأقل.', 'err');
  LOCAL.setKeys({ massive: m || LOCAL.rawKeys().massive, alpha: a || LOCAL.rawKeys().alpha });
  $('#massiveKey').value = ''; $('#alphaKey').value = '';
  trendData.clear(); trendQueue = []; // شموع الاتجاهات تُعاد بالمفتاح الجديد
  renderKeys(); refreshStatusOnce(); toast('انحفظت المفاتيح. المزامنة بدأت — شوف الإشارة فوق.', 'ok');
});
renderKeys();

/* ---------- mode badge: إشارة أحمر / أصفر / أخضر ---------- */
// الخادم يحسب الإشارات (server/status.js). النسخة المستقلة دائمًا تجريبية.
const LOCAL_STATUS = { level: 'red', badge: 'تجريبي', lights: [
  { level: 'red', label: 'هذي نسخة التجربة — الأسعار مصطنعة دائمًا', fix: 'الأسعار الحقيقية في رابط تطبيقك على Railway (…up.railway.app)، مو هذا الرابط.' },
] };
function setStatus(st) {
  const b = $('#modeBadge');
  b.className = 'pill ' + st.level; b.querySelector('span').textContent = st.badge;
  const canSync = LOCAL && LOCAL.syncNow && LOCAL.keys().massive;
  $('#statusPanel').innerHTML = `<div class="st-title">حالة التطبيق</div>` + st.lights.map(l => `
    <div class="st-row"><i class="dot ${l.level}"></i><div><div class="st-label">${esc(l.label)}</div>${l.fix ? `<div class="st-fix">${esc(l.fix)}</div>` : ''}</div></div>`).join('')
    + (canSync ? '<button type="button" class="btn-sm" id="syncNowBtn">مزامنة الآن</button>' : '');
}
$('#statusPanel').addEventListener('click', e => {
  if (e.target.id !== 'syncNowBtn') return;
  LOCAL.syncNow(); toast('بدأت المزامنة…'); setTimeout(refreshStatusOnce, 300);
});
const refreshStatusOnce = () => LOCAL && LOCAL.status && setStatus(LOCAL.status());
$('#modeBadge').addEventListener('click', () => {
  const p = $('#statusPanel'); p.hidden = !p.hidden; $('#modeBadge').setAttribute('aria-expanded', String(!p.hidden));
});
function refreshHealth() {
  if (LOCAL && LOCAL.status) { setStatus(LOCAL.status()); return setTimeout(refreshHealth, 2000); } // تطبيق الأندرويد
  if (LOCAL) return setStatus(LOCAL_STATUS);
  fetch('api/health').then(r => r.json()).then(h => {
    setStatus(h.status || { level: h.demo ? 'red' : 'green', badge: h.demo ? 'تجريبي' : 'حقيقي', lights: [] });
    const m = { demo: !!h.demo && !h.yahoo, massive: !!h.demo || !!h.market || !!h.yahoo, yahoo: !!h.yahoo };
    if (!serverMode || serverMode.demo !== m.demo || serverMode.massive !== m.massive || serverMode.yahoo !== m.yahoo) { serverMode = m; if (trendsOpen()) renderTrends(); }
  }).catch(() => setStatus({ level: 'red', badge: 'غير متصل', lights: [{ level: 'red', label: 'ما قدرت أوصل للخادم', fix: 'تأكد إن خدمة Railway شغالة وإن الإنترنت عندك شغال.' }] }))
    .finally(() => setTimeout(refreshHealth, 60000)); // الإشارة تتحدث كل دقيقة (تقدّم التعبئة، يوم جديد، أخطاء)
}
refreshHealth();

/* ---------- boot ---------- */
renderHome(); renderList(); renderYaqeen(); renderSettings();
// النسخة المستقلة التجريبية تفتح على نتيجة جاهزة بدل شاشة فاضية
if (LOCAL && !LOCAL.status && !lastScan) $('#scanBtn').click();
if (!LOCAL && 'serviceWorker' in navigator) navigator.serviceWorker.register('sw.js').catch(() => {});
