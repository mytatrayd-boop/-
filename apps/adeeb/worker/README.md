# الخادم الوسيط لـ «الأديب الذكي» (Cloudflare Worker)

يحفظ مفتاح Gemini ويطبّق الحدود ويتحقق من الاقتباس قبل الرد على التطبيق. التصميم في `../ARCHITECTURE.md` §7–§8، والقرارات D10–D15 وD24 في `../DECISIONS.md`.

## المحتوى
| الملف | الدور |
|---|---|
| `src/index.ts` | نقطة الدخول، وتصدير `CounterStore` |
| `src/app.ts` | المسارات، التحقق، الحجز/الاسترداد، الرد، السجل |
| `src/validate.ts` | التحقق الصارم من الترويسات والجسم |
| `src/counters.ts` | Durable Object (SQLite): العدّادات اليومية، قاطع الدائرة، التنظيف |
| `src/gemini.ts` | تعليمات النظام، مخطط المخرجات، استدعاء Gemini REST، تصنيف 429 |
| `src/verify.ts` + `src/normalize.ts` | التحقق من الاقتباس بالتطبيع نفسه في `lib/text/arabic_normalizer.dart` |
| `wrangler.jsonc` | الربط والإعدادات — **بلا أسرار** |
| `.dev.vars.example` | أسماء الأسرار للتطوير المحلي بلا قيم |

## الأوامر (من `apps/adeeb/worker/`)
```
npm ci
npm test               # vitest داخل workerd محلياً، Gemini مُحاكى، لا يحتاج مفتاحاً
npm run typecheck      # tsc --noEmit
npx wrangler deploy --dry-run --outdir dist   # يبني فقط ولا ينشر
cp .dev.vars.example .dev.vars && npx wrangler dev   # تشغيل محلي (املأ .dev.vars بقيمك؛ غير مرفوع)
```

## العقد مع التطبيق
الترويسات: `X-Device-Id` (UUID v4)، `X-Client: adeeb-android/<build>`، و`Content-Type: application/json` لـ `/v1/ask`. أي طلب يحمل `Origin` (متصفح) يُرفض.

| المسار | الرد |
|---|---|
| `POST /v1/ask` | الجسم `{v:1, lang:"ar"\|"en", question, passages:[{id, book, chapter, text}]}` ← 200 `{found:true, answer, citations:[{paragraph_id, quote}], remaining}` أو `{found:false, answer:"", citations:[], reason:"NOT_FOUND"\|"UNVERIFIED", remaining}` |
| `GET /v1/quota` | `{limit, remaining, resets_at}` بلا استهلاك |
| `GET /v1/health` | `{ok:true}` |

الأخطاء بجسم `{code, remaining?, retry_after?}` (وترويسة `Retry-After` عند وجوده):

| HTTP | code | متى |
|---|---|---|
| 400 | `BAD_REQUEST` | صيغة أو ترويسة أو حجم غير مطابق (لا يلمس العدّادات ولا Gemini) |
| 403 | `FORBIDDEN` | الطلب يحمل `Origin` |
| 404 / 405 | `NOT_FOUND` / `METHOD_NOT_ALLOWED` | مسار أو طريقة خاطئة |
| 426 | `UPGRADE_REQUIRED` | `v` أو رقم البناء في `X-Client` أقدم من `MIN_CLIENT` |
| 429 | `DAILY_LIMIT` | انتهت حصة الجهاز أو عنوان IP اليوم (`remaining:0`) |
| 429 | `RATE_LIMIT` | أكثر من 3 طلبات/دقيقة للجهاز أو 10 لعنوان IP |
| 503 | `UNAVAILABLE` | الحد الإجمالي، نفاد حصة Gemini (قاطع الدائرة)، عطل Gemini، أو إعداد ناقص. السؤال لا يُخصم |

- `NOT_FOUND`: النموذج لم يجد (أو حجب أمان). `UNVERIFIED`: النموذج أجاب لكن لم يصح أي اقتباس، فلا تُعاد الإجابة. كلاهما يُخصم من الحصة لأن Gemini استُدعي (D24).
- الاقتباس المعاد من نص النموذج؛ التطبيق يتحقق منه مجدداً ويعرض النص من فقرته المحلية (D12).

## الإعدادات (`vars` في `wrangler.jsonc`، تتغير بلا تحديث التطبيق)
| المتغير | الافتراضي | المعنى |
|---|---|---|
| `GEMINI_MODEL` | `gemini-flash-lite-latest` | اسم النموذج (D14). تأكد منه في AI Studio |
| `GEMINI_API_BASE` | `https://generativelanguage.googleapis.com` | عنوان Gemini REST |
| `GEMINI_TIMEOUT_MS` | 12000 | مهلة Gemini (التطبيق ينتظر 15 ثانية) |
| `DAILY_PER_DEVICE` / `DAILY_PER_IP` | 10 / 30 | الحد اليومي (UTC) |
| `DAILY_GLOBAL` | 450 | الحد الإجمالي اليومي ≈ 90% من حد النموذج الفعلي — **يضبطه المالك** |
| `MIN_CLIENT` | 1 | أقل رقم بناء مقبول |
| `MAX_BODY_BYTES` | 32768 | حجم الجسم (انظر D24) |
| `MAX_QUESTION_CHARS` / `MAX_PASSAGES` / `MAX_PASSAGE_CHARS` / `MAX_PASSAGES_TOTAL_CHARS` | 500 / 6 / 1500 / 8000 | حدود الطلب |

الحد بالدقيقة في `ratelimits` (RL_DEVICE: 3/60ث، RL_IP: 10/60ث).
**الأسرار** (لا تُكتب في أي ملف مرفوع): `GEMINI_API_KEY`، `DEVICE_SALT`، `IP_SALT`.

## الخصوصية والسجلات
- سطر سجل واحد لكل طلب: `{path, status, ms, code}` فقط. لا سؤال ولا فقرات ولا IP ولا معرّف (اختبار `test/logging.test.ts`). سجلات الاستدعاء التلقائية في Cloudflare معطّلة (`invocation_logs: false`) لأنها قد تحمل الترويسات.
- العدّادات تخزّن `HMAC-SHA256` للمعرّف وIP بملحين سريين، وتُحذف صفوف الأيام السابقة بمنبّه يومي.

## النشر — خطوات يقوم بها المالك لاحقاً (لم يُنشر شيء)
> لا ترسل أي مفتاح أو رمز في المحادثة ولا تكتبه في ملف مرفوع. الأوامر تطلب القيمة في الطرفية مباشرة.

1. **حساب Cloudflare مجاني:** أنشئه من <https://dash.cloudflare.com/sign-up> بالبريد فقط؛ الخطة Free لا تحتاج بطاقة. بلوغ الحد يوقف الخدمة ولا ينشئ فاتورة.
2. **مفتاح Gemini:** من <https://aistudio.google.com/apikey> على مشروع **بلا فوترة**. من صفحة الحدود (Rate limits) في AI Studio اقرأ الحد اليومي (RPD) للنموذج المختار، وعدّل `DAILY_GLOBAL` في `wrangler.jsonc` إلى نحو 90% منه، وتأكد أن `GEMINI_MODEL` اسم نموذج متاح لك.
3. على جهازك (يحتاج Node.js 20 أو أحدث)، من `apps/adeeb/worker/`:
   ```
   npm ci
   npm test
   npx wrangler login                       # يفتح المتصفح لتسجيل الدخول إلى Cloudflare
   npx wrangler secret put GEMINI_API_KEY   # الصق المفتاح عند الطلب
   npx wrangler secret put DEVICE_SALT      # أي نص عشوائي طويل (مثلاً ناتج: openssl rand -hex 32)
   npx wrangler secret put IP_SALT          # نص عشوائي آخر مختلف
   npx wrangler deploy
   ```
   أول `secret put` قد يسأل عن إنشاء الـ Worker؛ وافق. يطبع `deploy` عنواناً مثل `https://adeeb-worker.<اسمك>.workers.dev`.
4. **فحص بعد النشر:** افتح `https://adeeb-worker.<اسمك>.workers.dev/v1/health` ويجب أن يظهر `{"ok":true}`. ثم سؤال تجريبي واحد من التطبيق (أو `tool/eval_ask.dart` لاحقاً)؛ إن ظهر 503 بسبب «location not supported» من Gemini فانظر ARCHITECTURE §8.5 (`placement`).
5. ضع العنوان في `config/app_config.json` للتطبيق كـ `ASK_API_BASE_URL` (ليس سراً).

تغيير ملح `DEVICE_SALT` أو `IP_SALT` لاحقاً يصفّر عدّادات اليوم فقط. لتغيير النموذج أو الحدود: عدّل `wrangler.jsonc` ثم `npx wrangler deploy`.

## ما لم يُختبر هنا
النشر الفعلي على Cloudflare، واستدعاء Gemini الحقيقي (المخطط `responseSchema` و`format: "enum"` وشكل رد 429 الفعلي، وصحة اسم النموذج)، وحد CPU 10ms على الخطة المجانية، وسلوك Rate Limiting الموزّع (يُحسب لكل موقع Cloudflare)، وموقع التنفيذ مقابل الدول المدعومة في Gemini.
