// أدوات مشتركة لملفات المهارات: ناتج التعلم (outcome) يحوي مؤشراته، وكل مؤشر = مهارة.

// اسم مختصر للمؤشر: أول جملة فرعية من نصه (حتى أول فاصلة)، بحد أقصى ~58 حرفاً.
export function shortName(text) {
    let t = text.replace(/\s+/g, ' ').trim().replace(/[.،؛]+$/, '');
    let depth = 0;
    for (let i = 0; i < t.length; i++) {              // أول فاصلة خارج الأقواس
        if (t[i] === '(') depth++;
        else if (t[i] === ')') depth = Math.max(0, depth - 1);
        else if ((t[i] === '،' || t[i] === '؛') && depth === 0 && i > 18) { t = t.slice(0, i); break; }
    }
    if (t.length > 58) {
        let cut = t.slice(0, 58);
        const open = cut.lastIndexOf('('), close = cut.lastIndexOf(')');
        if (open > close) cut = cut.slice(0, open);      // لا نقطع داخل قوس
        else cut = cut.slice(0, cut.lastIndexOf(' '));
        t = cut.replace(/[،؛ ]+$/, '') + '…';
    }
    return t;
}

// ناتج تعلم: id مثل m6-1-1-1، ومؤشراته نصوص من الوثيقة، ومعرّف كل مؤشر id.n
export const outcome = (id, name, desc, items) => ({
    id, name, desc,
    skills: items.map((text, i) => ({ id: `${id}.${i + 1}`, name: shortName(text), desc: text, n: i + 1 })),
});

// مجموعة = مجال فرعي: [ نواتج التعلم ]
export const group = (domain, title, outcomes) => ({ domain, title, outcomes });
