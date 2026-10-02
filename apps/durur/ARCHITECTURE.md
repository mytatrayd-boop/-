# معمارية «ديرة الدرور» — ARCHITECTURE

> المرجع: SPEC.md وIDEA.md. أسباب القرارات في DECISIONS.md (يُشار إليها بـ D1، D2 ...).

## 1. الصورة العامة

- تطبيق Flutter واحد لآيفون وأندرويد، **بلا خادم ولا Firebase ولا تسجيل دخول** (D1).
- كل البيانات مضمّنة في التطبيق كأصول JSON، وكل الحساب على الجهاز.
- لا يحتاج إنترنت ليعمل كاملاً. الاستثناء الوحيد (D21): تحقق أسبوعي اختياري عن **حزمة بيانات موقّعة** (جداول + تقويم أم القرى) من استضافة ملفات ثابتة، بلا أي بيانات عن المستخدم (§16). لذلك تحتاج نسخة أندرويد إذن `INTERNET` (يعدّل D15).
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
│  │  ├─ hijri_umm_al_qura.json  # بدايات الأشهر الهجرية (D22، §16.6)
│  │  └─ regions/
│  │     ├─ najd.json            # جدول كل منطقة: الدرور، المواسم، النجوم، مواسم الجو
│  │     ├─ kuwait.json
│  │     ├─ uae_oman.json
│  │     └─ <الرابعة>.json      # بانتظار قرار المالك
│  └─ fonts/                     # خط عربي مضمّن برخصة OFL (يحدده DESIGN.md)
├─ config/
│  └─ app_config.example.json    # إعدادات البناء (رابط نموذج البلاغ وحقوله). ليست أسراراً
├─ lib/
│  ├─ main.dart                  # ProviderScope + DururApp
│  ├─ l10n/                      # app_ar.arb + الملفات المولّدة (gen-l10n)
│  └─ src/
│     ├─ app.dart                # MaterialApp.router، اللغة، الاتجاه، الثيم
│     ├─ routing/                # go_router: / ، /item/:id ، /dar/:regionId/:start ، /about/origin ، /settings ، /settings/sources ، /city ، /onboarding (+ /location ، /city ، /notifications)؛ `app_routes.dart` = بناء المسارات (حمولات التنبيه)
│     ├─ domain/                 # [Dart صافٍ] النماذج: Region, City, Item, Period, DayInfo, WeatherSymbol, Approval, Source
│     ├─ engine/                 # [Dart صافٍ] CalendarEngine, YearIndex, TableValidator
│     ├─ astronomy/              # [Dart صافٍ] angles.dart, time.dart, sun.dart, stars.dart, sidereal.dart, precession.dart, horizon.dart (الارتفاع والانكسار), heliacal_params.dart, heliacal.dart
│     ├─ hijri/                  # HijriDate، UmmAlQuraCalendar (جدول بيانات، D22)، HijriTableValidator
│     ├─ updates/                # DataUpdater، BundleVerifier، SignedManifest، UpdateStore، UpdateFetcher، isCheckDue، trusted_keys (§16، D21)
│     ├─ repository/             # TableRepository (تحميل JSON)، SettingsRepository (shared_preferences)
│     ├─ location/               # LocationService (geolocator)، NearestCity [Dart صافٍ]
│     ├─ notifications/          # NotificationPlanner [Dart صافٍ]، NotificationScheduler (البلجن)
│     ├─ report/                 # ReportService: نموذج ← نسخ (Dart صافٍ، §10)
│     ├─ providers.dart          # كل مزوّدات Riverpod في مكان واحد
│     └─ features/
│        ├─ onboarding/          # شرح الموقع ← الإذن ← المدينة ← إذن التنبيهات
│        ├─ home/                # الشاشة الرئيسية + dial/ (CustomPainter + اختبار اللمس)
│        ├─ item_detail/         # صفحة النجم/الموسم/الدَّرّ: ورقة سفلية وصفحة كاملة (الميزة 7)
│        ├─ about/               # صفحة «أصل التقويم» (D24)
│        ├─ report/              # ورقة البلاغ ومحتواه (§10، الميزة 9)
│        ├─ city_picker/         # قائمة المدن مع البحث
│        └─ settings/
├─ test/                         # نفس تقسيم lib/src
│  ├─ domain/ engine/ hijri/ formatting/ widgets/ helpers/  (+ astronomy/ location/ notifications/ updates/ مع ميزاتها)
│  └─ fixtures/                  # جداول تجريبية صغيرة للاختبار
└─ tool/
   ├─ validate_tables.dart       # يتحقق من الجداول؛ مع --release يفشل إن وُجد سجل غير معتمد (D16)
   ├─ gen_hijri_table.dart       # يولّد hijri_umm_al_qura.json مرة واحدة من مكتبة hijri (D22)
   └─ sign_bundle.dart           # keygen: زوج مفاتيح Ed25519 (الخاص في ملف خارج المستودع)؛ sign: يبني bundle-<seq>.json ويوقّع manifest.json (§16.3، الميزة 11)
```

## 3. إدارة الحالة — Riverpod (D3)

مزوّدات يدوية (بلا توليد كود) في `lib/src/providers.dart`:

**المبنيّ فعلاً (الميزات 1، 2، 2ب، 3، 4، 5، 6، 7، 8، 9، 11):**

| المزوّد | النوع | الوظيفة |
|---|---|---|
| `sharedPreferencesProvider` | `Provider<SharedPreferences>` | يرمي `UnimplementedError` افتراضياً؛ يُستبدل في `main()` بنسخة محمّلة مسبقاً (`SharedPreferences.getInstance()` قبل `runApp`)، وفي الاختبارات بنسخة وهمية |
| `settingsRepositoryProvider` | `Provider<SettingsRepository>` | غلاف المفاتيح المحفوظة: `cityId`، `onboardingDone`، `notifyImportant` (افتراضي true)، `notifyDar` (افتراضي false)، `theme` (`ThemeChoice`)، `digits` (`DigitStyle`)؛ القيم الافتراضية لا تُكتب؛ الحفظ الفاشل يرمي `SettingsSaveException` |
| `embeddedTablesLoaderProvider` | `Provider<Future<Tables> Function()>` | يحمّل الجداول المضمّنة (`TableRepository().load`)؛ الملاذ الأخير دائماً (الميزة 11) |
| `tablesProvider` | `FutureProvider<Tables>` | المضمّنة، ثم الحزمة المثبّتة فوقها إن اجتازت التحقق من جديد (`loadInstalledTables`، §16.4)؛ مرة عند الفتح، وتُعاد بـ `invalidate` بعد قبول حزمة (§16.5)؛ بلا إعادة محاولة تلقائية (`retry: null`)؛ إعادة المحاولة بزر في الواجهة. أثناء إعادة التحميل تبقى الجداول السابقة معروضة في الرئيسية وقائمة المدن (بلا وميض) |
| `hijriCalendarProvider` | `Provider<UmmAlQuraCalendar?>` | جدول أم القرى من `tablesProvider` (D22)، `null` قبل اكتمال التحميل؛ يتحدث مع أي إعادة تحميل للجداول (§16.5) |
| `settingsProvider` | `NotifierProvider<SettingsController, Settings>` | المدينة، انتهاء الإعداد الأولي، مفتاحا التنبيهات، السمة، الأرقام (الميزة 8)؛ كل دالة (`selectCity`، `completeOnboarding`، `setNotifyImportant`، `setNotifyDar`، `setTheme`، `setDigits`) تحفظ أولاً ثم تغيّر الحالة |
| `digitStyleProvider` | `Provider<DigitStyle>` | شكل الأرقام (١٢٣/123، DESIGN 8.7)؛ يُمرَّر إلى `formatInteger`/`localizeDigits` ودوال التواريخ ونصوص الدائرة (الميزة 8) |
| `currentCityProvider` | `Provider<City?>` | المدينة المختارة، أو `null` إن لم تُختر أو لم تعد في القائمة أو لم تُحمَّل الجداول |
| `currentRegionProvider` | `Provider<Region?>` | منطقة المدينة المختارة (`city.regionId`) |
| `engineProvider` | `Provider<CalendarEngine?>` | محرك جدول منطقة المدينة الحالية (`CalendarEngine.fromTables`، ومعه جدول المُعيرة عند الاستعارة، D24) |
| `dayInfoProvider` | `Provider.family<DayInfo?, DateTime>` | نتيجة المحرك ليوم، أو `null` بلا مدينة/جداول. المفتاح المقرّب لمنتصف الليل يُفحص بـ `assert` |
| `yearIndexProvider` | `Provider.family<YearIndex?, int>` | كل أيام سنة لمنطقة المدينة (تغذي حلقات الدائرة) (الميزة 6) |
| `hasUnapprovedDataProvider` | `Provider<bool>` | في البيانات سجل غير معتمد ← شريط «بيانات تجريبية» أعلى كل الشاشات (`DraftBannerFrame` في `MaterialApp.builder`) (الميزة 6) |
| `clockProvider` | `Provider<DateTime Function()>` | ساعة الجهاز (`DateTime.now`)؛ تُستبدل في الاختبارات بوقت ثابت (الميزة 6) |
| `todayProvider` | `NotifierProvider<TodayController, DateTime>` | اليوم المحلي مقرّباً؛ مؤقت حتى منتصف الليل التالي، و`refresh()` عند العودة للواجهة (`AppLifecycleListener` في الرئيسية) (الميزة 6) |
| `selectedDateProvider` | `NotifierProvider<SelectedDateController, DateTime>` | التاريخ المعروض مقرّباً ومحصوراً في 2025-01-01..2040-12-31 (`DateRange`)؛ يتبع اليوم الجديد فقط إن كان يعرض اليوم؛ `select` و`shiftDays` و`backToToday` (الميزة 6) |
| `locationServiceProvider` | `Provider<LocationService>` | غلاف geolocator (قراءة واحدة بدقة low ومهلة 10 ثوانٍ، بلا بث)؛ يُستبدل بنسخة وهمية في الاختبارات (الميزة 4) |
| `cityLocatorProvider` | `Provider<CityLocator>` | يقرأ الموقع مرة واحدة ويعيد أقرب مدينة أو سبب الفشل (Denied / Unavailable / Timeout / OutOfRange > 250 كم)؛ لا يعيد الإحداثيات ولا يحفظها (D11) |
| `heliacalProvider` | `Provider.family<HeliacalDates?, (String cityId, int year)>` | طلوع سهيل والثريا بإحداثيات المدينة (مخزّن لكل مدينة وسنة)؛ `null` قبل تحميل الجداول أو لمدينة غير موجودة؛ يُعاد مع إعادة تحميل الجداول (الميزة 5، D28) |
| `currentHeliacalProvider` | `Provider.family<HeliacalDates?, int year>` | طلوع سهيل والثريا للمدينة المختارة، أو `null` بلا مدينة (الميزة 5)؛ تقرؤه صفحة سهيل/الثريا (الميزة 7) |
| `urlOpenerProvider` | `Provider<Future<bool> Function(Uri)>` | يفتح رابطاً عاماً في المتصفح (`url_launcher`، رابطا صفحة المصادر، D27)؛ **يرفض أي رابط ليس https بنطاق** (`isOpenableUrl`) ويعيد false بلا محاولة؛ يُستبدل في الاختبارات (الميزة 7، الإصلاح مع 8)؛ ويفتح نموذج البلاغ أيضاً (الميزة 9) |
| `reportConfigProvider` | `Provider<ReportConfig>` | `REPORT_FORM_URL` و`REPORT_FORM_FIELDS` من `--dart-define-from-file` (§10) (الميزة 9) |
| `clipboardWriterProvider` | `Provider<Future<void> Function(String)>` | ينسخ نص البلاغ للحافظة (الميزة 9) |
| `reportServiceProvider` | `Provider<ReportService>` | نموذج ← نسخ، يفتح عبر `urlOpenerProvider` فقط (§10) (الميزة 9) |
| `appVersionProvider` | `FutureProvider<String>` | نسخة التطبيق للبلاغ (`package_info_plus`، `version+buildNumber`) (الميزة 9) |
| `notificationSchedulerProvider` | `Provider<NotificationScheduler>` | `LocalNotificationScheduler` (البلجن)؛ يُستبدل بـ `FakeNotificationScheduler` في الاختبارات (`appOverrides` يضعه افتراضياً) (الميزة 8) |
| `notificationPermissionProvider` | `AsyncNotifierProvider<…, bool>` | هل إذن التنبيهات ممنوح؛ `refresh()` عند العودة للواجهة، `request()` من شرح التنبيهات ومن تشغيل مفتاح والإذن غير ممنوح (الميزة 8) |
| `notificationInputsProvider` | `Provider<NotificationInputs>` | (المدينة، المفتاحان، الجداول، اليوم): تغيّر أيٍّ منها يعيد الجدولة (الميزة 8) |
| `notificationSyncProvider` | `NotifierProvider<NotificationSyncController, NotificationSyncStatus>` | يعيد الجدولة عند الفتح وتغيّر المدخلات وعند العودة للواجهة (`sync()`؛ تُقرأ المنطقة الزمنية من جديد)؛ لا يعيد إن تطابقت بصمة الخطة والمنطقة الزمنية مع آخر جدولة ناجحة؛ الحالة `failed` تُظهر رسالة في الإعدادات (الميزة 8) |

| `updateConfigProvider` | `Provider<UpdateConfig>` | `UPDATE_BASE_URL` من `--dart-define-from-file`؛ فارغ أو ليس https ← معطّل (الميزة 11) |
| `trustedKeysProvider` | `Provider<Map<String, String>>` | المفاتيح العامة الموثوقة (`trusted_keys.dart`، فارغة حتى يولّد المالك المفتاح)؛ مفتاح مؤقت في الاختبارات (الميزة 11) |
| `bundleVerifierProvider` | `Provider<BundleVerifier>` | فحوص القبول §16.3/16.6/16.7 (الميزة 11) |
| `updateStoreProvider` | `Provider<UpdateStore>` | الحزمة المثبّتة في `getApplicationSupportDirectory()/tables/` (الميزة 11) |
| `updateFetcherProvider` | `Provider<UpdateFetcher>` | `HttpUpdateFetcher` (`dart:io`)؛ وهمي في الاختبارات (الميزة 11) |
| `appBuildProvider` | `FutureProvider<int>` | رقم البناء (`package_info_plus`) لـ `minAppBuild` (الميزة 11) |
| `dataUpdaterProvider` | `Provider<DataUpdater>` | محاولة تحقق واحدة: البيان ← الحزمة ← التحقق ← التثبيت (الميزة 11) |
| `dataUpdateProvider` | `NotifierProvider<DataUpdateController, UpdateOutcome?>` | `maybeCheck()` بعد أول إطار وعند العودة للواجهة (`app.dart`) إن حان الموعد؛ بعد القبول `invalidate(tablesProvider)`؛ الحالة نتيجة آخر محاولة (الميزة 11) |

**توصية ملزمة للميزات القادمة:** مفتاح `dayInfoProvider` يُمرَّر **مقرّباً لمنتصف الليل** (`DateTime(d.year, d.month, d.day)`)، لا `DateTime.now()` مباشرة؛ وإلا يُنشأ مدخل family جديد في كل إعادة بناء (ذاكرة وحساب بلا فائدة). المحرك نفسه يأخذ التاريخ فقط، فالتقريب لا يغيّر النتيجة. `todayProvider` و`selectedDateProvider` يخزّنان القيمة مقرّبة أصلاً.


الاختبارات تستبدل المزوّدات بـ `overrides` (جداول تجريبية، `SharedPreferences` وهمية، تاريخ ثابت) بلا مكتبات محاكاة (`test/helpers/app_harness.dart`).

## 4. نموذج البيانات وتخزينها (D5، D6)

### المبادئ
- **`source` و`approval` إلزاميان في كل سجل** (المناطق، المدن، العناصر، كل سجل في جداول المناطق، جدول الهجري). غيابهما أو `source.title` فارغ ← **خطأ تحليل** يرفض الملف كله (لا تحذير). `approval.status` ∈ {`draft`، `approved`}، ومع `--release` يلزم `reviewer` و`date` غير فارغين. العناصر في `items.json` لها `sources` (قائمة، والمدقق يرفضها فارغة) بدل `source`.
- النصوص المعروضة من البيانات بصيغة `{"ar": "..."}` لتُضاف `"en"` لاحقاً بلا تغيير المخطط.
- التواريخ داخل الجداول بصيغة `"MM-DD"` (يوم وشهر، تتكرر كل سنة).
- **الطبقات المتصلة** (الدرور، المواسم الكبيرة، النجوم) تُخزَّن **بتاريخ البداية فقط**؛ النهاية = اليوم السابق لبداية التالي (دورياً عبر نهاية السنة). هذا يجعل الفجوات والتداخل مستحيلة بالبناء.
- **مواسم الجو** لها بداية ونهاية، وقد توجد بينها فجوات (لا موسم جو)، ولا يُسمح بالتداخل داخل المنطقة (D24 لمربعانية القيظ).
- رموز الجو مجموعة مغلقة من **17 رمزاً** (D23): `hot, very_hot, mild, cool, cold, very_cold, wind, wind_strong, rain, heavy_rain, thunder, cloud, dust, humidity, fog, sea_calm, sea_rough`. مبنيّة كلها في `WeatherSymbol` منذ الميزة 6، ولكل رمز أيقونة مرسومة منّا (`features/common/weather_icon.dart`، `switch` شامل يمنع رمزاً بلا أيقونة) واسم في ARB (`weatherSymbolName`). الإضافة بعدها بقرار وتحديث متجر (حزمة البيانات لا تضيف رموزاً، §16.7).
- `meta.json`: `schemaVersion` (حالياً 1)، `dataVersion` (نص؛ بادئة `sample` ممنوعة في الإطلاق)، و`dataSeq` (عدد صحيح ≥ 0، اختياري وافتراضيه 0 = لم تُنشر حزمة بعد؛ §16.3).

### أمثلة (القيم توضيحية وغير معتمدة)

`regions.json`
```json
[{ "id": "najd", "name": {"ar": "نجد"}, "leapDayRule": "extend_feb28",
   "source": {"title": "...", "author": "...", "year": 0, "page": "..."},
   "approval": {"status": "draft", "reviewer": null, "date": null} }]
```

`cities.json`
```json
[{ "id": "riyadh", "name": {"ar": "الرياض"}, "country": "SA", "area": "najd",
   "lat": 24.6877, "lon": 46.7219, "regionId": "najd",
   "regionNote": "ربط مؤقت: ...",
   "source": {"title": "GeoNames ...", "author": "GeoNames", "page": "geonameId 108410", "url": "https://www.geonames.org/108410"},
   "approval": {...} }]
```
- `country`: رمز ISO من مجموعة مغلقة (`SA, KW, AE, OM, QA, BH`، ترتيبها ترتيب شرائح التصفية).
- `area` (اختياري): المنطقة داخل الدولة (للسعودية: `najd`، `eastern`، `hijaz`، `south`، `north`)، للمراجعة فقط.
- `regionNote` (اختياري): سبب الربط إن كان مؤقتاً، للمراجع فقط، **لا يُعرض للمستخدم**.
- الإحداثيات من GeoNames (CC BY 4.0)؛ الإشارة إليها في صفحة المصادر إلزامية (D27).

`items.json` (كتالوج كل ما له صفحة)
```json
[{ "id": "suhail", "kind": "star", "name": {"ar": "سهيل"},
   "important": true, "dateMethod": "heliacal", "gender": "m",
   "definition": {"ar": "سطر أول\nسطر ثانٍ"}, "proverb": {"ar": "..."},
   "weather": ["hot", "humidity"], "weatherNote": {"ar": "..."},
   "referenceRisings": [{"cityId": "kuwait", "year": 2026, "date": "2026-08-24", "source": {...}}],
   "sources": [{...}], "approval": {...} }]
```
`kind`: `star` | `majorSeason` | `weatherSeason` (حُذف `dar` مع الميزة 7، D26: المحلل يرفضه). `dateMethod`: `table` | `heliacal`.
`gender` (D30، DESIGN §13 «جنس النجم»): `"m"` | `"f"` (`StarGender`)، جنس النجم لغوياً لاختيار الفعل والضمير في النصوص («طلعت الثريا…»، «تطلع…»). **إلزامي** حين `dateMethod: heliacal` (سهيل `m`، الثريا `f`): غيابه أو قيمة غيرهما ← **خطأ تحليل** يرفض الملف (فيفشل `validate_tables` أيضاً)؛ واختياري لغيرها وافتراضه `m`. يُمرَّر `item.gender.code` إلى مفاتيح ARB بصيغة `{gender, select, f{…} other{…}}` (والجمع متداخل داخل الاختيار في `detailStarRisenAgo`): `notifStarTitle`، `notifStarBody`، `detailStarRisesOn`، `detailStarRisesToday`، `detailStarRisenAgo`. المخطط نفسه في `research/drafts/items.json`.

`regions/najd.json`
```json
{ "regionId": "najd",
  "durur":         [{"start": "08-15", "number": 1, "name": {"ar": "العشر"}, "seasonId": "safari",
                     "weather": ["hot"], "weatherNote": {"ar": "..."}, "source": {...}, "approval": {...}}],
  "majorSeasons":  [{"itemId": "safari", "start": "08-15"}],
  "stars":         [{"itemId": "suhail", "start": "08-24"}],
  "weatherSeasons":[{"itemId": "wasm", "start": "10-16", "end": "12-06"}] }
```
(كل سجل في `majorSeasons` و`stars` و`weatherSeasons` يحمل أيضاً `source` و`approval`؛ حُذفا من المثال للاختصار.)

- `seasonId` في الدَّرّ = **«المئة» التي ينتمي إليها الدَّرّ في عدّ الدرور نفسه** (الصفري/الشتاء/الصيف/القيظ)، لا الموسم الكبير الفعّال في طبقة `majorSeasons`. يُعرض «دَرّ {dar} من {season}» منه (D25).
- **استعارة الدرور (D24، السعودية):** منطقة بلا درور خاصة بها تكتب `"durur": []` وحقل:
  ```json
  "dururBorrow": { "fromRegionId": "uae_oman",
                   "note": {"ar": "الدرور حساب خليجي ساحلي ... وليس من التقويم النجدي ..."},
                   "source": {...}, "approval": {...} }
  ```
  المحرك يحسب الدَّرّ من جدول المنطقة المُعيرة (بقاعدة 29 فبراير الخاصة بها)، وبقية الطبقات من جدول المنطقة نفسها. `DayInfo.dururRegionId` يحمل معرّف المُعيرة (يساوي `regionId` في الحالة العادية) لتعرض الواجهة السطر الثابت واسم المُعيرة. **مبنيّ (الميزة 6):** `DururBorrow` في `region_table.dart` (سجل `Sourced` يدخل في `allRecords` فيخضع للاعتماد وبوابة الإطلاق)، و`RegionTable.borrowsDurur`، و`DayInfo.borrowsDurur`. `najd.json` التجريبي يستعير `uae_oman` بالسطر من research/SAUDI.md (مسودة).

### التحقق (`TableValidator` + `tool/validate_tables.dart` + اختبار)
- الطبقات المتصلة: بدايات مرتبة وفريدة وغير فارغة؛ الغطاء الكامل مضمون بالبناء (D6).
- مواسم الجو بلا تداخل (فحص كل يوم من سنة غير كبيسة).
- كل `itemId` (والـ `seasonId`) موجود في `items.json` **ومن النوع الصحيح** (`star`/`majorSeason`/`weatherSeason`). كل عنصر: معرّف فريد، تعريف ≤ سطرين، مصدر واحد على الأقل.
- `seasonId`: القاعدة الحالية في الكود «يطابق الموسم الكبير الفعّال يوم بداية الدَّرّ» **تُستبدل** (D25) بـ: كل `seasonId` يشغل **مقطعاً واحداً متصلاً** من الدرور (دورياً)، ورقم الدَّرّ ≥ 1 وفريد داخل المقطع.
- `dururBorrow` (D24، **مبنيّ**): إما `durur` غير فارغ أو `dururBorrow`، لا الاثنان ولا لا شيء؛ المُعيرة موجودة، ليست المنطقة نفسها، ولها درور خاصة (لا سلاسل استعارة)؛ `note` غير فارغ (خطأ تحليل).
- **المدن:** معرّف فريد، `regionId` موجود في `regions.json`، خط العرض ضمن ±90 والطول ضمن ±180، و`country` ضمن المجموعة المغلقة (يرفضه المحلل).
- المناطق: العدد 4 (`expectedRegionCount`)، معرّف فريد، ولكل منطقة ملف جدول ولا ملف بلا منطقة؛ `regionId` في الملف يطابق اسمه.
- الهجري: `HijriTableValidator` (§16.6) ضمن المدقق نفسه إن وُجد الجدول.
- مع `--release`: أي `approval.status != approved` ← فشل؛ والمعتمد بلا `reviewer` أو `date` ← فشل؛ و`dataVersion` يبدأ بـ `sample` ← فشل (شرط الإطلاق).
- في وضع التطوير المسودات تحذير، ويظهر شريط «بيانات تجريبية غير معتمدة» إن وُجد سجل مسودة (`Tables.hasUnapproved`).

## 5. محرك الحساب (الميزة 1) — Dart صافٍ

`CalendarEngine(RegionTable)` ← `DayInfo resolve(DateTime localDate)`:

1. يؤخذ التاريخ المحلي فقط (يبدأ اليوم عند منتصف الليل بتوقيت الجهاز)، ويُحوَّل إلى `DateTime.utc(y, m, d)` لتجنب مشاكل التوقيت الصيفي في حساب الفروق.
2. `(شهر، يوم)`؛ 29 فبراير يُعامَل كـ 28 فبراير في تحديد السجل (`extend_feb28`)، فيطول ذلك الدَّرّ يوماً.
3. لكل طبقة متصلة: السجل الفعّال = آخر بداية ≤ (شهر، يوم)، وإلا آخر سجل في السنة (التفاف).
4. اليوم داخل الدَّرّ = عدد الأيام الفعلية من آخر حدوث لتاريخ بدايته + 1؛ وطوله = الأيام حتى البداية التالية (فيشمل 29 فبراير تلقائياً).
5. موسم الجو: السجل الذي يحتوي التاريخ أو لا شيء.
6. `DayInfo`: الدَّرّ (اسم، رقم، اليوم، الطول)، الموسم الكبير، موسم الجو؟، النجم، رموز الجو ووصفه، وتواريخ البداية/النهاية.

**الدرور المستعارة (D24، مبنيّ):** `CalendarEngine({region, table, dururRegion, dururTable})`، و`CalendarEngine.fromTables(tables, regionId)` يملأ المُعيرة تلقائياً؛ المُنشئ يرفض استعارة بلا جدول المُعيرة أو بجدول خاطئ أو بسلسلة. إن كان لجدول المنطقة `dururBorrow` يُبنى المحرك بجدول درور المنطقة المُعيرة (ومنطقتها لقاعدة 29 فبراير)، والخطوات 2–4 للدَّرّ تجري عليه؛ `DayInfo.dururRegionId` = المُعيرة. بقية الطبقات من جدول المنطقة نفسها.

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

المعيار **الرؤية بالعين المجردة** (قرار المدير، D28). المعاملات الحالية: سهيل `h_star = 1°`، `AV = 13.5°` (معايَر مؤقتاً على مراجع العين المجردة غير المعتمدة: الكويت ≈ 7/9 وأقصى الشمال ≈ 8/9؛ كانت القيمة الأولية 10.5° وتطابق رؤية المنظار)؛ الثريا `h_star = 1°`، `AV = 15°` (أولية، بلا معايرة لعدم وجود رصد بالعين المجردة). تُحفظ ثوابت في `astronomy/heliacal_params.dart` مع مصدر قيمها. المعايرة: نضبط `AV` لكل نجم حتى تكون كل القيم المرجعية (5 مدن على الأقل من المراجع، الحقل `referenceRisings`) ضمن ±يومين، ويبقى ذلك اختباراً دائماً.

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

- **منذ الميزة 2ب (D22، §16.6):** التحويل من جدول البيانات `assets/tables/hijri_umm_al_qura.json` عبر `UmmAlQuraCalendar` (`lib/src/hijri/umm_al_qura_calendar.dart`، Dart صافٍ، بحث ثنائي). الواجهة: **`HijriDate.fromGregorian(DateTime date, UmmAlQuraCalendar calendar)`** (يأخذ التاريخ فقط ويرمي `RangeError` خارج مدى الجدول). الجدول يُقرأ في التطبيق من `hijriCalendarProvider`.
- مكتبة `hijri` في **`dev_dependencies` فقط** (لا تدخل التطبيق): يستخدمها `tool/gen_hijri_table.dart` واختبار التطابق.
- أسماء الأشهر الهجرية والميلادية في ARB (`hijriDate` و`gregorianDate` بصيغة select)، والنص يُبنى في `lib/src/formatting/date_labels.dart`.
- الأرقام العربية الهندية عبر `lib/src/formatting/digits.dart` (لا عبر `intl`، لأن `intl` يُخرج للغة `ar` أرقاماً لاتينية).
- الاختبارات: 28 تاريخاً مرجعياً (2025–2035)، وبدايات 54 شهراً، وتسلسل كل يوم 2025–2035 (`test/hijri/hijri_date_test.dart`، `test/formatting/date_labels_test.dart`). عند الانتقال للجدول **عُدّل فيها سطر التحميل فقط** (`loadAssetHijriCalendar()` من `test/helpers/hijri_asset.dart` وتمرير الجدول)؛ القيم المتوقعة لم تتغير. انظر الخلاف بين المصادر بعد أغسطس 2029 في STATUS.md.

## 9. التنبيهات المحلية (الميزة 8) (D13)

**المخطِّط** `NotificationPlanner` (Dart صافٍ): `plan(now, city, engine, heliacal, settings) → List<PlannedNotification>`.
- أفق 365 يوماً من اليوم، الساعة 08:00 بتوقيت الجهاز.
- المواسم المهمة (عناصر `important: true`: سهيل، الوسم، المربعانية، برد العجايز، الثريا، جمرة القيظ) إن كان مفتاحها مفعّلاً؛ سهيل والثريا بتاريخهما المحسوب.
- بداية كل دَرّ إن كان مفتاحها مفعّلاً.
- إزالة التكرار: (العنصر، اليوم) مرة واحدة.
- ترتيب زمني، ثم قصّ إلى **60** (حد آيفون 64 معلقاً، مع هامش 4). في الحالة الكاملة (6 مهمة + ~37 دَرّاً في السنة ≈ 43) يكفي الأفق كاملاً؛ القص احتياط.
- المعرّف ثابت: `yyyymmdd * 100 + slot` (يقع ضمن int32).
- الحمولة: `/item/<itemId>` للعناصر، و`/dar/<regionId>/<MM-DD>` لبداية الدَّرّ (D26) ← go_router يفتح الصفحة عند الضغط (ومن حالة التطبيق المغلق عبر `getNotificationAppLaunchDetails`). مسار لعنصر/دَرّ لم يعد موجوداً ← الرئيسية.
- النص من ARB: «دخل {الموسم} اليوم في {المنطقة}». للدرور المستعارة (D24) يُذكر اسم المنطقة المُعيرة لا منطقة المستخدم.

**المُجدوِل** `NotificationScheduler` (flutter_local_notifications + timezone + flutter_timezone):
- عند كل فتح/عودة للواجهة، وتغيّر المدينة أو الإعدادات **أو الجداول بعد تحديث بيانات (§16.5)**: `cancelAll()` ثم جدولة الخطة (عملية حتمية، فلا تكرار).
- `zonedSchedule` بوضع `AndroidScheduleMode.inexactAllowWhileIdle` (لا يحتاج إذن المنبهات الدقيقة؛ قد يتأخر دقائق) (D13).
- المنطقة الزمنية من `FlutterTimezone.getLocalTimezone()`؛ تغيّرها يُعالج عند الفتح التالي.
- الإذن يُطلب بعد اختيار المنطقة (أندرويد 13+ و آيفون). إن رُفض تظهر ملاحظة في الإعدادات.
- اختبار الوحدة يغطي المخطِّط بالكامل؛ «تغيير تاريخ الجهاز» اختبار يدوي في TESTERS.md.

**مبنيّ (الميزة 8)، `lib/src/notifications/`:**
- `notification_planner.dart` (Dart صافٍ): `NotificationPlanner.plan(now, engine, items, heliacal(year), important, dar)` ← `PlannedNotification(id, date, kind, subject)` و`fireAt` = 08:00 محلياً. الأيام `[اليوم، اليوم+364]` وما لم تفت ساعته (يوم البداية بعد 8:00 لا يُجدول). `ItemSubject(item, heliacal)` / `DarSubject(record, dururRegionId, borrowed)`. العناصر `heliacal` (سهيل والثريا) من `heliacal(year)` لسنتي الأفق، **وإن كان الحساب null لسنة يُستعمل تاريخ بدايتها في جدول المنطقة** (مثل صفحة العنصر). الترتيب: التاريخ ← المهمة قبل الدَّرّ ← المعرّف، ثم القص إلى 60، ثم `slot` داخل اليوم. لا نصوص فيه.
- `notification_content.dart`: `buildScheduledNotification` ← العنوان/النص من ARB (`notifSeasonTitle` بمنطقة المستخدم، `notifStarTitle`/`notifStarBody` بالمدينة لما تاريخه فلكي وبجنس النجم `item.gender` («طلعت الثريا…»، D30)، `notifDarTitle`، و`notifDarTitleBorrowed` «… حسب حساب {المُعيرة}» للمستعيرة D24 — مفتاح جديد غير موجود في DESIGN §13، و`notifDarBody` بأسماء رموز الجو). **الحمولة** `AppRoutes.item(id, from: يوم التنبيه)` أو `AppRoutes.dar(regionId, MM-DD, from: …)` (تفتح الفترة التي بدأت يوم التنبيه حتى لو ضُغط لاحقاً)؛ `isNotificationPayload` يقبل `/item/<id>` و`/dar/<r>/<MM-DD>` فقط.
- `notification_scheduler.dart` (واجهة) و`local_notification_scheduler.dart`: تهيئة **بلا طلب إذن** (`DarwinInitializationSettings(request…: false)`)، `getNotificationAppLaunchDetails`، `FlutterTimezone` + `timezone/latest_all` (منطقة غير معروفة ← اللحظة نفسها بـ UTC)، `pendingNotificationRequests` ثم `cancelAllPendingNotifications` (لا `cancelAll`: المعروضة تبقى، D29) ثم `zonedSchedule(inexactAllowWhileIdle)` بقناتين `important`/`dar` (أسماؤهما من ARB)، وأيقونة `ic_stat_durur` (نجمة رباعية). `openAppNotificationSettings` لزر «فتح إعدادات الجهاز».
- `DururApp` (`app.dart`): يهيّئ المُجدوِل، ويفتح حمولة الضغط (والتشغيل من تنبيه) بـ `openNotificationPayload`: `backToToday` ← `go('/')` ← إطار ← `push(payload)` فيرجع زر الرجوع إلى الرئيسية على اليوم (DESIGN 8.9). `AppLifecycleListener.onResume` ← `refresh` للإذن و`sync()`. `themeMode` من الإعدادات.
- **بلا إذن:** آيفون يرفض إضافة التنبيه؛ الخطأ حينها لا يُحسب فشلاً (الحالة `idle`، ورسالة الفشل لا تظهر إلا والإذن ممنوح)، و`NotificationSyncController` يستمع لـ `notificationPermissionProvider` فيعيد الجدولة عند تحوّله إلى ممنوح.
- **هامش التأخر:** تنبيه اليوم يبقى في الخطة حتى 09:00 (`lateMargin`)؛ المُجدوِل يعيده بعد 10 ثوانٍ من لحظة الجدولة (ساعته لا بداية المزامنة) فقط إن كان ما يزال في `pendingNotificationRequests` (لم يصل بعد)، وإلا لا يُعاد (معيار 7)؛ السباق النادر في D29.
- **الحمولة:** `isNotificationPayload` يشترط مساراً مطلقاً، وتُهمل أثناء الإعداد الأولي (`onboardingDone = false`).
- **إعادة الجدولة:** فتح التطبيق، منح الإذن، تغيير المدينة، المفتاحين، «الأرقام» (DESIGN 8.7، بصمت: `digits` ضمن `NotificationInputs` وفي بصمة الخطة، فتُعاد حتى لو لم يتغير نص؛ لا نص تنبيه فيه رقم حالياً)، اليوم، المنطقة الزمنية (عند العودة)، وإعادة تحميل الجداول (`tablesProvider` ضمن المدخلات، جاهز للميزة 11). الجدولة تتم حتى بلا إذن (يُطبَّق الاختيار عند منحه).
- **الإذن:** شاشة `/onboarding/notifications` (`NotificationsIntroScreen`، DESIGN 8.2 د) بعد اختيار المدينة: «فعّل التنبيهات» يطلب الإذن ثم الرئيسية (قبول أو رفض)، «ليس الآن» بلا طلب. أندرويد 13+ `POST_NOTIFICATIONS`. **لا `SCHEDULE_EXACT_ALARM`** (D13: الوضع غير الدقيق يكفي ولا يحتاج إذناً يقيّده متجر Google).
- **انتهاء الإعداد الأولي:** `onboardingDone` يُحفظ عند الخروج من شرح التنبيهات. التوجيه: لا مدينة ← `/onboarding`؛ مدينة محذوفة ← `/onboarding/city`؛ مدينة بلا `onboardingDone` (أُغلق التطبيق قبل الشرح) ← `/onboarding/notifications`.
- **الإعدادات (DESIGN 8.7):** قسم «التنبيهات» (بطاقة «التنبيهات متوقفة من إعدادات جهازك.» + «فتح إعدادات الجهاز» إن لم يُمنح الإذن، رسالة فشل الجدولة، مفتاحان `SwitchListTile` 64dp، سطر الساعة)، وقسم «المظهر» (شرائح السمة والأرقام). تشغيل مفتاح والإذن مرفوض يطلبه مرة.

## 10. زر «أبلغ عن خطأ» بلا خادم (الميزة 9) (D14، قرار المالك النهائي: نموذج Google بلا بريد) — **مبنيّ**

**المسار: نموذج ← نسخ.** حذف بديل البريد (`mailto`) بقرار المالك النهائي (DECISIONS، آخر الملف): لا يظهر بريد المالك للمستخدمين، فلا `REPORT_EMAIL` ولا مسار `mailto` في الكود ولا `<queries>` له.

`lib/src/report/report_service.dart` (Dart صافٍ):
- `ReportConfig` من `--dart-define-from-file=config/app_config.json`:
  - `REPORT_FORM_URL`: رابط النموذج. يُقبل فقط إن كان **https بنطاق** (`isOpenableUrl`، نُقلت هنا وتُصدَّر من `providers.dart`)؛ أي قيمة أخرى (فارغة، http، mailto، javascript، file …) = لا نموذج.
  - `REPORT_FORM_FIELDS` (اختياري): تعبئة حقول نموذج Google مسبقاً، أزواج `اسم=entry.<رقم>` مفصولة بفواصل، مثل `item=entry.111,region=entry.222,date=entry.333,appVersion=entry.444,dataVersion=entry.555,details=entry.666`. الأسماء المسموحة فقط: `item` (اسم العنصر)، `region` (منطقة الجدول)، `date` (التاريخ المعروض `YYYY-MM-DD`)، `appVersion`، `dataVersion` (`dataVersion (dataSeq)`)، `details` (نص البلاغ كاملاً). أي زوج غير صالح (اسم آخر، أو معرّف ليس `entry.<رقم>`) يُهمل. نصّ واحد لا خريطة JSON لأن `--dart-define-from-file` يمرّر قيماً نصية فقط. المعرّفات تُؤخذ من «الحصول على رابط معبأ مسبقاً» في نموذج Google.
  - `config/app_config.example.json` في git بقيم فارغة، و`config/app_config.json` مستثنى منه. لا رابط ولا بريد في الكود.
- `ReportService.report(ReportMessage)`:
  1. لا نموذج صالح ← `copy` بلا أي محاولة فتح.
  2. نموذج **بحقول** ← يُفتح الرابط معبأً (القيم مرمّزة UTF-8، ومعاملات الرابط الأصلية تبقى) عبر `urlOpenerProvider` ← `formPrefilled`.
  3. نموذج **بلا حقول** ← يُنسخ نص البلاغ للحافظة **أولاً** ثم يُفتح النموذج كما هو ← `formWithCopiedText`.
  4. فشل الفتح (يعيد false أو يرمي) ← `copy`.
  5. فشل النسخ قبل الفتح (الحالة 3) ← `copyFailed` **بلا فتح**، فتعرض الورقة «تعذّر نسخ تفاصيل البلاغ…» (`reportCopyError`) لا «تعذّر فتح النموذج». لا يرمي.
- `ReportMessage`: `lines` (كل معلومة في سطر، من ARB) و`values` (قيم الحقول) و`text` (الأسطر بفاصل سطر؛ هو ما يُنسخ وقيمة `details`).

**المحتوى (`buildReportMessage` في `features/report/report_sheet.dart`):** العنصر (إن وُجد)، منطقة الجدول، التاريخ المعروض، نسخة التطبيق (`appVersionProvider` من `package_info_plus`: `version+buildNumber`)، نسخة البيانات (`meta.dataVersion` و`dataSeq`). **لا شيء غيرها:** لا مدينة ولا إحداثيات ولا معرّف جهاز أو عنصر. الأرقام حسب إعداد «الأرقام» في الأسطر، ولاتينية في قيم الحقول.

**الواجهة (`features/report/report_sheet.dart`، DESIGN 8.8):** ورقة سفلية `showReportSheet(context, itemName?, regionName?, date)`: العنوان (`header`) و«إغلاق»، سطر الشرح، بطاقة الملخص، ثم:
- لا نموذج: «نسخ تفاصيل البلاغ» وحده (زر أساسي) ← «تم نسخ تفاصيل البلاغ» (`liveRegion`)؛ وفشل النسخ (`_copy`) ← «تعذّر نسخ تفاصيل البلاغ. حاول مرة أخرى.» (`reportCopyError`، `ReportSheet.copyErrorKey`، بلون الخطأ) بلا تأكيد.
- نموذج: «متابعة إلى النموذج» ← معبأ: تُغلق الورقة؛ بلا تعبئة: تبقى الورقة برسالة «نسخنا تفاصيل البلاغ. الصقها في النموذج…» (`liveRegion`) مع زر النسخ؛ فشل الفتح: «تعذّر فتح النموذج…» مع زر النسخ؛ فشل النسخ قبل الفتح: «تعذّر نسخ تفاصيل البلاغ…» مع زر النسخ، ونجاح النسخ بعده يعيد زر النموذج.
- «لن يُرسل شيء حتى تضغط إرسال بنفسك.» دائماً. لا نعرض «تم الإرسال».
- التمرير `SingleChildScrollView` (تكبير 200%)، والأزرار 52dp.

**أماكن الزر:** أسفل صفحة النجم/الموسم/الدَّرّ (`ItemDetailView.reportKey`، زر ثانوي بعرض كامل؛ العنصر = الاسم، المنطقة = منطقة جدول التواريخ، التاريخ = التاريخ المرجعي للصفحة)، وصف «أبلغ عن خطأ» في «البيانات والمساعدة» بالإعدادات (بلاغ عام: منطقة المستخدم والتاريخ المعروض في الرئيسية)، وزر تحت «تعذّر حساب هذا اليوم.» في الرئيسية (DESIGN 8.4).

**المزوّدات:** `reportConfigProvider` (`ReportConfig.fromEnvironment()`)، `clipboardWriterProvider` (`Clipboard.setData`)، `reportServiceProvider`، `appVersionProvider`؛ كلها تُستبدل في الاختبارات.

## 11. الواجهة

- **عرض السعودية (D24، قرار المالك):** المواسم والطوالع أولاً؛ تحتها الدَّرّ مع السطر الثابت (`dururBorrow.note`) ورابط «أصل التقويم» (صفحة ثابتة `/about/origin`، نصوصها في ARB). في الدائرة تبقى حلقة الدرور، ويوضع اسم المُعيرة في وسيلة الإيضاح.
- **صفحة الدَّرّ (D26):** المسار `/dar/:regionId/:start` (`start` بصيغة `MM-DD`، و`regionId` جدول الدرور الفعلي، أي المُعيرة عند الاستعارة). تُبنى من سجل الدَّرّ نفسه: الاسم، «من {المئة}»، التواريخ، الجو ووصفه، المصدر، وزر البلاغ، ورابط لصفحة المئة (`/item/<seasonId>`). لا عنصر في `items.json` للدرور.
- **صفحة المصادر (D27):** مصادر كل الجداول مجمّعة من حقول `source`/`sources` بلا تكرار، وقسم ثابت «رخص البيانات» فيه إشارة GeoNames (CC BY 4.0) مع الرابطين.
- **مبنيّ (الميزة 7)، `features/item_detail/` و`features/about/` و`features/settings/sources_screen.dart`:**
  - `detail_data.dart` (بلا Flutter): `DetailTarget` = `ItemTarget(itemId)` أو `DarTarget(regionId, MonthDay start)`، و`DetailRequest = (target, from)`، و`detailRequestFor(DialRing, DayInfo)` (الدَّرّ بمعرّف جدول الدرور الفعلي `dururRegionId`)، و`resolveDetail` ← `DetailData` (النوع، الاسم، الفترة، اسم منطقة الجدول، سجل التواريخ، الجو، العنصر أو سجل الدَّرّ، وشريحة الموسم: الموسم الكبير في بداية الفترة للنجم وموسم الجو، ومئة الدَّرّ D25 للدَّرّ) أو null (عنصر/سجل غير موجود، أو `regionId` منطقة مستعيرة).
  - `engine/period_finder.dart` (Dart صافٍ): `findItemPeriod`/`findDarPeriod` = الفترة التي تحتوي التاريخ المرجعي، وإلا التالية خلال 370 يوماً (القفز بنهاية كل فترة). `ItemPeriod.record` (جديد) = سجل الجدول (`Sourced`) لمصدر التواريخ واعتمادها.
  - التاريخ المرجعي: من الدائرة اليوم المضغوط؛ في المسار `?from=YYYY-MM-DD` (البطاقة تمرّر التاريخ المعروض)، وبدونه التاريخ المعروض في الرئيسية (حمولة التنبيه).
  - `item_detail_view.dart`: شريط السدو (CustomPainter، مخفي عن القارئ) ← النوع ← الاسم (`header`) مع شريحة الموسم ← بطاقة التواريخ («من … إلى … في جدول {المنطقة}»، المدة، الحالة نسبةً إلى اليوم الحقيقي، ولسهيل/الثريا «يطلع في {المدينة} يوم …»/«طلع … قبل …» من `currentHeliacalProvider(سنة بداية الفترة)` مع «محسوب فلكياً لموقع مدينتك.» أو «تاريخ تقريبي من جدول المنطقة.» إن تعذّر، ثم «انتقل إلى بدايته») ← التعريف ← المثل (Amiri، علامة اقتباس مخفية عن القارئ) ← الجو المعتاد ← المصدر لكل معلومة: «مصدر التعريف والمثل» (`items.json`) و«مصدر التواريخ» (سجل الجدول)، وللدَّرّ «المصدر» من سجله؛ تحت كل مصدر سجله مسودة «بانتظار الاعتماد» (Amiri مائل). صفحة الدَّرّ بلا تعريف ولا مثل (D26).
  - `item_detail_sheet.dart`: `DraggableScrollableSheet` (نصف الشاشة ← كاملة)، ومكدّس داخلي: شريحة الموسم تفتح صفحته داخل الورقة مع زر رجوع (ورجوع النظام يعود داخلها أولاً). «انتقل إلى بدايته» يغلق الورقة و`select(start)`.
  - `item_detail_page.dart`: الصفحة الكاملة للمسارين؛ الشريحة `push` لمسار جديد، و«انتقل إلى بدايته» `select` ثم `go('/')`. مسار لا يجد سجله (أو `MM-DD` غير صالح) ← `go('/')` بلا رسالة.
  - `about/origin_screen.dart`: قسمان (الطوالع والمواسم، الدرور) نصوصهما في ARB من research/SAUDI.md §3 (بانتظار المراجع). عبارة «معروض هنا للمقارنة.» مفتاح مستقل `originDururComparison` تُلحق فقط إن كانت منطقة المستخدم الحالية تستعير الدرور (DESIGN 8.10، مع الميزة 8).
  - `item_detail_page.dart`: فشل تحميل الجداول ← `DataLoadError` (`features/common/load_error.dart`، المشتركة مع الرئيسية) برسالة و«إعادة المحاولة» (`invalidate(tablesProvider)`) (إصلاح مع الميزة 8).
  - صفحة المصادر: `domain/source_catalog.dart` (`collectSources`: مفتاح التكرار العنوان والمؤلف والسنة، فيظهر GeoNames مرة واحدة؛ «بانتظار الاعتماد» إن كان أي سجل يستشهد بالمصدر مسودة، وإلا «اعتمده: {المراجعون}»)، ثم «رخص البيانات» (نص GeoNames ورابطاه ثوابت في الكود عبر `urlOpenerProvider`، ورسالة إن تعذّر الفتح)، ثم «التقويم الهجري». صف «المصادر» في قسم «البيانات والمساعدة» بالإعدادات. أندرويد: `<queries>` لنيّة VIEW بمخطط https.
  - `features/common/chips.dart`: `SeasonChip` و`WeatherChip` (نُقلتا من `day_card.dart` لتستخدمهما الصفحة).
  - زر «أبلغ عن خطأ» أسفل الصفحة **بُني مع الميزة 9** (SPEC 7 معيار 4، §10).
- الدائرة: `CustomPainter` بحلقات (الأشهر، الدرور، المواسم، النجوم، مواسم الجو)، والزاوية من رقم اليوم في السنة. اللمس: تحويل الإحداثيات القطبية إلى (حلقة، يوم) ← عنصر. التدوير بالسحب يغيّر `selectedDateProvider`.
- **مبنيّ (الميزة 6)، `features/home/`:**
  - `dial/dial_model.dart` (بلا Flutter): `DialModel.fromYearIndex` يجمع أيام السنة في قطع لكل حلقة (الفترة العابرة لنهاية السنة قطعتان)؛ الدرور بلون مئتها `seasonId` (D25)، ومواسم الجو بلون الموسم الكبير في منتصفها. `DialGeometry`: أنصاف الأقطار المرجعية (170/146/130/102/78/60، المحور 58)، `angleOf`، و`hitTest(dx, dy, rotation)` ← `HubHit` أو `RingHit(ring, day)`.
  - `dial/dial_painter.dart`: `DialPainter(repaint: rotation)` يرسم القرص والإبرة وشريحة اليوم وتمييز القطع تحت الإبرة وعلامة اليوم الحقيقي. النصوص `TextPainter` مُعدّة مسبقاً في `DialLabels` (مرة لكل سنة/سمة/حجم خط/كثافة، وتكبيرها محصور 1.3×). الكثافة حسب العرض: ≥400 كل الأسماء، 360–399 أول كلمة من اسم النجم، <360 لا أسماء نجوم والأشهر بأرقامها.
  - `dial/day_dial.dart`: الدوران `ValueNotifier<double>` (فهرس يوم كسري)؛ السحب يغيّره فيعيد رسم القرص داخل `RepaintBoundary` فقط، ويُستدعى `select` عند عبور يوم كامل (والواجهة تُبنى مرة لكل يوم). التدوير من أحداث اللمس الخام (`Listener`)، وإيماءة `ScaleGestureRecognizer` تكسب الساحة فور الضغط فلا تتمرّر الصفحة من فوق الدائرة؛ الضغطة/الضغطتان تُميَّزان يدوياً بمهلة `kDoubleTapTimeout`. التكبير 1×–3× (ضغطتان أو إصبعان)، والسحب في التكبير يحرّك. القفز للعودة بحركة 400ms إلا مع «تقليل الحركة». `Semantics` واحد: `label` البادئة فقط («اليوم»/«التاريخ المعروض»)، و`value` من `dialSemanticsValue` (التاريخ المسموع بلا «م»/«هـ»، ثم الجمل بترتيب DESIGN 7.7، والدَّرّ بطوله الفعلي)، و`increasedValue`/`decreasedValue` قيمة اليوم التالي/السابق تحسبها الرئيسية من `dayInfoProvider` (عبر نهاية السنة؛ null مع إزالة الإجراء عند حدّي 2025/2040)، `onTap` ما يعرضه المحور، وإجراءات مخصصة. المحور للمنطقة المستعيرة (7.8): موسم الجو أو الموسم الكبير و«طالع {النجم}»، ويفتح الموسم.
  - `home_screen.dart` (سطر التاريخين بارتفاع ثابت للصيغتين، الدائرة، صف التنقل، `DayCard`، العبارة الثابتة، المصدر)، والتحميل (هيكل رمادي بعد 300ms) والخطأ (إعادة المحاولة بـ `ref.invalidate(tablesProvider)`). أفقي/تابلت ≥600: الدائرة بجانب البطاقة.
  - من الدائرة ← `showItemDetailSheet` (ورقة)، ومن البطاقة ← `context.push` لمسار الصفحة الكاملة (الميزة 7). سطر الإيضاح (48dp) ورابط «أصل التقويم» في البطاقة يفتحان `/about/origin`.
  - الثيم `lib/src/theme/app_theme.dart`: `DururColors` (ThemeExtension بألوان DESIGN §2 للوضعين وألوان المواسم بمعرّفات عناصرها) و`buildDururTheme`؛ الوضع حسب الجهاز افتراضياً، واختياره (تلقائي/فاتح/داكن) من الإعدادات منذ الميزة 8 (`themeMode` في `app.dart`).
- كل معلومة مهمة تُعرض أيضاً كنص عادي تحت الدائرة (يتكبّر مع خط الجهاز)، وللدائرة `Semantics` لقارئ الشاشة.
- خط عربي مضمّن (لا تحميل وقت التشغيل). الألوان والرموز من DESIGN.md، ومن صنعنا بالكامل.

## 12. الأمان والخصوصية

- لا مفاتيح ولا أسرار في التطبيق أصلاً (لا خادم). أي ملف `.env` مستثنى من git.
- البيانات المحفوظة على الجهاز فقط: معرّف المدينة، مفتاحا التنبيهات (`notifyImportant`، `notifyDar`)، انتهاء الإعداد الأولي (`onboardingDone`)، السمة والأرقام (`theme`، `digits`)، وحالة التحديث (`data.highestSeq`، `data.lastCheckOk`، `data.lastAttempt`) وحزمة البيانات المنزّلة (§16.4). (مفتاح «تحديث البيانات تلقائياً» في D21 لم يُبنَ بعد، §16.11.)
- لا تحليلات ولا تقارير أعطال ولا إعلانات (D15).
- الشبكة: طلب GET واحد أسبوعياً لملف ثابت عام، بلا معرّفات ولا معاملات ولا كوكيز ولا `If-None-Match` (§16.2)، و`User-Agent` ثابت `durur`. المفتاح العام للتوقيع مضمّن في الكود (ليس سراً)؛ المفتاح الخاص لا يدخل المستودع ولا التطبيق أبداً (§16.3).
- أندرويد الإصدار: إذن `INTERNET` فقط لتحديث البيانات (D21). لا `ACCESS_NETWORK_STATE` ولا أي إذن شبكة آخر.
- قواعد أمان Firebase: لا تنطبق (لا Firebase في النسخة الأولى).

## 13. إعدادات المنصات (تُنفّذ مع ميزاتها؛ لم تُختبر هنا لعدم وجود Android SDK وXcode)

أندرويد (`AndroidManifest.xml`، `build.gradle.kts`):
- `ACCESS_COARSE_LOCATION`، `POST_NOTIFICATIONS`، `RECEIVE_BOOT_COMPLETED` + مستقبلا flutter_local_notifications `ScheduledNotificationReceiver` و`ScheduledNotificationBootReceiver` (لإعادة الجدولة بعد إعادة التشغيل) — **مُضافة مع الميزة 8**، ومعها `res/drawable/ic_stat_durur.xml` و`res/raw/keep.xml` (حماية الأيقونة من R8). لا `SCHEDULE_EXACT_ALARM` (D13).
- `<queries>` لنيّة VIEW بمخطط `https` (url_launcher على أندرويد 11+؛ روابط المصادر ونموذج البلاغ). لا `mailto` (البلاغ بلا بريد، §10). آيفون: لا `LSApplicationQueriesSchemes` (لا نستخدم `canLaunchUrl`، و`https` لا يحتاجه).
- `coreLibraryDesugaring` (مطلوب لـ flutter_local_notifications) — مُضاف مع الميزة 8 (`desugar_jdk_libs:2.1.4`).
- `INTERNET` في `src/main/AndroidManifest.xml` و`android:usesCleartextTraffic="false"` (HTTPS فقط) — **مُضافان مع الميزة 11** (D21)، ويثبتهما `test/platform/location_permissions_test.dart`. لا `networkSecurityConfig` ولا `ACCESS_NETWORK_STATE`.

آيفون (`Info.plist`، `AppDelegate.swift`):
- `NSLocationWhenInUseUsageDescription` (بالعربية)، `NSLocationDefaultAccuracyReduced = true`.
- `CFBundleDevelopmentRegion = ar`، `CFBundleLocalizations = [ar]`.
- مندوب `UNUserNotificationCenter` حسب توثيق flutter_local_notifications — مُضاف مع الميزة 8 في `AppDelegate.swift`.

## 14. المكتبات (الإصدارات المثبّتة فعلاً في pubspec.lock)

| المكتبة | الإصدار | الغرض |
|---|---|---|
| Flutter / Dart | 3.47.6 / 3.13.5 (stable) | الإطار |
| flutter_localizations + intl | SDK / 0.20.3 | العربية، الأرقام والتواريخ |
| flutter_riverpod | 3.4.3 | إدارة الحالة |
| go_router | 18.0.2 | التنقل وفتح الصفحات من التنبيه |
| hijri (تطوير فقط) | 3.0.1 | في `dev_dependencies`: توليد `hijri_umm_al_qura.json` واختبار التطابق (D22)؛ لا تدخل التطبيق |
| geolocator | 14.1.1 | قراءة الموقع التقريبي مرة واحدة |
| خطوط مضمّنة (ليست مكتبات) | — | Reem Kufi (متغيّر، محور wght) وIBM Plex Sans Arabic (400/500/600) وAmiri (400 عادي ومائل، للمثل الشعبي و«بانتظار الاعتماد») في `assets/fonts/` مع رخص OFL مسجّلة في `LicenseRegistry` (`main.dart`) |
| flutter_local_notifications | 22.3.1 | التنبيهات المجدولة على الجهاز |
| timezone | 0.11.1 | الجدولة بالتوقيت المحلي |
| flutter_timezone | 5.1.0 | اسم المنطقة الزمنية للجهاز |
| shared_preferences | 2.5.5 | حفظ الإعدادات |
| url_launcher | 6.3.2 | فتح روابط https فقط (المصادر ونموذج البلاغ) |
| package_info_plus | 10.2.2 | نسخة التطبيق في البلاغ |
| cryptography | 2.9.0 | التحقق من توقيع Ed25519 وSHA-256 بـ Dart صافٍ (`DartEd25519`، `DartSha256`) (D21)؛ والتوقيع في الأداة |
| path_provider | 2.1.6 | مجلد دعم التطبيق لحفظ الحزمة المنزّلة |
| meta | 1.18.3 | `@visibleForTesting` في طبقة التحديث (Dart صافٍ بلا Flutter)؛ كانت انتقالية من SDK (D31) |
| flutter_lints (تطوير) | 6.0.0 | قواعد التحليل |

الشبكة عبر `dart:io HttpClient` بلا مكتبة إضافية. غير مستخدم عمداً: Firebase وRemote Config، workmanager (مهام خلفية)، connectivity_plus، google_fonts (يحمّل من الإنترنت)، أي مكتبة تحليلات، permission_handler (البلجنات تطلب أذوناتها)، مكتبات توليد الكود.

## 15. الاختبارات

| المستوى | ماذا | أين |
|---|---|---|
**الموجود فعلاً (543 اختباراً بعد الميزة 9 حسب STATUS.md):**

| المستوى | ماذا | الملف |
|---|---|---|
| وحدة | المحرك على جداول صغيرة معروفة (حدود الدَّرّ، 29 فبراير، الالتفاف) | `test/engine/calendar_engine_test.dart` (+ `engine_expectations.dart` مساعد) |
| وحدة | المدقق (كل قاعدة بحالة نجاح وفشل) | `test/engine/table_validator_test.dart` |
| بيانات | المحرك والمدقق على `assets/tables` الفعلية (366 يوماً × كل المناطق × 2025–2040، بلا افتراض قيم بعينها) | `test/engine/asset_tables_test.dart` |
| بيانات | `cities.json` الفعلي (الدول الست، الربط بالمناطق وملاحظاته، الإحداثيات ±0.2°، البحث) | `test/engine/asset_cities_test.dart` |
| وحدة | المدينة: التحليل، والبحث مع تطبيع العربية | `test/domain/city_test.dart`، `test/domain/city_search_test.dart` |
| وحدة | الهجري: تواريخ مرجعية، بدايات أشهر، تسلسل كل يوم | `test/hijri/hijri_date_test.dart` |
| وحدة | جدول أم القرى: التحويل، والتطابق مع مكتبة hijri يوماً بيوم، والمولّد | `test/hijri/umm_al_qura_calendar_test.dart` |
| وحدة | مدقق الهجري وقاعدة «لا تغيّر أكثر من يوم» | `test/hijri/hijri_table_validator_test.dart` |
| تكامل | ربط الهجري بالجداول والمدقق والمزوّدات والواجهة | `test/hijri/hijri_tables_test.dart` |
| وحدة | نصوص التاريخين والأرقام العربية | `test/formatting/date_labels_test.dart` |
| مزوّدات | سلسلة الإعدادات ← المدينة ← المنطقة ← المحرك ← اليوم | `test/providers_test.dart` |
| واجهة | التطبيق يفتح بالعربية ومن اليمين لليسار، والتاريخان الهجري والميلادي | `test/widget_test.dart` |
| واجهة | قائمة المدن: البحث، الشرائح، الاختيار والحفظ، فشل الحفظ | `test/widgets/city_picker_test.dart` |
| مساعدات | جداول تجريبية؛ تحميل الأصول وتطبيق بمزوّدات مستبدلة (و`fixedClock`، `scrollHomeTo`)؛ جدول الهجري المضمّن | `test/fixtures/fixture_tables.dart`، `test/helpers/app_harness.dart`، `test/helpers/hijri_asset.dart` |
| وحدة | رموز الجو الـ17 (D23): القائمة، التحليل، الاسم، الأيقونة | `test/domain/weather_symbol_test.dart` |
| وحدة | استعارة الدرور (D24): المحلل، المحرك، المدقق، والبيانات التجريبية | `test/engine/durur_borrow_test.dart` |
| مزوّدات | اليوم ومنتصف الليل، التاريخ المعروض والحصر، المفتاح المقرّب، فهرس السنة، شريط المسودة | `test/features/today_providers_test.dart` |
| وحدة | نموذج الدائرة (حلقات بلا فجوات لكل منطقة) والهندسة واللمس وزمن البناء | `test/features/dial_model_test.dart` |
| واجهة | الرئيسية: المعايير 1–8، قارئ الشاشة، 320dp وخط 200%، السحب والضغط والتكبير، D24، التحميل والخطأ، منتصف الليل | `test/widgets/home_screen_test.dart` |
| وحدة | فترة العنصر/الدَّرّ حول تاريخ (تحتويه أو التالية، الالتفاف، 29 فبراير، غير موجود) | `test/engine/period_finder_test.dart` |
| وحدة | محتوى الصفحة، `detailRequestFor`، حذف `ItemKind.dar`، والمعيار 3 على البيانات المضمّنة (كل عنصر في الدائرة له تعريف ≤ سطرين ومثل ومصدر وصفحة، وكل دَرّ له صفحة) | `test/features/detail_data_test.dart` |
| وحدة | مصادر الجداول بلا تكرار وحالة اعتمادها (D27) | `test/domain/source_catalog_test.dart` |
| واجهة | الميزة 7: الورقة والصفحة الكاملة بمساراتها، سهيل/الثريا من الحساب الفلكي، الحالات، الدَّرّ (D26)، المسار المفقود ← الرئيسية، «أصل التقويم»، المصادر وروابطها، خط 200% على 320dp، أهداف 48dp | `test/widgets/item_detail_test.dart` |
| وحدة | المخطِّط: المواسم الستة وتواريخها (الجدول/الفلك/البديل)، 08:00، يوم البداية قبل/بعد 8، الأفق، المفتاحان، الدرور والمستعيرة، حد 60 بجدول كثيف، الترتيب والمعرّفات، التكرار، كل المناطق 2025–2040 | `test/notifications/notification_planner_test.dart` |
| مزوّدات | النص والحمولة (D24)، `isNotificationPayload`، المزامنة (الفتح، المفتاحان، المدينة، الجداول، المنطقة الزمنية، اليوم، الفشل)، الإذن | `test/notifications/notification_sync_test.dart` (+ `test/helpers/fake_notification_scheduler.dart`) |
| بلجن (محاكاة القناة) | المُجدوِل الفعلي على أندرويد: المسح قبل الجدولة، 08:00 Asia/Riyadh، UTC لمنطقة مجهولة، الوضع غير الدقيق، القناة، الأيقونة، المتأخر المعلق | `test/notifications/local_notification_scheduler_test.dart` |
| واجهة | شرح التنبيهات وإذنه ورفضه، مفاتيح الإعدادات وملاحظة الإذن وخطأ الجدولة، السمة والأرقام، الضغط على التنبيه والتشغيل منه، الإصلاحات المؤجلة، عبارة «للمقارنة» في أصل التقويم، 200% و48dp وقارئ الشاشة | `test/widgets/notifications_settings_test.dart` |
| وحدة | الميزة 9: ترتيب البلاغ (نموذج ← نسخ)، القيم الفارغة، النموذج المعبأ وغير المعبأ، الفشل، رفض المخططات غير https، `REPORT_FORM_FIELDS` | `test/report/report_service_test.dart` |
| واجهة | الميزة 9: محتوى البلاغ بلا بيانات شخصية، الزر في صفحة النجم والدَّرّ والإعدادات وخطأ الحساب، «نسخ» فقط بلا إعدادات، النسخ للحافظة، 200% على 320dp وقارئ الشاشة | `test/widgets/report_test.dart` |

| وحدة | الميزة 11: القبول والرفض (توقيع، keyId، تطبيق، مخطط، minAppBuild، seq، حجم، بصمة، JSON، ملف ناقص، مسودة، بدايات مكررة، شهر هجري 31، إزاحة يومين، تصحيح يوم واحد مقبول، حذف مدينة) | `test/updates/bundle_verifier_test.dart` (+ `update_test_kit.dart`: مفتاح مؤقت وحزم من الجداول الفعلية بعد اعتمادها في الذاكرة) |
| وحدة | الميزة 11: الموعد (7 أيام/24 ساعة/الإعداد الأولي/رجوع الساعة) | `test/updates/update_schedule_test.dart` |
| شبكة (خادم HTTP محلي) | الميزة 11: الترويسات (لا كوكيز ولا معاملات، `User-Agent` ثابت)، 404، 304، مهلة، حجم زائد بطريقتين، تحويل لنفس النطاق/لنطاق آخر، بلا خادم | `test/updates/update_fetcher_test.dart` |
| مزوّدات | الميزة 11: القبول ← إعادة الجداول والهجري والتنبيهات، الفتح التالي من المثبّت، خادم محلي من البداية للنهاية، الرفض والبقاء، التوقيت، معطّل، الرجوع للمضمّن (تالف، مؤشر تالف، مضمّن أحدث، مفتاح أُزيل، بلا مجلد)، المخزن | `test/updates/data_updater_test.dart` |
| واجهة | الميزة 11: التحقق بعد أول إطار وعند العودة حسب الموعد، ولا طلب في البناء الافتراضي | `test/updates/app_update_trigger_test.dart` |

**مخطط مع ميزاته:** الفلك (Meeus + مرجعي ±2 + ترتيب المدن) `test/astronomy/`؛ أقرب مدينة `test/location/`. يدوي: وضع الطيران، تغيير تاريخ الجهاز للتنبيه، رفض الأذونات (TESTERS.md).

الأوامر في CLAUDE.md.

## 16. تحديث البيانات الموقّع بلا تحديث التطبيق (الميزة 11) (D21، D22)

الهدف: تصحيح الجداول (الدرور، المواسم، النجوم، المدن، النصوص) وتقويم أم القرى دون انتظار المتجر، مع بقاء التطبيق يعمل كاملاً بلا إنترنت، وبلا خادم خاص ولا حساب ولا تتبع.

### 16.1 المصدر: GitHub Pages من مستودع بيانات عام مستقل
- مستودع عام مستقل (مقترح: `durur-data`) فيه `assets/tables` المعتمدة فقط، وGitHub Pages ينشر مجلد `v<schemaVersion>/`:
  ```
  https://<الحساب>.github.io/durur-data/v1/manifest.json   # صغير (<1 كيلوبايت)، موقّع
  https://<الحساب>.github.io/durur-data/v1/bundle-<dataSeq>.json  # كل الجداول في ملف واحد (~100–300 كيلوبايت)
  ```
- **لماذا Pages لا Releases:** رابط ثابت بلا تحويلات لنطاقات أخرى، شبكة توزيع (CDN) مجانية، يدعم `ETag/If-None-Match` فيكون التحقق الأسبوعي غالباً رد 304 بلا محتوى، ويمكن ربط نطاق خاص لاحقاً دون تغيير التطبيق إن كان الرابط الأساسي نطاقاً خاصاً. Releases تبقى أرشيفاً لكل حزمة منشورة (للتدقيق والتراجع).
- الرابط الأساسي `UPDATE_BASE_URL` من `--dart-define-from-file` (ليس سراً، لا يُكتب في الكود؛ مثل `https://<الحساب>.github.io/durur-data`، والتطبيق يضيف `v1/`). إن كان فارغاً أو ليس https بنطاق (أو فيه معاملات/جزء/بيانات دخول) تُعطَّل الميزة كلياً ولا يُرسل أي طلب. وتُعطَّل أيضاً إن لم يكن في التطبيق مفتاح عام موثوق.
- **الأمان لا يعتمد على الاستضافة:** حتى لو اختُرق المستودع أو الاستضافة أو الشبكة، لا يقبل التطبيق إلا ملفاً موقّعاً بمفتاحنا (16.3).

### 16.2 متى يتحقق، وماذا يرسل
- **عند الفتح أو العودة للواجهة** فقط (لا مهام خلفية): إن مرّ ≥ 7 أيام على آخر تحقق ناجح، أو ≥ 24 ساعة على آخر محاولة فاشلة. يبدأ بعد رسم أول إطار، غير متزامن، ولا يؤخر الدائرة ولا يظهر للمستخدم أي خطأ شبكة.
- لا يتحقق أثناء الإعداد الأولي، ولا إن أطفأ المستخدم «تحديث البيانات تلقائياً» في الإعدادات (مفعّل افتراضياً، D21): مطفأ = لا طلب تلقائي أبداً. في الإعدادات زر «تحقق الآن» (طلب صريح من المستخدم يتجاهل المهلة والمفتاح، DESIGN 8.7) وسطر «نسخة البيانات: {version} — آخر تحقق: …» (**مبنيّ، الميزة 11ب**).
- ساعة الجهاز رجعت للخلف (وقت مسجّل في المستقبل) ← يُعامل كأنه الآن ويُعاد كتابته الآن، فلا تحقق في كل عودة ولا توقف حتى تلحق الساعة.
- لا فحص لحالة الشبكة (لا `connectivity_plus`): المحاولة نفسها هي الفحص؛ الفشل يسجَّل وقته فقط.
- **الطلب:** `GET <base>/v1/manifest.json` عبر `dart:io HttpClient`، HTTPS فقط، بلا معاملات استعلام، بلا كوكيز، بلا معرّف جهاز أو مدينة أو لغة أو نسخة تطبيق؛ `User-Agent` ثابت `durur` لكل المستخدمين؛ **بلا `If-None-Match`** (§16.11). مهلة 15 ث، حد حجم 4 كيلوبايت للبيان و2 ميغابايت للحزمة (يُقطع الاتصال عند التجاوز)، لا تحويلات إلا إلى HTTPS على نفس النطاق.
- ما يراه المستضيف (GitHub) حتماً: عنوان IP ووقت الطلب، كأي فتح لصفحة ويب. لا نملك هذه السجلات ولا نطلبها. يُذكر في سياسة الخصوصية.
- الحزمة تُنزَّل فقط إن كان `dataSeq` في البيان الموقّع أكبر من المثبّت.

### 16.3 التوقيع (Ed25519)
- **البيان الموقّع** (`manifest.json`) غلاف يوقَّع فيه نص بايتات خام، فلا مشكلة توحيد JSON:
  ```json
  { "keyId": "k1", "payload": "<base64 لبايتات JSON>", "signature": "<base64 Ed25519 على بايتات payload>" }
  ```
  و`payload` بعد فك base64:
  ```json
  { "app": "com.durur.durur", "schemaVersion": 1, "dataSeq": 7, "dataVersion": "2027-03-a",
    "publishedAt": "2027-03-01", "minAppBuild": 1,
    "bundle": { "path": "bundle-7.json", "sha256": "<hex>", "size": 183422 } }
  ```
- **ترتيب التحقق في التطبيق (أي فشل ← رفض وبقاء البيانات الحالية):**
  1. `keyId` معروف، والتوقيع صحيح بالمفتاح العام المضمّن (`lib/src/updates/trusted_keys.dart`، مفتاحان كحد أقصى: الحالي والتالي للتدوير).
  2. `app` يطابق، `schemaVersion` == ما يدعمه التطبيق، `minAppBuild` ≤ رقم بناء التطبيق.
  3. `dataSeq` > max(رقم الحزمة المضمّنة في `meta.json`، أعلى رقم قُبل سابقاً). **رفض أي نسخة أقدم أو مساوية** (يمنع إعادة تشغيل حزمة قديمة صحيحة التوقيع).
  4. بعد التنزيل: الحجم وSHA-256 يطابقان البيان.
  5. تحليل الحزمة بنفس `Tables.fromJson`، ثم **`TableValidator` بوضع release** (كل سجل `approved`) + مدقق الهجري (16.6) + قواعد التوافق (16.7).
- `dataSeq` عدد صحيح يزيد مع كل نشر، ويُضاف إلى `meta.json` المضمّن؛ كل إصدار متجر يضمّن آخر حزمة منشورة برقمها.
- **المفتاح الخاص:** يُولَّد مرة واحدة خارج المستودع وخارج بيئة الوكلاء. لا يُكتب في أي ملف داخل المستودع، ولا في `config/`، ولا في التطبيق. `tool/sign_bundle.dart` يقرؤه من مسار في متغير البيئة `DURUR_SIGNING_KEY_FILE` أو من `DURUR_SIGNING_KEY` (base64، لسر GitHub Actions) ولا يطبعه أبداً، و`keygen` يرفض الكتابة داخل المستودع؛ و`.gitignore` يستثني `*.key` و`*.pem` و`*.ed25519` احتياطاً. نسخة احتياطية غير متصلة لدى المالك؛ فقدانه يعني أن التصحيحات تحتاج تحديث متجر يضمّن مفتاحاً جديداً، وتسريبه يعالج بإزالة `keyId` من التطبيق في التحديث التالي.
- المفتاح العام ليس سراً، ووجوده في الكود لا يخالف قاعدة «لا مفاتيح في الكود» (القاعدة عن الأسرار).
- الاختبارات تولّد زوج مفاتيح مؤقتاً أثناء التشغيل؛ لا مفاتيح اختبار محفوظة في المستودع.

### 16.4 التخزين والتحميل عند الفتح
- مجلد `getApplicationSupportDirectory()/tables/` (خاص بالتطبيق، لا يحتاج إذن تخزين):
  - التنزيل إلى `incoming.tmp` ← التحقق الكامل ← إعادة تسمية ذرّية إلى `bundle.json` + `manifest.json` بجانبه.
  - `shared_preferences`: `data.highestSeq`، `data.lastCheckOk`، `data.lastAttempt`، `data.autoUpdate` (المبنيّ؛ لا `data.etag`، §16.11).
- `TableRepository.load()` يصبح: إن وُجدت حزمة منزّلة ← تحقق التوقيع والـ SHA-256 من الملفين المحفوظين ← تحليل ← المدقق بوضع release ← استخدامها؛ **أي فشل أو `dataSeq` ≤ المضمّن (بعد تحديث متجر) ← البيانات المضمّنة وحذف الحزمة المنزّلة.** التحقق عند كل فتح رخيص (ملف واحد، أجزاء من الثانية) ويحمي من تلف الملف على الجهاز.
- `TablesLoader` الحالي يُعاد استخدامه كما هو: مصدر القراءة إما `AssetBundle` أو قارئ من الحزمة الموحّدة (خريطة مسار ← نص)، فلا يتغير المحلل ولا المدقق.
- حزمة واحدة منزّلة فقط (لا سجل نسخ)؛ الرجوع دائماً إلى المضمّن.

### 16.5 تطبيق التحديث وإعادة جدولة التنبيهات
- بعد قبول حزمة: `ref.invalidate(tablesProvider)` ← تُعاد كل المزوّدات المشتقة (المحرك، `YearIndex`، `heliacalProvider` لأن إحداثيات المدن قد تتغير، الهجري).
- `notificationSyncProvider` يراقب `tablesProvider` أيضاً، فيُنفّذ `cancelAll()` ثم الجدولة من الخطة الجديدة (نفس المسار الحتمي في §9)، فلا تكرار ولا تنبيه لتاريخ قديم.
- إن لم تعد المدينة المحفوظة موجودة لن يحدث ذلك أصلاً (16.7 يرفض الحزمة).
- **عُدّل (DESIGN 8.7، الميزة 11ب):** رسالة مؤقتة أسفل الشاشة (SnackBar) «حُدّثت البيانات» **مرة واحدة** عند قبول أي حزمة (من «تحقق الآن» أو التحقق التلقائي)، على أي شاشة؛ لا نافذة تقطع العمل. تنتظر إغلاق أي ورقة سفلية أو حوار مفتوح (`PopupRouteTracker` على موجّه التطبيق)، ولا تظهر إن كان التطبيق في الخلفية لحظة القبول ولا أثناء الإعداد الأولي. 6 ثوانٍ (10 مع قارئ الشاشة)، بلا زر. يعرضها جذر التطبيق (`scaffoldMessengerKey`) عند زيادة `DataUpdateStatus.acceptedCount`، فلا تتكرر من الإعدادات. وسطر الحالة في الإعدادات يتحدث بالنسخة الجديدة و«اليوم». شريط «بيانات تجريبية» لا يظهر لحزمة منزّلة لأنها مقبولة بوضع release فقط.

### 16.6 تقويم أم القرى كبيانات (D22)
- ملف `assets/tables/hijri_umm_al_qura.json` (ويدخل في الحزمة):
  ```json
  { "calendar": "umm_al_qura", "firstYear": 1446, "firstMonth": 1,
    "monthStarts": ["2024-07-07", "2024-08-05", "..."],
    "source": {...}, "approval": {...},
    "verifiedThrough": "2029-08-10" }
  ```
  `monthStarts[i]` = اليوم الميلادي لبداية الشهر i، والعنصر الأخير حارس لنهاية آخر شهر. المدى: 1446/1 حتى 1466/12 (يغطي 2025-01-01 حتى أواخر 2044، أوسع من شرط 2025–2040). (1 محرم 1446 = 2024-07-07، و1 صفر 1446 = 2024-08-05، كما في الملف المولّد.)
- **مبنيّ (الميزة 2ب):** `UmmAlQuraCalendar.convert` بحث ثنائي في `monthStarts` (Dart صافٍ، بلا مكتبة)، والواجهة صارت **`HijriDate.fromGregorian(date, calendar)`**: الجدول يُمرَّر صراحةً (من `hijriCalendarProvider` في التطبيق، ومن `loadAssetHijriCalendar()` في الاختبارات) بدل جدول ضمني.
- **مكتبة hijri في `dev_dependencies` فقط** (لا تدخل التطبيق): يستخدمها `tool/gen_hijri_table.dart` لتوليد الملف الأول، واختبار `test/hijri/umm_al_qura_calendar_test.dart` يثبت التطابق يوماً بيوم مع المكتبة في المدى كله. بعد التوليد الأول **الحقيقة هي الملف لا المكتبة**؛ إعادة التوليد (`--force`) تمحو أي تصحيح أو اعتماد في الملف، فلا تُستخدم إلا عمداً.
- مدقق الهجري: بدايات متزايدة، كل شهر 29 أو 30 يوماً، كل سنة 354 أو 355، تغطية 2025-01-01 حتى 2040-12-31 كاملة. **وفي التحديث:** أي بداية شهر تختلف عن الجدول المضمّن بأكثر من يوم واحد ← رفض (حاجز ضد خطأ موقّع).
- `verifiedThrough` يُرفع بعد التحقق من التقويم الرسمي ونشر الحزمة؛ لا أثر له على العرض (معلومة للمراجعة والاختبار).

### 16.7 قواعد توافق الحزمة (فوق TableValidator)
- لا تحذف معرّفاً موجوداً في الجدول المضمّن: المناطق والمدن (المدينة المحفوظة) والعناصر (حمولات التنبيه `/item/<id>`). الإضافة مسموحة؛ الإخفاء يكون بحقل لا بالحذف. (حمولات الدرور `/dar/<regionId>/<MM-DD>` قد تتغير بتصحيح تاريخ؛ التنبيهات تُعاد جدولتها بعد القبول، والمسار المفقود يفتح الرئيسية، D26.)
- رموز الجو ضمن المجموعة المغلقة التي يعرفها هذا الإصدار.
- نفس `schemaVersion`. تغيير المخطط ← مجلد `v2/` جديد؛ الإصدارات القديمة تبقى تقرأ `v1/` (ويستمر نشر تصحيحات `v1` ما دام لها مستخدمون).

### 16.8 مسار النشر (من البلاغ إلى الجهاز)
1. بلاغ «أبلغ عن خطأ» (D14) ← المراجع يقرر ← تعديل JSON في مستودع البيانات بطلب دمج.
2. فحص آلي: `validate_tables --release` + مدقق الهجري + قواعد 16.7 مقارنة بآخر حزمة منشورة.
3. `tool/build_bundle.dart` يولّد `bundle-<seq>.json` و`payload`.
4. التوقيع بالمفتاح الخاص (طريقته قرار للمالك، D21) ثم رفع `manifest.json` والحزمة إلى Pages.
5. **النشر للمستخدمين إجراء نهائي: لا يتم إلا بموافقة المالك الصريحة لكل حزمة** (قاعدة الشركة).
6. الإصدار التالي في المتجر يضمّن آخر حزمة منشورة.

### 16.9 الاختبارات
| ماذا | كيف |
|---|---|
| التوقيع | زوج مفاتيح مؤقت: صحيح يُقبل؛ بايت معدّل، توقيع ناقص، `keyId` مجهول، `app` آخر ← رفض |
| النسخة | `dataSeq` أقل/مساوٍ للمضمّن أو للمقبول سابقاً ← رفض |
| السلامة | SHA-256 أو حجم مخالف، JSON تالف، سجل `draft`، مدينة محذوفة، شهر هجري 31 يوماً أو مزاح يومين ← رفض والرجوع للمضمّن |
| التحميل | حزمة تالفة على القرص ← المضمّن وحذفها؛ مضمّن أحدث بعد تحديث متجر ← المضمّن |
| الجدولة | قرار «هل أتحقق الآن» (7 أيام / 24 ساعة / الإعداد الأولي / المفتاح مطفأ / ساعة رجعت للخلف) كدالة Dart صافية بتاريخ ثابت؛ **ومبنيّ (11ب):** المفتاح مطفأ ← لا طلب شبكة عند الفتح ولا العودة بعد شهر (`test/widgets/data_update_settings_test.dart` و`data_updater_test.dart`) |
| الشبكة | خادم HTTP محلي في الاختبار: 304، 404، مهلة، حجم زائد، تحويل لنطاق آخر |
| الهجري | **مبنيّ:** الجدول المولّد = مكتبة hijri يوماً بيوم (`test/hijri/umm_al_qura_calendar_test.dart`)؛ مدقق الهجري وحاجز «يوم واحد» (`test/hijri/hijri_table_validator_test.dart`). الاختبارات القديمة (الـ176 قبل 2ب) **عُدّل فيها سطر التحميل فقط** (تمرير الجدول إلى `HijriDate.fromGregorian`)، والقيم المتوقعة كما هي |
| التنبيهات | تغيير الجداول ← خطة جديدة كاملة (المخطِّط حتمي) |
| يدوي | وضع الطيران أسبوعاً ثم الاتصال؛ حزمة حقيقية منشورة على Pages تجريبي (TESTERS.md) |

### 16.10 موقعها في ترتيب البناء
- **الميزة 2ب (بعد قبول الميزة 2 مباشرة):** الهجري كبيانات (16.6). بلا شبكة، صغيرة، وتمنع إعادة العمل لاحقاً.
- **الميزة 11 (بعد الميزة 9 وقبل الإطلاق):** التحديث الموقّع (16.1–16.5، 16.7). تحتاج الإعدادات (الميزة 3) والتنبيهات (الميزة 8). يمكن بناؤها واختبارها كاملاً بمفاتيح مؤقتة وخادم محلي قبل قرار المالك؛ الربط بالاستضافة الحقيقية يحتاج المالك.
- `dataSeq` **أُضيف** إلى `meta.json` مع الميزة 2ب (قيمته الحالية 0، اختياري وافتراضيه 0، والسالب خطأ تحليل)؛ `schemaVersion` بقي 1 لأنه لم يُنشر بعد.

### 16.11 المبنيّ (الميزة 11) والفروق عن التصميم أعلاه
- **الملفات:** `lib/src/updates/`: `update_config.dart` (`UPDATE_BASE_URL`)، `trusted_keys.dart` (`trustedDataKeys`، **فارغ** حتى يولّد المالك المفتاح؛ بلا مفتاح ← لا طلب ويُرفض أي مثبّت)، `signed_manifest.dart` (الغلاف والمحتوى و`sha256Hex` و`signManifest`)، `data_bundle.dart` (`{"format":1,"files":{"meta.json":{…},"regions/najd.json":{…}}}` تمرّ بـ `TablesLoader` نفسه)، `bundle_verifier.dart` (`RejectReason` لكل فحص)، `update_fetcher.dart`، `update_store.dart`، `update_schedule.dart` (`isCheckDue`)، `data_updater.dart` (`DataUpdater.check`، `loadInstalledTables`). كلها Dart صافٍ عدا المخزن (shared_preferences) والجلب (`dart:io`).
- **ترتيب القبول:** الغلاف ← `keyId` موثوق ← التوقيع ← المحتوى (المسار يجب أن يكون `bundle-<dataSeq>.json` بالضبط) ← `app` ← `schemaVersion` ← `minAppBuild` ≤ رقم البناء ← `dataSeq` > max(المضمّن، `data.highestSeq`) ← تنزيل بحد = الحجم المعلن (≤ 2 ميغابايت) ← الحجم ← SHA-256 ← التحليل ← `meta.json` في الحزمة يطابق البيان (الرقم والنسخة والمخطط) ← `TableValidator(release)` ← `HijriTableValidator(embedded: المضمّن)` ← لا حذف لمنطقة/مدينة/عنصر.
- **بيان صحيح بلا جديد** (`dataSeq` ≤ الحالي) = نجاح (`upToDate`) بلا تنزيل، والتالي بعد 7 أيام. أي فشل آخر (شبكة، توقيع، رفض) = فشل، والتالي بعد 24 ساعة. وقت المحاولة يُسجَّل **قبل** الطلب.
- **التخزين:** بدل `incoming.tmp` و`bundle.json` بجانب `manifest.json`: مجلد `tables/s<seq>/` فيه الملفان، ثم مؤشر `tables/current` يُكتب مؤقتاً ويُعاد تسميته (لحظة الالتزام)، ثم حذف القديم. التحقق الكامل قبل الكتابة، ومن جديد عند كل فتح. أي رفض عند الفتح (تلف، مؤشر تالف، مضمّن أحدث أو مساوٍ، مفتاح أُزيل) ← المضمّن وحذف المنزّلة؛ تعذّر الوصول للمجلد ← المضمّن بلا حذف. `data.highestSeq` يبقى بعد الحذف (فالحزمة نفسها لا تُعاد حتى رقم أحدث).
- **التحويلات:** مسموحة فقط لنفس المخطط والنطاق والمنفذ (حتى 3)، بلا معاملات.
- **فروق مقصودة عن §16.2–16.4 (للمراجعة):**
  1. اسم الإعداد `UPDATE_BASE_URL` (بطلب المدير) لا `DATA_UPDATE_BASE_URL`.
  2. **لا `ETag`/`If-None-Match`**: قيمة يحددها الخادم ويعيدها الجهاز، فيمكن لمستضيف مخترق أن يجعلها معرّفاً لكل جهاز؛ والبيان أقل من كيلوبايت فلا فائدة تُذكر. 304 يُعامل فشلاً.
  3. أداة واحدة `tool/sign_bundle.dart` (`keygen` و`sign` الذي يبني الحزمة أيضاً، ويرفض ما لا يجتاز `--release`، ويتحقق ذاتياً بالمفتاح العام المقابل) بدل `build_bundle.dart` + `sign_bundle.dart`. رقم الحزمة ونسختها من `meta.json` (`dataSeq` ≥ 1).
  4. **بُني مع الميزة 11ب** (كان «لم يُبنَ»): انظر 16.12.

### 16.12 المبنيّ (الميزة 11ب): الواجهة والتقوية
- **الإعدادات** (`features/settings/data_update_section.dart`، DESIGN 8.7): قسم «تحديث البيانات» بين «المظهر» و«البيانات والمساعدة»، **مخفي كاملاً** إن لم يكن التحديث متاحاً (`dataUpdateAvailableProvider` = رابط صالح ومفتاح موثوق). المفتاح (`data.autoUpdate`، مفعّل افتراضياً، اهتزاز خفيف بلا رسالة)؛ سطر الحالة من `dataVersion` المستخدمة و`data.lastCheckOk` («اليوم»/«أمس»/التاريخ)؛ زر «تحقق الآن» بحالاته (جاهز، جارٍ التحقق معطّل بمؤشر، لا جديد، حُدّثت = رسالة الجذر بلا سطر، تعذّر الاتصال = `FetchException`، تعذّر التحقق = أي رفض أو فشل تثبيت)؛ سطر النتيجة حالة محلية تُمسح بمغادرة الشاشة، ومنطقة حيّة.
- **`DataUpdateController`** صار حالته `DataUpdateStatus` (النتيجة، نوع الفشل `UpdateFailure`، `acceptedCount`). `maybeCheck()` التلقائي يحترم المفتاح والمهلة؛ `checkNow()` يتجاهلهما، وإن كان تحقق جارياً ينتظر نتيجته بلا طلب ثانٍ.
- **صفحة المصادر** (DESIGN 8.11): بطاقة أولى «آخر تحديث للبيانات: {publishedAt}» إن كانت البيانات المستخدمة هي المنزّلة (`dataOriginProvider`: البيان المحفوظ يطابق رقم الجداول المستخدمة ونسختها؛ وقد اجتاز التحقق الكامل عند تحميلها)، أو «البيانات المرفقة مع نسخة التطبيق {appVersion}» للمضمّنة، ثم «نسخة البيانات: {version} ({seq})». تعذّر القراءة ← سطر النسخة وحده. تظهر في كل النسخ.
- **تقوية (من المراجع):**
  1. `data.highestSeq` يُسجَّل **قبل** التثبيت: توقف التطبيق بين التثبيت والتسجيل لا يسمح لاحقاً بحزمة أقدم من المثبّتة. فشل التثبيت نفسه يترك البيانات الحالية والحد مرفوعاً (الحزمة نفسها لا تُعاد حتى رقم أحدث؛ اتجاه الأمان).
  2. `UpdateConfig.unchecked` موسوم `@visibleForTesting`؛ و`HttpUpdateFetcher` يرفض أي مخطط غير `https` (أو بلا نطاق) قبل أي اتصال، إلا بالمنشئ الصريح `HttpUpdateFetcher.allowingHttpForTesting` (موسوم أيضاً).
  3. `isCheckDue`: وقت مسجّل في المستقبل كأنه الآن، و`UpdateState.clampFuture` يعيد كتابته الآن عند التحقق التلقائي.
  4. `tool/sign_bundle.dart`: التحقق الذاتي يقارن الهجري (حاجز اليوم الواحد) وعدم الحذف مقابل `assets/tables` الحقيقية في المشروع لا الجداول المُوقَّعة نفسها (ويُنبّه إن لم يكن `dataSeq` أكبر من المضمّن)؛ و`_insideRepository` يقارن المسارين بعد `resolveSymbolicLinksSync` (لأقرب أصل موجود)، فرابط رمزي خارج المستودع يشير إلى داخله يُرفض.
