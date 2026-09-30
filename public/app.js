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
  $('#scanBtn').hidden = view === 'settings' || view === 'yaqeen';
  window.scrollTo({ top: 0 });
  if (view === 'home') requestAnimationFrame(drawCharts);
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
window.addEventListener('resize', () => { clearTimeout(resizeTimer); resizeTimer = setTimeout(drawCharts, 120); });

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
  }).catch(() => setStatus({ level: 'red', badge: 'غير متصل', lights: [{ level: 'red', label: 'ما قدرت أوصل للخادم', fix: 'تأكد إن خدمة Railway شغالة وإن الإنترنت عندك شغال.' }] }))
    .finally(() => setTimeout(refreshHealth, 60000)); // الإشارة تتحدث كل دقيقة (تقدّم التعبئة، يوم جديد، أخطاء)
}
refreshHealth();

/* ---------- boot ---------- */
renderHome(); renderList(); renderYaqeen(); renderSettings();
// النسخة المستقلة التجريبية تفتح على نتيجة جاهزة بدل شاشة فاضية
if (LOCAL && !LOCAL.status && !lastScan) $('#scanBtn').click();
if (!LOCAL && 'serviceWorker' in navigator) navigator.serviceWorker.register('sw.js').catch(() => {});
