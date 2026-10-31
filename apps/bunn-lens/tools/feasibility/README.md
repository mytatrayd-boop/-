# اختبار جدوى الدقة (الميزة 0)

يقيس: فرق ≤10 عن الخبير (هدف 70%)، ثبات ≤5 بين فحصين (90%)، التفريق بين «ضعيفة» و«ممتازة»، صحة الملاحظات (70%)، الزمن (≤10ث في 90%) والتكلفة.

## صور مفتوحة بلا خبير (وضع البداية)
```
node datasets/fetch.mjs        # ينزّل ~40 بن و~40 مشروب إلى data/ (خارج git) ويكتب datasets/manifest.csv
node run.mjs --images data/images --csv datasets/manifest.csv --model gemini-2.5-flash --out results.json
```
المصادر والتراخيص والحدود: `datasets/LICENSES.md`. المانيفست بصيغة CSV نفسها مع أعمدة اختيارية:
`roast_label` (light|medium|dark) و`defect_label` (defect|ok) و`clear_class` (poor|mid|excellent) و`expert_score` فارغ. `run.mjs` يبحث عن الصورة في `<images>/<type>/<image>` ثم `<images>/<image>`.

المقاييس بلا خبير:
- **بن**: مطابقة مستوى التحميص مقابل `roast_label`، وكشف العيوب (دقة/استدعاء/نوعية) مقابل `defect_label`، لكل تشغيل. الطلب `v0-feasibility-2` يضيف الحقلين `roast_level` و`has_defects` لمخرجات البن. الهدف 70% مبدئي (ليس من SPEC).
- **مشروب**: ثبات الدرجة بين التشغيلين (≤5 في 90%)، والتفريق بين فئتين واضحتين من `clear_class` إن وُجدت.
- **فرق الخبير** يبقى معياراً كما هو ويظهر «غير مقاس» حتى تُملأ `expert_score`؛ «غير مقاس» لا يُعدّ نجاحاً. المعياران الجديدان يدخلان الحكم فقط إن قيسا.
- ما زال يحتاج خبيراً: درجة الجودة 0-100 (للبن والمشروب)، وصحة الملاحظات، والتفريق الحقيقي بين مشروب ضعيف وممتاز.

## التجهيز (وضع الخبير)
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
