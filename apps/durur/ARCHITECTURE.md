# معمارية «ديرة الدرور» — ARCHITECTURE

> المرجع: SPEC.md وIDEA.md. أسباب القرارات في DECISIONS.md (يُشار إليها بـ D1، D2 ...).

## 1. الصورة العامة

- تطبيق Flutter واحد لآيفون وأندرويد، **بلا خادم ولا Firebase ولا تسجيل دخول** (D1).
- كل البيانات مضمّنة في التطبيق كأصول JSON، وكل الحساب على الجهاز.
- لا يحتاج إنترنت إطلاقاً. نسخة أندرويد الإصدارية **بلا إذن INTERNET** (D15).
- العربية فقط في الإطلاق، ومن اليمين لليسار؛ النصوص في ملفات ARB جاهزة لإضافة الإنجليزية (D17).

```
أصول JSON ──► TableRepository ──► CalendarEngine ──► DayInfo ──► الواجهة (الدائرة/الصفحات)
                                     ▲                               ▲
مدينة المستخدم ──► Heliacal (فلك) ───┘                               │
            └──► NotificationPlanner ──► NotificationScheduler (جهاز) │
SettingsRepository (shared_preferences) ──────────────────────────────┘
```

الطبقات المعلّمة بـ «Dart صافٍ» لا تستورد Flutter، وتُختبر باختبارات وحدة سريعة.

## 2. هيكل المجلدات

```
apps/durur/
├─ assets/
│  ├─ tables/                    # بيانات الجداول (D5). لا تسمِّ أي مجلد "data" (D18)
│  │  ├─ meta.json               # رقم مخطط البيانات ونسختها
│  │  ├─ regions.json            # المناطق الأربع
│  │  ├─ cities.json             # المدن + الإحداثيات + المنطقة
│  │  ├─ items.json              # النجوم والمواسم ومواسم الجو: تعريف، مثل، مصدر
│  │  └─ regions/
│  │     ├─ najd.json            # جدول كل منطقة: الدرور، المواسم، النجوم، مواسم الجو
│  │     ├─ kuwait.json
│  │     ├─ uae_oman.json
│  │     └─ <الرابعة>.json      # بانتظار قرار المالك
│  └─ fonts/                     # خط عربي مضمّن برخصة OFL (يحدده DESIGN.md)
├─ config/
│  └─ app_config.example.json    # إعدادات البناء (رابط البلاغ/البريد). ليست أسراراً
├─ lib/
│  ├─ main.dart                  # ProviderScope + DururApp
│  ├─ l10n/                      # app_ar.arb + الملفات المولّدة (gen-l10n)
│  └─ src/
│     ├─ app.dart                # MaterialApp.router، اللغة، الاتجاه، الثيم
│     ├─ routing/                # go_router: / ، /item/:id ، /settings ، /city ، /onboarding
│     ├─ domain/                 # [Dart صافٍ] النماذج: Region, City, Item, Period, DayInfo, WeatherSymbol, Approval, Source
│     ├─ engine/                 # [Dart صافٍ] CalendarEngine, YearIndex, TableValidator
│     ├─ astronomy/              # [Dart صافٍ] sun.dart, stars.dart, sidereal.dart, precession.dart, heliacal.dart
│     ├─ hijri/                  # HijriDate (أم القرى) — موجود
│     ├─ repository/             # TableRepository (تحميل JSON)، SettingsRepository (shared_preferences)
│     ├─ location/               # LocationService (geolocator)، NearestCity [Dart صافٍ]
│     ├─ notifications/          # NotificationPlanner [Dart صافٍ]، NotificationScheduler (البلجن)
│     ├─ report/                 # ReportService: نموذج ← بريد ← نسخ
│     ├─ providers.dart          # كل مزوّدات Riverpod في مكان واحد
│     └─ features/
│        ├─ onboarding/          # شرح الموقع ← الإذن ← المدينة ← إذن التنبيهات
│        ├─ home/                # الشاشة الرئيسية + dial/ (CustomPainter + اختبار اللمس)
│        ├─ item_detail/         # صفحة النجم/الموسم
│        ├─ city_picker/         # قائمة المدن مع البحث
│        └─ settings/
├─ test/                         # نفس تقسيم lib/src
│  ├─ engine/ astronomy/ hijri/ notifications/ location/ widgets/
│  └─ fixtures/                  # جداول تجريبية صغيرة للاختبار
└─ tool/
   └─ validate_tables.dart       # يتحقق من الجداول؛ مع --release يفشل إن وُجد سجل غير معتمد (D16)
```

## 3. إدارة الحالة — Riverpod (D3)

مزوّدات يدوية (بلا توليد كود) في `lib/src/providers.dart`:

| المزوّد | النوع | الوظيفة |
|---|---|---|
| `tablesProvider` | `FutureProvider<Tables>` | يحمّل كل JSON مرة واحدة عند الفتح |
| `settingsProvider` | `NotifierProvider<SettingsController, Settings>` | المدينة، مفتاحا التنبيهات، انتهاء الإعداد الأولي |
| `currentCityProvider` | `Provider<City?>` | المدينة المختارة من الإعدادات والجداول |
| `todayProvider` | `NotifierProvider<DateTime>` | تاريخ اليوم المحلي؛ يُحدَّث عند عودة التطبيق للواجهة وعند منتصف الليل |
| `selectedDateProvider` | `NotifierProvider<DateTime>` | التاريخ المعروض في الدائرة؛ زر «اليوم» يعيده لـ today |
| `engineProvider` | `Provider<CalendarEngine?>` | محرك منطقة المدينة الحالية |
| `dayInfoProvider` | `Provider.family<DayInfo, DateTime>` | نتيجة المحرك ليوم |
| `heliacalProvider` | `Provider.family<HeliacalDates, (String cityId, int year)>` | طلوع سهيل والثريا (مخزّن مؤقتاً) |
| `notificationSyncProvider` | مستمع | يعيد جدولة التنبيهات عند تغيّر المدينة/الإعدادات وعند الفتح |

الاختبارات تستبدل المزوّدات بـ `overrides` (جداول تجريبية، تاريخ ثابت) بلا مكتبات محاكاة.

## 4. نموذج البيانات وتخزينها (D5، D6)

### المبادئ
- كل سجل فيه `source` (مرجع منشور) و`approval` (`status`: `draft`/`approved`، `reviewer`، `date`).
- النصوص المعروضة من البيانات بصيغة `{"ar": "..."}` لتُضاف `"en"` لاحقاً بلا تغيير المخطط.
- التواريخ داخل الجداول بصيغة `"MM-DD"` (يوم وشهر، تتكرر كل سنة).
- **الطبقات المتصلة** (الدرور، المواسم الكبيرة، النجوم) تُخزَّن **بتاريخ البداية فقط**؛ النهاية = اليوم السابق لبداية التالي (دورياً عبر نهاية السنة). هذا يجعل الفجوات والتداخل مستحيلة بالبناء.
- **مواسم الجو** لها بداية ونهاية، وقد توجد بينها فجوات (لا موسم جو)، ولا يُسمح بالتداخل داخل المنطقة.
- رموز الجو مجموعة مغلقة: `hot, very_hot, cold, very_cold, mild, wind, rain, dust, humidity, fog` (يتحقق منها المدقق؛ الإضافة بقرار).

### أمثلة (القيم توضيحية وغير معتمدة)

`regions.json`
```json
[{ "id": "najd", "name": {"ar": "نجد"}, "leapDayRule": "extend_feb28",
   "source": {"title": "...", "author": "...", "year": 0, "page": "..."},
   "approval": {"status": "draft", "reviewer": null, "date": null} }]
```

`cities.json`
```json
[{ "id": "riyadh", "name": {"ar": "الرياض"}, "country": "SA",
   "lat": 24.71, "lon": 46.68, "regionId": "najd",
   "source": {...}, "approval": {...} }]
```

`items.json` (كتالوج كل ما له صفحة)
```json
[{ "id": "suhail", "kind": "star", "name": {"ar": "سهيل"},
   "important": true, "dateMethod": "heliacal",
   "definition": {"ar": "سطر أول\nسطر ثانٍ"}, "proverb": {"ar": "..."},
   "weather": ["hot", "humidity"], "weatherNote": {"ar": "..."},
   "referenceRisings": [{"cityId": "kuwait", "year": 2026, "date": "2026-08-24", "source": {...}}],
   "sources": [{...}], "approval": {...} }]
```
`kind`: `star` | `majorSeason` | `weatherSeason` | `dar`. `dateMethod`: `table` | `heliacal`.

`regions/najd.json`
```json
{ "regionId": "najd",
  "durur":         [{"start": "08-15", "number": 1, "name": {"ar": "العشر"}, "seasonId": "safari",
                     "weather": ["hot"], "weatherNote": {"ar": "..."}, "source": {...}, "approval": {...}}],
  "majorSeasons":  [{"itemId": "safari", "start": "08-15"}],
  "stars":         [{"itemId": "suhail", "start": "08-24"}],
  "weatherSeasons":[{"itemId": "wasm", "start": "10-16", "end": "12-06"}] }
```

### التحقق (`TableValidator` + `tool/validate_tables.dart` + اختبار)
- الطبقات المتصلة: بدايات مرتبة وفريدة وصالحة، وغطاء كامل للسنة.
- مواسم الجو بلا تداخل، وكل `itemId` موجود في `items.json` وله تعريف (سطران كحد أقصى) ومثل ومصدر.
- كل مدينة مرتبطة بمنطقة موجودة؛ المناطق 4.
- مع `--release`: أي `approval.status != approved` ← فشل (شرط الإطلاق).
- في وضع التطوير يظهر شريط «بيانات تجريبية غير معتمدة» إن وُجد سجل مسودة.

## 5. محرك الحساب (الميزة 1) — Dart صافٍ

`CalendarEngine(RegionTable)` ← `DayInfo resolve(DateTime localDate)`:

1. يؤخذ التاريخ المحلي فقط (يبدأ اليوم عند منتصف الليل بتوقيت الجهاز)، ويُحوَّل إلى `DateTime.utc(y, m, d)` لتجنب مشاكل التوقيت الصيفي في حساب الفروق.
2. `(شهر، يوم)`؛ 29 فبراير يُعامَل كـ 28 فبراير في تحديد السجل (`extend_feb28`)، فيطول ذلك الدَّرّ يوماً.
3. لكل طبقة متصلة: السجل الفعّال = آخر بداية ≤ (شهر، يوم)، وإلا آخر سجل في السنة (التفاف).
4. اليوم داخل الدَّرّ = عدد الأيام الفعلية من آخر حدوث لتاريخ بدايته + 1؛ وطوله = الأيام حتى البداية التالية (فيشمل 29 فبراير تلقائياً).
5. موسم الجو: السجل الذي يحتوي التاريخ أو لا شيء.
6. `DayInfo`: الدَّرّ (اسم، رقم، اليوم، الطول)، الموسم الكبير، موسم الجو؟، النجم، رموز الجو ووصفه، وتواريخ البداية/النهاية.

`YearIndex(region, year)`: مصفوفة 365/366 `DayInfo` تُبنى عند الطلب وتُخزَّن؛ تغذي الدائرة والمخطِّط والاختبارات.

اختبارات المحرك: 366 يوماً × 4 مناطق × سنوات 2025–2040 (نتيجة واحدة، لا فجوات)، حدود الدَّرّ (اليوم 1 والسابق له)، 29 فبراير، اختلاف تاريخ واحد بين جدولين، الالتفاف عبر 31 ديسمبر.

## 6. الحساب الفلكي للطلوع الفجري (الميزة 5) — Dart صافٍ (D8، D9)

لا توجد مكتبة Dart فلكية مستقرة ومشهورة، فالكود منّا وفق خوارزميات Jean Meeus «Astronomical Algorithms» (الطبعة 2):

| المكوّن | الطريقة | الدقة |
|---|---|---|
| الوقت | التاريخ اليولياني JD وفرق ΔT تقريبي (~69 ث) | يكفي لمستوى اليوم |
| موضع الشمس | Meeus فصل 25 (الدقة المنخفضة) | ~0.01° |
| موضع النجم | إحداثيات J2000 + الحركة الذاتية + المبادرة (Meeus فصل 21) | أقل من ثانية قوسية؛ التحوّل والزيغ مُهملان (<20″) |
| الزمن النجمي | GMST (Meeus 12.4) + خط الطول | — |
| الارتفاع | sin h = sin φ sin δ + cos φ cos δ cos H | — |
| الانكسار | صيغة Sæmundsson | — |

النجوم: سهيل = α Carinae (Canopus، قدر −0.74). الثريا = η Tauri (Alcyone) كنقطة مرجعية للعنقود. الإحداثيات من فهرس Hipparcos/SIMBAD وتُذكر في الكود.

**المعيار (قوس الرؤية Arcus Visionis):**
لكل يوم محلي D في نافذة بحث (سهيل: 15 يوليو – 30 سبتمبر؛ الثريا: 15 مايو – 15 يوليو):
1. أوجد بالتنصيف اللحظة t قبل شروق الشمس التي يبلغ فيها الارتفاع الظاهري للنجم `h_star`.
2. احسب ارتفاع الشمس عند t.
3. النجم مرئي في D إذا كان ارتفاع الشمس ≤ `−AV`.
4. تاريخ الطلوع = أول يوم مرئي بعد أيام غير مرئية.

المعاملات الأولية (تُعاير على القيم المرجعية): سهيل `h_star = 1°`، `AV ≈ 10.5°`؛ الثريا `h_star = 1°`، `AV ≈ 15°`. تُحفظ ثوابت في `astronomy/heliacal_params.dart` مع مصدر قيمها. المعايرة: نضبط `AV` لكل نجم حتى تكون كل القيم المرجعية (5 مدن على الأقل من المراجع، الحقل `referenceRisings`) ضمن ±يومين، ويبقى ذلك اختباراً دائماً.

الأداء: ~80 يوماً × ~40 خطوة تنصيف لكل نجم ← أجزاء من الثانية؛ تُخزَّن النتيجة لكل (مدينة، سنة).

اختبارات: الترتيب الجغرافي (مسقط ≤ الرياض ≤ الكويت لسهيل في كل سنة 2025–2040)، القيم المرجعية ±يومين، موضع الشمس والنجم مقابل أمثلة Meeus المحلولة (25.a و21.b)، ثبات النتيجة بين السنوات (فرق ≤ يوم بين سنتين متتاليتين).

علاقة الحساب بالجدول (سؤال SPEC 4، D10): الحساب **لا يغيّر** الجدول. الدائرة تعرض الجدول المعتمد، وصفحة سهيل/الثريا وتنبيههما يستخدمان التاريخ المحسوب لمدينة المستخدم.

## 7. الموقع والمدينة (الميزتان 3 و4) (D11)

- إذن **الموقع التقريبي** فقط: أندرويد `ACCESS_COARSE_LOCATION` وحده، آيفون `NSLocationDefaultAccuracyReduced = true`.
- قراءة واحدة: `Geolocator.getCurrentPosition(accuracy: low, timeLimit: 10s)`؛ لا بث ولا خلفية.
- `NearestCity` (Dart صافٍ): مسافة هافرساين لأقرب مدينة في `cities.json`. إن زادت عن **250 كم** ← «منطقتك خارج نطاق الجداول» ثم قائمة المدن.
- **لا تُحفظ الإحداثيات**؛ يُحفظ معرّف المدينة فقط، وحساب سهيل يستخدم إحداثيات المدينة. (أقل من المسموح في SPEC، والدقة نفسها على مستوى المدينة.)
- رفض الإذن/فشل/تجاوز 10 ث ← قائمة المدن مباشرة. «تحديد موقعي مرة أخرى» في الإعدادات.
- قائمة المدن: بحث بالاسم العربي مع تطبيع (إزالة التشكيل، أ/إ/آ ← ا، ة ← ه، ى ← ي).

## 8. التاريخ الهجري (الميزة 2) (D12)

- مكتبة `hijri` (جدول أم القرى المضمّن، المعتمد على جداول R. H. van Gent) مغلّفة في `lib/src/hijri/hijri_date.dart`، فلا تعتمد الواجهة على المكتبة مباشرة.
- أسماء الأشهر في ARB (`hijriDate` بصيغة select)، والأرقام عبر `intl`.
- اختبار 20 تاريخاً من تقويم أم القرى الرسمي (2025–2035) قبل إغلاق الميزة؛ الموجود الآن عيّنة من تاريخين.

## 9. التنبيهات المحلية (الميزة 8) (D13)

**المخطِّط** `NotificationPlanner` (Dart صافٍ): `plan(now, city, engine, heliacal, settings) → List<PlannedNotification>`.
- أفق 365 يوماً من اليوم، الساعة 08:00 بتوقيت الجهاز.
- المواسم المهمة (عناصر `important: true`: سهيل، الوسم، المربعانية، برد العجايز، الثريا، جمرة القيظ) إن كان مفتاحها مفعّلاً؛ سهيل والثريا بتاريخهما المحسوب.
- بداية كل دَرّ إن كان مفتاحها مفعّلاً.
- إزالة التكرار: (العنصر، اليوم) مرة واحدة.
- ترتيب زمني، ثم قصّ إلى **60** (حد آيفون 64 معلقاً، مع هامش 4). في الحالة الكاملة (6 مهمة + ~37 دَرّاً في السنة ≈ 43) يكفي الأفق كاملاً؛ القص احتياط.
- المعرّف ثابت: `yyyymmdd * 100 + slot` (يقع ضمن int32).
- الحمولة: `/item/<itemId>` ← go_router يفتح الصفحة عند الضغط (ومن حالة التطبيق المغلق عبر `getNotificationAppLaunchDetails`).
- النص من ARB: «دخل {الموسم} اليوم في {المنطقة}».

**المُجدوِل** `NotificationScheduler` (flutter_local_notifications + timezone + flutter_timezone):
- عند كل فتح/عودة للواجهة، وتغيّر المدينة أو الإعدادات: `cancelAll()` ثم جدولة الخطة (عملية حتمية، فلا تكرار).
- `zonedSchedule` بوضع `AndroidScheduleMode.inexactAllowWhileIdle` (لا يحتاج إذن المنبهات الدقيقة؛ قد يتأخر دقائق) (D13).
- المنطقة الزمنية من `FlutterTimezone.getLocalTimezone()`؛ تغيّرها يُعالج عند الفتح التالي.
- الإذن يُطلب بعد اختيار المنطقة (أندرويد 13+ و آيفون). إن رُفض تظهر ملاحظة في الإعدادات.
- اختبار الوحدة يغطي المخطِّط بالكامل؛ «تغيير تاريخ الجهاز» اختبار يدوي في TESTERS.md.

## 10. زر «أبلغ عن خطأ» بلا خادم (الميزة 9) (D14)

`ReportService.report(itemName, regionName, date, appVersion)`:
1. إن وُجد `REPORT_FORM_URL` (نموذج خارجي مع حقول معبأة مسبقاً) ← يُفتح في المتصفح.
2. وإلا/أو عند الفشل: `mailto:REPORT_EMAIL` بعنوان ونص معبأين.
3. إن لم يُفتح شيء: نافذة فيها نص البلاغ والعنوان مع زر «نسخ».

- القيم من `--dart-define-from-file=config/app_config.json` (ليست أسراراً؛ لكن لا تُكتب في الكود). `config/app_config.example.json` في git، و`config/app_config.json` مستثنى منه. إن كانت القيمتان فارغتين يظهر خيار «نسخ» فقط.
- لا يُرسل شيء تلقائياً؛ لا مدينة ولا إحداثيات ولا معرّف جهاز. نسخة التطبيق من `package_info_plus`.

## 11. الواجهة

- الدائرة: `CustomPainter` بحلقات (الأشهر، الدرور، المواسم، النجوم، مواسم الجو)، والزاوية من رقم اليوم في السنة. اللمس: تحويل الإحداثيات القطبية إلى (حلقة، يوم) ← عنصر. التدوير بالسحب يغيّر `selectedDateProvider`.
- كل معلومة مهمة تُعرض أيضاً كنص عادي تحت الدائرة (يتكبّر مع خط الجهاز)، وللدائرة `Semantics` لقارئ الشاشة.
- خط عربي مضمّن (لا تحميل وقت التشغيل). الألوان والرموز من DESIGN.md، ومن صنعنا بالكامل.

## 12. الأمان والخصوصية

- لا مفاتيح ولا أسرار في التطبيق أصلاً (لا خادم). أي ملف `.env` مستثنى من git.
- البيانات المحفوظة على الجهاز فقط: معرّف المدينة، مفتاحا التنبيهات، انتهاء الإعداد الأولي.
- لا تحليلات ولا تقارير أعطال ولا إعلانات (D15).
- أندرويد الإصدار: بلا `INTERNET` (Flutter يضيفه في debug/profile فقط). أي مكتبة تضيفه تُرفض أو يُزال إذنها صراحةً.
- قواعد أمان Firebase: لا تنطبق (لا Firebase في النسخة الأولى).

## 13. إعدادات المنصات (تُنفّذ مع ميزاتها؛ لم تُختبر هنا لعدم وجود Android SDK وXcode)

أندرويد (`AndroidManifest.xml`، `build.gradle.kts`):
- `ACCESS_COARSE_LOCATION`، `POST_NOTIFICATIONS`، `RECEIVE_BOOT_COMPLETED` + مستقبلات flutter_local_notifications (لإعادة الجدولة بعد إعادة التشغيل).
- `<queries>` لنيّات `mailto` و`https` (url_launcher على أندرويد 11+).
- `coreLibraryDesugaring` (مطلوب لـ flutter_local_notifications).

آيفون (`Info.plist`، `AppDelegate.swift`):
- `NSLocationWhenInUseUsageDescription` (بالعربية)، `NSLocationDefaultAccuracyReduced = true`.
- `CFBundleDevelopmentRegion = ar`، `CFBundleLocalizations = [ar]`.
- مندوب `UNUserNotificationCenter` حسب توثيق flutter_local_notifications.

## 14. المكتبات (الإصدارات المثبّتة فعلاً في pubspec.lock)

| المكتبة | الإصدار | الغرض |
|---|---|---|
| Flutter / Dart | 3.47.6 / 3.13.5 (stable) | الإطار |
| flutter_localizations + intl | SDK / 0.20.3 | العربية، الأرقام والتواريخ |
| flutter_riverpod | 3.4.3 | إدارة الحالة |
| go_router | 18.0.2 | التنقل وفتح الصفحات من التنبيه |
| hijri | 3.0.1 | أم القرى بلا إنترنت |
| geolocator | 14.1.1 | قراءة الموقع التقريبي مرة واحدة |
| flutter_local_notifications | 22.3.1 | التنبيهات المجدولة على الجهاز |
| timezone | 0.11.1 | الجدولة بالتوقيت المحلي |
| flutter_timezone | 5.1.0 | اسم المنطقة الزمنية للجهاز |
| shared_preferences | 2.5.5 | حفظ الإعدادات |
| url_launcher | 6.3.2 | فتح النموذج/البريد |
| package_info_plus | 10.2.2 | نسخة التطبيق في البلاغ |
| flutter_lints (تطوير) | 6.0.0 | قواعد التحليل |

غير مستخدم عمداً: Firebase، google_fonts (يحمّل من الإنترنت)، أي مكتبة تحليلات، permission_handler (البلجنات تطلب أذوناتها)، مكتبات توليد الكود.

## 15. الاختبارات

| المستوى | ماذا | أين |
|---|---|---|
| وحدة | المحرك (366×4×16 سنة)، المدقق، الفلك (Meeus + مرجعي ±2 + ترتيب المدن)، الهجري (20 تاريخاً)، أقرب مدينة، المخطِّط (حد 60، التكرار، المفاتيح) | `test/engine`، `test/astronomy`، ... |
| بيانات | `validate_tables` على الأصول الحقيقية (يفشل في الإطلاق إن وُجدت مسودة) | `test/tables_test.dart` + `tool/` |
| واجهة | RTL، العبارة الثابتة، فتح الصفحة من الدائرة، أكبر حجم خط بلا فيضان | `test/widgets` |
| يدوي | وضع الطيران، تغيير تاريخ الجهاز للتنبيه، رفض الأذونات | TESTERS.md |

الأوامر في CLAUDE.md.
