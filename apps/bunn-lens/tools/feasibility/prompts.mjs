// نسخة مبدئية من الطلب. عند بناء الميزة 2 تُنقل إلى functions/src/prompts/ ويُشارَك منها الكود.
export const PROMPT_VERSION = 'v0-feasibility-1';

const COMMON = `أنت مقيّم بصري لجودة القهوة. التقدير بصري فقط ولا تحكم على الطعم أو الرائحة.
أعد JSON فقط بالحقول: status (ok | unclear | not_coffee)، score (عدد صحيح 0-100)، notes (3 جمل عربية قصيرة بالضبط، كل واحدة مرتبطة بما يظهر فعلاً في الصورة).
إن كانت الصورة غير واضحة فـ status=unclear، وإن لم تكن بناً/قهوة فـ status=not_coffee (وscore=0 والملاحظات فارغة النص "").
مقياس الدرجة: 90-100 ممتاز، 75-89 جيد، 60-74 مقبول، 40-59 ضعيف، أقل من 40 رديء. اعتمد المعايير أدناه فقط وبنفس الصرامة في كل مرة.`;

export const PROMPTS = {
  bean: `${COMMON}
نوع الفحص: حبوب بن. المعايير: تجانس لون التحميص (30)، تجانس الحجم والشكل (25)، خلو الحبوب من العيوب كالمكسورة والمحروقة والباهتة (25)، لمعان الزيوت المناسب لدرجة التحميص (10)، نظافة العينة من الشوائب (10).`,
  coffee: `${COMMON}
نوع الفحص: كوب قهوة/مشروب. المعايير: الكريما أو الرغوة وسماكتها وتجانسها (30)، لون المشروب وعمقه (25)، الفصل أو الفقاعات الكبيرة أو الشوائب (20)، تقديم الكوب ونظافته (10)، توازن الشكل العام (15).`,
};

export const RESPONSE_SCHEMA = {
  type: 'OBJECT',
  properties: {
    status: { type: 'STRING', enum: ['ok', 'unclear', 'not_coffee'] },
    score: { type: 'INTEGER' },
    notes: { type: 'ARRAY', items: { type: 'STRING' }, minItems: 3, maxItems: 3 },
  },
  required: ['status', 'score', 'notes'],
};

/** يتحقق من صيغة المخرجات كما ستفعل الدالة. */
export function validateResult(o) {
  if (!o || !['ok', 'unclear', 'not_coffee'].includes(o.status)) throw new Error('status غير صالح');
  if (!Number.isInteger(o.score) || o.score < 0 || o.score > 100) throw new Error('score خارج 0-100');
  if (!Array.isArray(o.notes) || o.notes.length !== 3) throw new Error('الملاحظات يجب أن تكون 3 بالضبط');
  return o;
}
