// بنك الأسئلة (المرحلة 02): سجل السؤال، فحص الجودة، ومسار المراجعة. منطق نقي بلا Firebase.
import { skillById } from './skills.js';

export const BANK_LEVELS = ['know', 'apply', 'reason'];
export const BANK_STATUS = {
    generated: 'مولَّد — بانتظار المراجعة',
    approved: 'معتمد',
    rejected: 'مرفوض',
    na: 'غير منطبق',
};
// المسار: مولد ← معتمد | مرفوض؛ ويُعاد المرفوض إلى المراجعة بعد التحرير. «غير منطبق» نهائي لذلك المستوى.
const NEXT = { generated: ['approved', 'rejected'], rejected: ['generated'], approved: ['generated'], na: [] };
export const canTransition = (from, to) => (NEXT[from] ?? []).includes(to);

const norm = (s) => s.trim().replace(/\s+/g, ' ');
const HINTS = /(كل ما سبق|جميع ما سبق|لا شيء مما سبق|كلها صحيحة|كلها خاطئة)/;

// سجل السؤال في البنك: skill معرّف مؤشر ثابت، version يزيد عند كل تحرير.
export function newBankQuestion({ skill, level, text, options, answer, explanation = '', source = 'manual', passageId = null }) {
    return { skill, level, text, options, answer, explanation, source, passageId, status: source === 'ai' ? 'generated' : 'generated', version: 1 };
}

// فحص الجودة: يرجع قائمة مشكلات (فارغة = سليم). لا يحكم على المعنى، بل على الشكل.
export function qualityIssues(q) {
    const issues = [];
    const skill = skillById(q.skill);
    if (!skill) issues.push('المهارة غير معروفة في الدليل.');
    if (!BANK_LEVELS.includes(q.level)) issues.push('المستوى المعرفي غير صحيح.');
    const text = norm(q.text ?? '');
    if (text.length < 12) issues.push('نص السؤال قصير جداً أو غير واضح.');
    if (text.length > 600) issues.push('نص السؤال طويل جداً.');
    const opts = (q.options ?? []).map(norm);
    if (opts.length !== 4) issues.push('يلزم أربعة خيارات.');
    if (opts.some((o) => !o)) issues.push('خيار فارغ.');
    if (new Set(opts).size !== opts.length) issues.push('خيارات مكررة.');
    if (!Number.isInteger(q.answer) || q.answer < 0 || q.answer >= opts.length) issues.push('مفتاح الإجابة غير محدد.');
    if (opts.some((o) => HINTS.test(o))) issues.push('تجنّب «كل ما سبق/لا شيء مما سبق».');
    const lens = opts.map((o) => o.length);
    if (lens.length === 4 && Math.max(...lens) > 3 * Math.max(4, Math.min(...lens)) + 10) issues.push('تفاوت كبير في أطوال الخيارات يلمّح للإجابة.');
    if (opts[q.answer] && opts.filter((o, i) => i !== q.answer && o.length && text.includes(o) && o.length > 6).length) issues.push('نص السؤال يتضمن أحد المشتتات.');
    if (!norm(q.explanation ?? '')) issues.push('اكتب تفسير الإجابة الصحيحة.');
    return issues;
}

// يقبل المعلم إدراج السؤال في اختبار فقط إن كان معتمداً.
export const usableInTest = (q) => q.status === 'approved';

// مكرر؟ (نفس المهارة والمستوى ونص متطابق بعد التطبيع)
export function isDuplicate(q, existing) {
    const t = norm(q.text);
    return existing.some((e) => e.skill === q.skill && e.level === q.level && norm(e.text) === t);
}

// تنسيق نتيجة التوليد (من خدمة الذكاء الاصطناعي) إلى سجلات: لكل مستوى سؤال أو «غير منطبق» مع السبب.
export function fromGeneration(skillId, result) {
    const out = [];
    for (const level of BANK_LEVELS) {
        const r = result?.[level];
        if (!r || r.applicable === false) {
            out.push({ skill: skillId, level, status: 'na', reason: String(r?.reason ?? 'لم يحدَّد سبب').slice(0, 300), version: 1, source: 'ai' });
        } else {
            out.push(newBankQuestion({ skill: skillId, level, text: String(r.text ?? ''), options: (r.options ?? []).map(String), answer: r.answer, explanation: String(r.explanation ?? ''), source: 'ai' }));
        }
    }
    return out;
}
