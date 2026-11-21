// ورقة إجابة للتظليل اليدوي (بتصميم الموقع وبلا شعارات جهات أخرى) قابلة للمسح الضوئي والتصحيح الآلي.
// كل العناصر بإحداثيات ثابتة بالمليمتر داخل صفحة 194×281؛ والماسح الضوئي (omr-scan.js) يستعمل الإحداثيات نفسها،
// فأي تعديل هنا يغيّر الماسح أيضاً. أربع علامات سوداء 6×6 في الزوايا يُحسب منها التحويل الهندسي للصورة.
const LETTERS = ['أ', 'ب', 'ج', 'د'];
export const OMR_PER_COLUMN = 15;
export const OMR_COLUMNS = 4;
export const OMR_PER_PAGE = OMR_PER_COLUMN * OMR_COLUMNS;
export const SHEET = { W: 194, H: 281, MARK: 6, BUBBLE: 5 };
// مراكز علامات الزوايا (يسار-أعلى، يمين-أعلى، يسار-أسفل، يمين-أسفل)
export const MARKS = [[3, 3], [191, 3], [3, 278], [191, 278]];

export const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]);

/** مراكز دوائر رقم السجل: [موضع الرقم 0..9 من اليسار][القيمة 0..9] → {x,y} (مم). */
export function idCenters() {
    return Array.from({ length: 10 }, (_, i) => Array.from({ length: 10 }, (_, v) => ({ x: 52 + i * 10, y: 77 + v * 5.4 })));
}
/** مراكز دوائر الإجابات: [رقم السؤال 0..n-1][الخيار 0..3 (أ ب ج د)] → {x,y} (مم). السؤال 1 أعلى العمود الأيمن. */
export function answerCenters(n) {
    return Array.from({ length: n }, (_, q) => {
        const col = Math.floor(q / OMR_PER_COLUMN), row = q % OMR_PER_COLUMN;
        const xr = 188 - col * 46.5;
        return LETTERS.map((_, j) => ({ x: xr - 17 - j * 8.4, y: 150 + row * 6 }));
    });
}
const numCenter = (q) => ({ x: 188 - Math.floor(q / OMR_PER_COLUMN) * 46.5 - 6, y: 150 + (q % OMR_PER_COLUMN) * 6 });

const CSS = `
@page{size:A4 portrait;margin:8mm}
*{box-sizing:border-box}
body{margin:0;font-family:'Cairo','Noto Naskh Arabic','Tahoma',sans-serif;color:#000;background:#fff}
.page{position:relative;width:194mm;height:281mm;margin:0 auto;page-break-after:always;overflow:hidden}
.page:last-child{page-break-after:auto}
.a{position:absolute}
.mk{position:absolute;width:6mm;height:6mm;background:#000}
.c{transform:translate(-50%,-50%);text-align:center;white-space:nowrap}
h1{position:absolute;left:0;right:0;top:9mm;margin:0;text-align:center;font-size:16pt}
.sub{position:absolute;left:8mm;right:8mm;top:20mm;text-align:center;font-size:10pt;font-weight:700}
.box{position:absolute;border:1.2px solid #000;border-radius:3mm;padding:1.5mm 3mm;font-size:11pt;font-weight:700}
.l{font-weight:400}
.b{position:absolute;width:5mm;height:5mm;margin:-2.5mm 0 0 -2.5mm;border:1px solid #000;border-radius:50%;font-size:7pt;line-height:4.6mm;text-align:center;font-weight:700}
.bd{font-size:6.5pt;font-weight:400}
.idw{position:absolute;width:7mm;height:7mm;margin:-3.5mm 0 0 -3.5mm;border:1px solid #000}
.bar{position:absolute;left:8mm;right:6mm;top:134mm;height:8mm;background:#0f766e;color:#fff;text-align:center;font-weight:800;border-radius:3mm;line-height:8mm;font-size:11pt;-webkit-print-color-adjust:exact;print-color-adjust:exact}
.col{position:absolute;border:1.2px solid #000;border-radius:3mm;top:145mm;height:94mm}
.qn{position:absolute;width:7mm;height:5mm;margin:-2.5mm 0 0 -3.5mm;text-align:center;font-weight:800;font-size:9pt;border:1px solid #000;border-radius:1mm;line-height:4.6mm}
.ft{position:absolute;bottom:9mm;left:0;right:0;text-align:center;font-size:8pt}
.note{position:absolute;left:8mm;right:8mm;top:243mm;font-size:8.5pt;text-align:center;line-height:1.8}
.key td,.key th{border:1px solid #000;padding:1mm 2mm;text-align:center;font-size:11pt}
.key{border-collapse:collapse;width:100%;margin-top:3mm}
`;

const at = (cls, x, y, inner, extra = '') => `<div class="${cls}" style="left:${x}mm;top:${y}mm;${extra}">${inner}</div>`;

/** ورقة إجابة (صفحة واحدة، حتى 60 سؤالاً). */
export function omrSheetHtml({ title, className = '', subjectName = '', count }) {
    const n = Math.max(1, Math.min(Number(count) || 1, OMR_PER_PAGE));
    let body = MARKS.map(([x, y]) => `<i class="mk" style="left:${x - 3}mm;top:${y - 3}mm"></i>`).join('');
    body += `<h1>ورقة الإجابة — ${esc(title)}</h1><div class="sub">${esc(subjectName)}${subjectName && className ? ' · ' : ''}${esc(className)} · ${n} سؤالاً</div>`;
    body += `<div class="box" style="left:8mm;right:6mm;top:30mm;height:10mm">الاسم الرباعي: <span class="l">.....................................................................................................</span></div>`;
    body += `<div class="box" style="left:8mm;width:84mm;top:42mm;height:10mm">المدرسة: <span class="l">...........................</span></div>`;
    body += `<div class="box" style="left:96mm;right:6mm;top:42mm;height:10mm">الصف والفصل: <span class="l">....................</span></div>`;
    body += `<div class="box" style="left:8mm;right:6mm;top:55mm;height:74mm"></div>`;
    body += at('a c', 97, 59.5, '<b style="font-size:9.5pt">رقم السجل المدني / الإقامة: اكتب الرقم في الخانات ثم ظلّل الدائرة تحت كل رقم</b>');
    const ids = idCenters();
    for (let i = 0; i < 10; i++) {
        body += `<div class="idw" style="left:${ids[i][0].x}mm;top:69mm"></div>`;
        for (let v = 0; v < 10; v++) body += `<div class="b bd" style="left:${ids[i][v].x}mm;top:${ids[i][v].y}mm">${v}</div>`;
    }
    body += `<div class="bar">إجابات الأسئلة 1 – ${n}</div>`;
    const cols = Math.ceil(n / OMR_PER_COLUMN);
    for (let c = 0; c < cols; c++) body += `<div class="col" style="left:${188 - c * 46.5 - 45}mm;width:45mm"></div>`;
    const ans = answerCenters(n);
    for (let q = 0; q < n; q++) {
        const nc = numCenter(q);
        body += `<div class="qn" style="left:${nc.x}mm;top:${nc.y}mm">${q + 1}</div>`;
        ans[q].forEach((p, j) => { body += `<div class="b" style="left:${p.x}mm;top:${p.y}mm">${LETTERS[j]}</div>`; });
    }
    body += `<div class="note">ظلّل الدائرة كاملة بقلم رصاص أو حبر غامق، ودائرة واحدة فقط لكل سؤال. لا تثنِ الورقة ولا تكتب على علامات الزوايا السوداء.</div>`;
    body += `<div class="ft">مهارات اختبارات نافس</div>`;
    return wrap(`ورقة إجابة — ${title}`, `<section class="page">${body}</section>`);
}

/** مفتاح التصحيح للمعلم (يُطبع منفصلاً ولا يُعطى للطلاب). answers: أرقام 0-3. */
export function omrKeyHtml({ title, className = '', answers }) {
    const rows = [];
    for (let i = 0; i < answers.length; i += 10) {
        let tr = '';
        for (let j = i; j < Math.min(i + 10, answers.length); j++) tr += `<th>${j + 1}</th>`;
        let td = '';
        for (let j = i; j < Math.min(i + 10, answers.length); j++) td += `<td>${LETTERS[answers[j]] ?? '؟'}</td>`;
        rows.push(`<tr>${tr}</tr><tr>${td}</tr>`);
    }
    return wrap(`مفتاح التصحيح — ${title}`, `<section class="page"><h1>مفتاح التصحيح — ${esc(title)}</h1><div class="sub">${esc(className)} · للمعلم فقط</div><table class="key">${rows.join('')}</table></section>`);
}

function wrap(title, body) {
    return `<!doctype html><html lang="ar" dir="rtl"><head><meta charset="utf-8"><title>${esc(title)}</title><style>${CSS}</style></head><body>${body}</body></html>`;
}

const BOOK_CSS = `
@page{size:A4 portrait;margin:12mm}
*{box-sizing:border-box}
body{margin:0;font-family:'Cairo','Noto Naskh Arabic','Tahoma',sans-serif;color:#000;background:#fff;font-size:12pt}
.top{border-bottom:2px solid #000;margin-bottom:5mm;padding-bottom:3mm}
h1{margin:0 0 1mm;font-size:18pt}.meta{font-size:11pt;font-weight:700}
.nm{display:flex;gap:6mm;margin-top:3mm;font-size:11pt}.nm span{flex:1;border-bottom:1px dotted #000;padding-bottom:1mm}
.q{break-inside:avoid;page-break-inside:avoid;margin:0 0 5mm;display:flex;gap:3mm;align-items:flex-start}
.q .n{flex:none;width:9mm;height:9mm;border:1.5px solid #000;border-radius:50%;text-align:center;line-height:8mm;font-weight:800;font-size:11pt}
.q .c{flex:1;min-width:0}
.q img{max-width:100%;height:auto;display:block}
.ps{break-inside:avoid;margin:0 0 5mm;border:1px solid #000;border-radius:2mm;padding:2mm}
.ps img{max-width:100%;height:auto;display:block}
.ps p{margin:0 0 2mm;line-height:1.9;text-align:justify}
.pl{font-weight:800;font-size:10.5pt;margin-bottom:1.5mm}
.opt{margin:1mm 0}
.opt b{display:inline-block;min-width:8mm}
`;

/** كتيّب أسئلة مطبوع. questions: [{text, options, image, passageImage}] ؛ baseUrl لتحويل مسارات الصور إلى مطلقة. */
export function bookletHtml({ title, className = '', subjectName = '', passageText = '', questions, baseUrl = '' }) {
    const abs = (p) => (baseUrl ? new URL(p, baseUrl).href : p);
    let body = `<div class="top"><h1>${esc(title)}</h1><div class="meta">${esc(subjectName)}${subjectName && className ? ' · ' : ''}${esc(className)} · ${questions.length} سؤالاً — أجب في ورقة الإجابة المنفصلة بتظليل الدائرة</div><div class="nm"><span>الاسم:</span><span>الفصل:</span></div></div>`;
    if (passageText.trim()) body += `<div class="ps"><div class="pl">اقرأ النص التالي ثم أجب عن الأسئلة:</div>${esc(passageText).split(/\n+/).map((l) => `<p>${l}</p>`).join('')}</div>`;
    let lastPassage = null;
    questions.forEach((q, i) => {
        if (q.passageImage && q.passageImage !== lastPassage) {
            lastPassage = q.passageImage;
            body += `<div class="ps"><div class="pl">اقرأ النص التالي ثم أجب عن الأسئلة التي بعده:</div><img src="${esc(abs(q.passageImage))}" alt="نص القراءة"></div>`;
        }
        const inner = q.image
            ? `<img src="${esc(abs(q.image))}" alt="السؤال ${i + 1}">`
            : `<div>${esc(q.text)}</div>${(q.options || []).map((o, k) => `<div class="opt"><b>${LETTERS[k]}.</b> ${esc(o)}</div>`).join('')}`;
        body += `<div class="q"><div class="n">${i + 1}</div><div class="c">${inner}</div></div>`;
    });
    return `<!doctype html><html lang="ar" dir="rtl"><head><meta charset="utf-8"><title>${esc('كتيّب الأسئلة — ' + title)}</title><style>${BOOK_CSS}</style></head><body>${body}</body></html>`;
}
