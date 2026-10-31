# اختبار جدوى الدقة (الميزة 0)

يقيس: فرق ≤10 عن الخبير (هدف 70%)، ثبات ≤5 بين فحصين (90%)، التفريق بين «ضعيفة» و«ممتازة»، صحة الملاحظات (70%)، الزمن (≤10ث في 90%) والتكلفة.

## التجهيز
1. ضع الصور في مجلد (خارج git)، JPEG بحد أقصى 1024px (كما سيرسلها التطبيق).
2. انسخ `expert-template.csv` واملأه: `type` = bean|coffee، `expert_score` 0-100، `expert_class` = poor|mid|excellent، `notes_correct` = عدد الملاحظات الصحيحة من 3 (اختياري).
3. المفاتيح من البيئة فقط (لا تكتبها في ملف):
```
export GOOGLE_CLOUD_PROJECT=...
export VERTEX_ACCESS_TOKEN=$(gcloud auth print-access-token)
export PRICE_IN_PER_M=...  PRICE_OUT_PER_M=...   # اختياري، للتكلفة
```
## التشغيل
```
node run.mjs --images ./photos --csv ./expert.csv --model gemini-2.5-flash --out results.json
```
لمقارنة نماذج: أعد التشغيل بـ `--model` مختلف وقارن التقارير.

## الاختبار
```
node --test "test/*.test.mjs"
```
لا يحتاج شبكة ولا اعتماديات (Node 20+).

## ملاحظات
- الطلب في `prompts.mjs` نسخة مبدئية (`v0-feasibility-1`) وسينتقل إلى `functions/src/prompts/`.
- الفرق عن الخبير يُحسب على متوسط التشغيلين. «غير مقاس» لا يُعدّ نجاحاً.
