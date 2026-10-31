# مصادر وتراخيص صور اختبار الجدوى

الصور نفسها لا تُحفظ في git (`tools/feasibility/data/`). يعيد `node datasets/fetch.mjs` تنزيلها حتمياً بلا حساب. `manifest.csv` يسرد كل صورة بمصدرها وترخيصها وملفها الأصلي. تاريخ الاستكشاف: 2026-10-31. التراخيص أدناه كما تعرضها المنصات نفسها؛ لا تُعامل كاستشارة قانونية. الاستخدام هنا اختبار داخلي فقط (لا نشر ولا تضمين في التطبيق).

## مستخدمة فعلاً

| المجموعة | الاستخدام | الصور | الترخيص | المصدر |
|---|---|---|---|---|
| Coffee Bean Dataset Resized 224x224 (gpiosenka، مشتقة من sot2542 Coffee Bean Dataset v1) | بن محمّص، وسم مستوى التحميص Light/Medium/Dark، حبة واحدة 224px | 24 (8 لكل مستوى، من test) | CC BY-SA 4.0 (يلزم الإسناد والمشاركة بالمثل) | https://www.kaggle.com/datasets/gpiosenka/coffee-bean-dataset-resized-224-x-224 |
| Coffee Bean Classification Dataset (Ardiyanto24) | وسم defect/premium، حبة واحدة 256px. **بن أخضر غير محمص** | 16 (8 معيبة + 8 premium، من train) | Apache-2.0 | https://www.kaggle.com/datasets/ardiyanto24/coffee-bean-classification-dataset |
| Coffee Images (thekangaroofactory) | كوب إسبريسو/لونغ بلاك، 256px، بلا وسم جودة | 24 (12 + 12) | "Other": الوصف يقول حر الاستخدام مع ذكر المصدر عند المشاركة خارج Kaggle. ليس ترخيصاً قياسياً؛ يُستخدم للاختبار الداخلي فقط | https://www.kaggle.com/datasets/thekangaroofactory/coffee-images |
| espresso_image (PARANGAT SINGh) | صورة إسبريسو | 1 | Apache-2.0 | https://www.kaggle.com/datasets/parangatsingh/espresso-image |
| Wikimedia Commons (بحث espresso/cappuccino/latte art/drip) | أكواب قهوة، حتى 1280px | 13 (CC BY-SA 4.0 x4، CC BY-SA 3.0 x4، CC0 x2، CC BY-SA 2.0 x2، CC BY 3.0 x1؛ المؤلف في عمود source). 7 صور أخرى فشلت بـ HTTP 429 (تحديد معدل Wikimedia) | لكل صورة: CC0 أو CC BY أو CC BY-SA (2.0 إلى 4.0)، مسجّل في عمود license مع رابط صفحة الملف في origin | https://commons.wikimedia.org (قائمة الملفات في `wikimedia.json`) |

## وُجدت ولم تُستخدم

| المجموعة | السبب |
|---|---|
| Roboflow `coffee-quality-classifier` (Public Domain) وRoboflow `coffee` (CC BY 4.0) | `universe.roboflow.com` محجوب من الوكيل (HTTP 403)، و`api.roboflow.com` يتطلب حساباً ومفتاح API. لم تُنزَّل. |
| مستودع GitHub لعيوب البن المحمّص (Apache-2.0) | `github.com` و`codeload.github.com` و`api.github.com/search` محجوبة (403/400) وبحث الجلسة مقيّد بمستودعاتها؛ لم أستطع حتى تحديد المستودع. `raw.githubusercontent.com` يعمل لكن يلزم اسم المستودع. |
| Kaggle `vinsentoothpaste/coffee-beans-defect-detection` (MIT، 4.2GB) | قابلة للتنزيل بلا حساب (فحصتُ قائمتها بطلبات Range) لكن وسومها YOLO بأرقام فئات بلا ملف أسماء (`data.yaml` غير موجود) فلا يمكن معرفة أي رقم يعني «معيب»؛ استبعدتها بدل التخمين. |
| Kaggle `sot2542/coffee-bean-dataset-v1` (CC BY-SA 4.0، 10GB) | الأصل بدقة 3024px لمجموعة gpiosenka؛ كبيرة جداً. النسخة المصغّرة تكفي للجدوى. |
| Kaggle `sujitraarw/coffee-green-bean-with-17-defects-original` | ترخيصها Unknown، وبن أخضر. |
| Pexels | `images.pexels.com` أعاد 404 ولم أستكشف الواجهة؛ لم تُستخدم. |

## حدود يجب معرفتها

- المجموع الفعلي: 40 بن و38 مشروب (ناقصة 2 عن الهدف 40 بسبب 429 من Wikimedia؛ إعادة تشغيل `fetch.mjs` لاحقاً قد تكملها). 13 فقط من صور المشروب بترخيص CC0/CC BY/CC BY-SA القياسي، والباقي (25) من مجموعتين على Kaggle.

- لا توجد صور بن **محمّص** موسومة بالعيوب (المتاح للعيوب بن أخضر). لذلك «كشف العيوب» يقيس بن أخضر فقط وليس سيناريو التطبيق الحقيقي (حبوب محمّصة متعددة في الصورة).
- صور البن حبة واحدة منخفضة الدقة (224-256px) وليست صور هاتف لكومة حبوب؛ نتائج التحميص عليها تدل على الاتجاه فقط.
- لا توجد وسوم جودة للمشروبات في أي مصدر مفتوح وجدته؛ فئات `clear_class` فارغة، وكل درجات الخبير فارغة.
