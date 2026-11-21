// ورقة إجابة للتظليل اليدوي (بنفس فكرة ورقة الإجابة الوطنية، بتصميم الموقع وبلا شعارات جهات أخرى).
// أربعة خيارات (أ ب ج د) لكل سؤال، ورقم السجل المدني بعشر خانات مظلَّلة، وعلامات زوايا لتسهيل المسح الضوئي لاحقاً.
const LETTERS = ['أ', 'ب', 'ج', 'د'];
export const OMR_PER_COLUMN = 15;
export const OMR_COLUMNS = 4;
export const OMR_PER_PAGE = OMR_PER_COLUMN * OMR_COLUMNS;

export const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]);

const CSS = `
@page{size:A4 portrait;margin:8mm}
*{box-sizing:border-box}
body{margin:0;font-family:'Cairo','Noto Naskh Arabic','Tahoma',sans-serif;color:#000;background:#fff}
.page{position:relative;width:194mm;height:281mm;margin:0 auto;padding:6mm;page-break-after:always;overflow:hidden}
.page:last-child{page-break-after:auto}
.mk{position:absolute;width:6mm;height:6mm;background:#000}
.mk.tl{top:0;left:0}.mk.tr{top:0;right:0}.mk.bl{bottom:0;left:0}.mk.br{bottom:0;right:0}
h1{margin:2mm 0 1mm;text-align:center;font-size:17pt}
.sub{text-align:center;font-size:11pt;margin-bottom:3mm;font-weight:700}
.box{border:1.2px solid #000;border-radius:3mm;padding:2mm 3mm;margin-bottom:2.5mm;font-size:11pt;font-weight:700}
.box span.l{font-weight:400;border-bottom:1px dotted #000;display:inline-block;min-width:60mm}
.row2{display:flex;gap:3mm;margin-bottom:2.5mm}
.row2 .box{flex:1;margin:0}
.idbox{border:1.2px solid #000;border-radius:3mm;padding:2mm;margin-bottom:2.5mm}
.idbox h3{margin:0 0 1mm;font-size:10pt;text-align:center}
.idgrid{display:flex;flex-direction:row-reverse;justify-content:center;gap:1.2mm}
.idcol{display:flex;flex-direction:column;gap:.8mm;align-items:center}
.idw{width:6mm;height:6mm;border:1px solid #000;margin-bottom:.6mm}
.b{width:4.6mm;height:4.6mm;border:1px solid #000;border-radius:50%;font-size:7pt;line-height:4.4mm;text-align:center}
.bar{background:#0f766e;color:#fff;text-align:center;font-weight:800;border-radius:3mm;padding:1.6mm;margin:2mm 0;font-size:11pt;-webkit-print-color-adjust:exact;print-color-adjust:exact}
.cols{display:flex;gap:2mm;direction:rtl}
.col{flex:1;border:1.2px solid #000;border-radius:3mm;padding:1.5mm}
.qr{display:flex;align-items:center;gap:1.4mm;margin:1.05mm 0;direction:rtl}
.qn{width:7mm;text-align:center;font-weight:800;font-size:9.5pt;border:1px solid #000;border-radius:1mm}
.qb{display:flex;gap:1.6mm;direction:rtl}
.qb .b{width:5.4mm;height:5.4mm;line-height:5.2mm;font-size:8.5pt;font-weight:700}
.ft{position:absolute;bottom:7mm;left:0;right:0;text-align:center;font-size:8pt}
.key td,.key th{border:1px solid #000;padding:1mm 2mm;text-align:center;font-size:11pt}
.key{border-collapse:collapse;width:100%;margin-top:3mm}
`;

const bubble = (t) => `<span class="b">${t}</span>`;

function idGrid() {
    let cols = '';
    for (let c = 0; c < 10; c++) {
        let d = '<div class="idw"></div>';
        for (let n = 0; n <= 9; n++) d += bubble(n);
        cols += `<div class="idcol">${d}</div>`;
    }
    return `<div class="idbox"><h3>رقم السجل المدني / رقم الإقامة (اكتب الرقم ثم ظلّل الدائرة تحته)</h3><div class="idgrid">${cols}</div></div>`;
}

function answersBlock(from, to) {
    const cols = [];
    for (let c = 0; c < OMR_COLUMNS; c++) {
        let rows = '';
        for (let i = 0; i < OMR_PER_COLUMN; i++) {
            const n = from + c * OMR_PER_COLUMN + i;
            if (n > to) break;
            rows += `<div class="qr"><div class="qn">${n}</div><div class="qb">${LETTERS.map(bubble).join('')}</div></div>`;
        }
        if (rows) cols.push(`<div class="col">${rows}</div>`);
    }
    return `<div class="cols">${cols.join('')}</div>`;
}

/** صفحات ورقة الإجابة لاختبار بعدد أسئلة معيّن. */
export function omrSheetHtml({ title, className = '', subjectName = '', count }) {
    const total = Math.max(1, Math.min(Number(count) || 1, 400));
    const pages = Math.ceil(total / OMR_PER_PAGE);
    let body = '';
    for (let p = 0; p < pages; p++) {
        const from = p * OMR_PER_PAGE + 1, to = Math.min(total, (p + 1) * OMR_PER_PAGE);
        body += `<section class="page"><i class="mk tl"></i><i class="mk tr"></i><i class="mk bl"></i><i class="mk br"></i>
<h1>ورقة الإجابة — ${esc(title)}</h1><div class="sub">${esc(subjectName)}${subjectName && className ? ' · ' : ''}${esc(className)} · ${total} سؤالاً · ظلّل الدائرة كاملة بقلم رصاص أو حبر غامق</div>
${p === 0 ? `<div class="box">الاسم الرباعي: <span class="l"></span></div><div class="row2"><div class="box">المدرسة: <span class="l" style="min-width:40mm"></span></div><div class="box">الصف والفصل: <span class="l" style="min-width:30mm"></span></div></div>${idGrid()}` : '<div class="box">الاسم: <span class="l"></span> &nbsp; رقم السجل: <span class="l" style="min-width:40mm"></span></div>'}
<div class="bar">إجابات الأسئلة ${from} – ${to}</div>
${answersBlock(from, to)}
<div class="ft">صفحة ${p + 1} من ${pages} — مهارات اختبارات نافس</div></section>`;
    }
    return wrap(`ورقة إجابة — ${title}`, body);
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
