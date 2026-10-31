// نسخة مبدئية من الطلب. عند بناء الميزة 2 تُنقل إلى functions/src/prompts/ ويُشارَك منها الكود.
export const PROMPT_VERSION = 'v0-feasibility-3';

const COMMON = `أنت مقيّم بصري لجودة القهوة. التقدير بصري فقط ولا تحكم على الطعم أو الرائحة.
أعد JSON فقط بالحقول: status (ok | unclear | not_coffee)، score (عدد صحيح 0-100)، notes (3 جمل عربية قصيرة بالضبط، كل واحدة مرتبطة بما يظهر فعلاً في الصورة).
إن كانت الصورة غير واضحة فـ status=unclear، وإن لم تكن بناً/قهوة فـ status=not_coffee (وscore=0 والملاحظات فارغة النص "").
مقياس الدرجة: 90-100 ممتاز، 75-89 جيد، 60-74 مقبول، 40-59 ضعيف، أقل من 40 رديء. اعتمد المعايير أدناه فقط وبنفس الصرامة في كل مرة.
كن صارماً ولا تجامل: متوسط الصور العادية بين 45 و65، والدرجة فوق 85 نادرة لا تُعطى إلا لصورة بلا أي عيب ظاهر. استعمل المدى كله ولا تتجمع حول رقم واحد.
قواعد الخصم الإلزامية: أي عيب جسيم ظاهر (حبة محروقة أو سوداء أو متعفنة أو مثقوبة أو مكسورة، أو كوب بلا كريما، أو صورة بعيدة يصعب فحصها) يجعل الدرجة 35 أو أقل. كريما رقيقة أو غير متجانسة أو فقاعات كبيرة تجعلها 60 أو أقل. تحميص غير متجانس بين الحبوب أو لون باهت يجعلها 60 أو أقل. جمال الصورة أو الإضاءة أو الكوب لا يرفع الدرجة، فقيّم القهوة نفسها لا التصوير.`;

// حقول إضافية لاختبار الجدوى على البن فقط (تُقارن بالوسوم المفتوحة)
const BEAN_EXTRA = `
أضف أيضاً الحقلين: roast_level (light | medium | dark | green | unknown) = مستوى تحميص الحبوب الظاهرة (green للبن الأخضر غير المحمص)، وhas_defects (true/false) = هل تظهر حبة معيبة (مكسورة أو محروقة أو متعفنة أو مثقوبة أو مشوّهة).`;

export const PROMPTS = {
  bean: `${COMMON}
نوع الفحص: حبوب بن. المعايير: تجانس لون التحميص (30)، تجانس الحجم والشكل (25)، خلو الحبوب من العيوب كالمكسورة والمحروقة والباهتة (25)، لمعان الزيوت المناسب لدرجة التحميص (10)، نظافة العينة من الشوائب (10).${BEAN_EXTRA}`,
  coffee: `${COMMON}
نوع الفحص: كوب قهوة/مشروب. المعايير: الكريما أو الرغوة وسماكتها وتجانسها (30)، لون المشروب وعمقه (25)، الفصل أو الفقاعات الكبيرة أو الشوائب (20)، تقديم الكوب ونظافته (10)، توازن الشكل العام (15).`,
};

export const RESPONSE_SCHEMA = {
  type: 'OBJECT',
  properties: {
    status: { type: 'STRING', enum: ['ok', 'unclear', 'not_coffee'] },
    score: { type: 'INTEGER' },
    notes: { type: 'ARRAY', items: { type: 'STRING' }, minItems: 3, maxItems: 3 },
    roast_level: { type: 'STRING', enum: ['light', 'medium', 'dark', 'green', 'unknown'] },
    has_defects: { type: 'BOOLEAN' },
  },
  required: ['status', 'score', 'notes'],
};

/** يتحقق من صيغة المخرجات كما ستفعل الدالة. */
export function validateResult(o) {
  if (!o || !['ok', 'unclear', 'not_coffee'].includes(o.status)) throw new Error('status غير صالح');
  if (!Number.isInteger(o.score) || o.score < 0 || o.score > 100) throw new Error('score خارج 0-100');
  if (!Array.isArray(o.notes) || o.notes.length !== 3) throw new Error('الملاحظات يجب أن تكون 3 بالضبط');
  if (o.roast_level !== undefined && !['light', 'medium', 'dark', 'green', 'unknown'].includes(o.roast_level)) throw new Error('roast_level غير صالح');
  if (o.has_defects !== undefined && typeof o.has_defects !== 'boolean') throw new Error('has_defects غير صالح');
  return o;
}
