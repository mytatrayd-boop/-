// توليد أسئلة المهارة: ثلاثة مستويات (معرفة، تطبيق، استدلال) مع «غير منطبق». منطق نقي قابل للاختبار.
// لا تُرسل أي بيانات طلاب إلى الخدمة؛ المُرسَل نص المؤشر الرسمي فقط.
export const MODEL = 'claude-sonnet-5-5';

export function buildPrompt({ subject, grade, outcome, indicator }) {
    const names = { reading: 'اللغة العربية (القراءة)', math: 'الرياضيات', science: 'العلوم' };
    const gradeName = { 3: 'الثالث الابتدائي', 6: 'السادس الابتدائي', 9: 'الثالث المتوسط' }[grade];
    return `أنت مختص في بناء أسئلة الاختبارات الوطنية (نافس) باللغة العربية.
المادة: ${names[subject]} — الصف: ${gradeName}
ناتج التعلم: ${outcome}
المؤشر (المهارة): ${indicator}

اكتب لهذا المؤشر وحده ثلاثة أسئلة اختيار من متعدد، سؤالاً لكل مستوى:
- know (معرفة): تذكّر أو تعرّف مباشر.
- apply (تطبيق): استخدام المعرفة في موقف مألوف.
- reason (استدلال): تحليل أو تعليل أو حل في موقف جديد.
الشروط: أربعة خيارات بالضبط، إجابة صحيحة واحدة فقط، مشتتات معقولة متقاربة الطول، بلا «كل ما سبق/لا شيء مما سبق»، بلا تلميح في نص السؤال، ولا تخرج عن المؤشر.
إذا لم يناسب مستوى ما هذا المؤشر فعلاً (طبيعة المهارة أو مواصفاتها لا تسمح)، فاجعله {"applicable": false, "reason": "السبب باختصار"} ولا تختلق سؤالاً.
أجب بـ JSON فقط بهذا الشكل دون أي نص آخر:
{"know": {"text": "", "options": ["","","",""], "answer": 0, "explanation": ""}, "apply": {...}, "reason": {...}}
answer رقم الإجابة الصحيحة (0 إلى 3).`;
}

// يستخرج JSON من رد النموذج (قد يحيط به نص أو أسوار كود) ويتحقق من شكله؛ يرمي عند الفساد.
export function parseResult(raw) {
    const m = String(raw).match(/\{[\s\S]*\}/);
    if (!m) throw new Error('لا يوجد JSON في الرد');
    const data = JSON.parse(m[0]);
    const out = {};
    for (const level of ['know', 'apply', 'reason']) {
        const r = data[level];
        if (!r || r.applicable === false) { out[level] = { applicable: false, reason: String(r?.reason ?? '') }; continue; }
        if (!Array.isArray(r.options) || r.options.length !== 4 || !Number.isInteger(r.answer) || r.answer < 0 || r.answer > 3 || typeof r.text !== 'string') {
            throw new Error(`شكل غير صحيح للمستوى ${level}`);
        }
        out[level] = { text: r.text, options: r.options.map(String), answer: r.answer, explanation: String(r.explanation ?? '') };
    }
    return out;
}
