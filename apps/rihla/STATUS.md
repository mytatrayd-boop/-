# STATUS — رحلة

## إصلاحات المدير: galleryDone + سلامة الاسترداد (2026-11-14): مبني ومختبر على المضيف، لا جهاز

- schema v2: عمود `trips.galleryDone` (bool، افتراضي false) + `onUpgrade` (`addColumn`). `TripRepository.markGallerySaved(id, {assetId})`؛ `GallerySaveController` يحفظ العلامة عند النجاح (حتى بلا معرّف من gal) ولا يعيد الحفظ إن كانت true (حتى بعد إعادة تشغيل التطبيق). `videoAssetId` اختياري. فشل كتابة العلامة بعد حفظ ناجح لا يُظهر فشلاً (قد يتكرر الحفظ في جلسة لاحقة: خطر ضئيل معروف).
- اختبار ترحيل حقيقي v1->v2 (test/data/db_test.dart): ملف SQLite بمخطط v1 الفعلي وuser_version=1 وبيانات، يُفتح بـAppDatabase الجديد؛ البيانات باقية وgalleryDone=false وuser_version=2. + اختبارات الريبو والمتحكم (gallery_done_test.dart: بلا معرّف، عدم التكرار، فشل ثم إعادة).
- Kotlin recoverPending: `RecoverPolicy` في Pure.kt. لا حذف لأي مجلد فيه mp4؛ يُحذف المجلد الخالي من الوسائط تماماً فقط. بعد 3 محاولات فاشلة (أو وسائط بلا سجل صالح) يُنقل المجلد إلى `rihla/recovery_failed/` ويُرسل حدث `recoveryFailed` (path, moved) لـDart (Dart يتجاهله حالياً: لا واجهة له؛ أنقله إن فشل النقل يبقى في مكانه). أخطاء المساحة (`LowStorageException`، ENOSPC، low_storage) لا تُحتسب محاولة. `RecordingSession.recover` لم يعد يحذف شيئاً عند غياب المقاطع.
- منخفضة: حُذف durationUs/firstBaseUs/lastPtsUs الميتة من SegmentWriter. SegmentConcat يقرأ كل مقطع قراءة جافة قبل كتابته (readsFully) فلا يدخل الناتج جزء من مقطع تالف؛ ثمنه قراءة إضافية للقرص عند الدمج. غير مجرَّب على ملفات mp4 حقيقية (لا جهاز).
- تحقق على نسخة نظيفة من `git ls-files -co --exclude-standard`: analyze بلا ملاحظات؛ flutter test 113 (+ 15 في الحزمة)؛ gradlew :rihla_recorder:testDebugUnitTest 20 ناجحاً (4 جديدة لسياسة الاسترداد)؛ build apk --debug نجح.
- لم يُجرَّب: أي شيء أصلي على جهاز (الاسترداد/النقل الفعلي، الدمج).

## F6 (ربط الشاشة بالمُسجِّل، Dart فقط) (2026-11-14): مكتمل بالمزيّفات، لم يُجرَّب على جهاز

### المنجز
- home_controller: عدّ تنازلي 3-2-1 (يُلغى بلمسة) ثم `recorder.start` (الجودة والكتم) ثم `TripRepository.startTrip`؛ كل نقطة GPS مقبولة تُحفظ بـ`addPoints` بالتسلسل (فشل الحفظ لا يوقف التسجيل)؛ المسافة تراكمية؛ الكتم أثناء التسجيل يصل لـ`setMuted`؛ اهتزاز خفيف عند البدء.
- home_screen: التقاط `RepaintBoundary.toImage` كل 500ms (map_frame_capturer.dart) بعرض نصف اللوحة (640/960) ودفعه عبر `pushMapFrame`؛ حوار تأكيد (متابعة/إنهاء وحفظ) والتسجيل مستمر خلفه؛ طبقة "جارٍ الحفظ"؛ Snackbar عند فشل البدء.
- الإيقاف: `recorder.stop` ثم `completeTrip(videoPath)` ثم الانتقال إلى `/summary/:id`. فشل stop: المسار محفوظ والرحلة interrupted بلا فيديو وتظهر "حُفظ المسار لكن تعذّر حفظ الفيديو".
- حدث `interrupted` من المُسجِّل: `interruptTrip(videoPath)` (جديدة في TripRepository) + إغلاق الحوار إن كان مفتوحاً + ملخص برسالة حسب السبب (خلفية/كاميرا/كتابة/مساحة/غير ذلك).
- summary_screen: المدة والمسافة وخريطة المسار (بداية خضراء ونهاية حمراء وإسناد) وزر "رحلة جديدة" وزر "عرض الرحلة" (معطّل حتى F8/F9). `tripRepositoryProvider` يُستبدل في main وفي الاختبارات.
- نصوص جديدة في ARB (عربي وإنجليزي).

### تحقق فعلاً
- `flutter analyze` بلا ملاحظات؛ `flutter test`: 99 في الجذر (92 + 7 جديدة في f6_recording_test.dart: العدّ والإلغاء، التدفق الكامل، إطارات الخريطة بعرض 640، الانقطاع، فشل البدء، فشل stop، الكتم) واختبارات home القديمة عُدّلت لتمر بالعدّ والتأكيد.
- نسخة نظيفة من `git ls-files -co --exclude-standard`: analyze وtest (99) و`flutter build apk --debug` نجحت. .gitignore لا يتجاهل مجلد features/summary ولا ملفاتي الجديدة.

### لم يُنفَّذ / مخاطر
- لم يُجرَّب شيء على جهاز: لا فيديو فعلي ولا التقاط خريطة حقيقية بالبلاطات المتجهة ولا GPS ولا قناة أصلية. إطار 640x(ارتفاع حسب الشاشة) ~1.8MB x 2/ث عبر القناة: الأداء غير مقاس.
- حفظ الفيديو في الألبوم منفَّذ بالمزيّف فقط (انظر "إصلاحات المراجعة"): `gal` لا يعيد معرّفاً، فيبقى `videoAssetId` فارغاً مع الحزمة الحقيقية (يُخزَّن فقط إن أعادت الخدمة معرّفاً، والمزيّف يعيده). لا حفظ فعلي جُرِّب على جهاز.
- المؤقت عدّ ثوانٍ في Dart (لا ساعة المُسجِّل)؛ مدة الرحلة في DB من ساعة الجدار (بدء/إنهاء).
- غير موصول: فحص مساحة قبل البدء وتنبيهاتها (F8)، `recoverPending` عند الإقلاع، المشاركة وعرض الرحلة (F8/F9). "زرا المتابعة" فُسِّرا: رحلة جديدة + عرض الرحلة (معطّل).

### إصلاحات المراجعة + حفظ الألبوم (2026-11-14)
- _begin: علامة إلغاء تُفحص بعد `await rec.start` (وبعد startTrip) فيُوقَف المُسجِّل ولا تُنشأ رحلة؛ dispose بعد نجاح start يوقف المُسجِّل أيضاً؛ يُلتقط أي استثناء من start (لا RecorderException فقط) فتظهر رسالة فشل البدء؛ الاعتماديات تُلتقط قبل أي await (لا ref.read بعد dispose).
- stop/الانقطاع: completeTrip/interruptTrip داخل try/catch؛ عند الفشل احتياط interruptTrip بالمسار، ولا يبقى saving=true، وينتقل للملخص (رسالة `summaryDbError` إن فشل الاحتياط أيضاً).
- VideoGalleryService (data/gallery) خلف واجهة: Gal (حزمة gal 3.0.0) + Fake. الملخص: جارٍ الحفظ / تم الحفظ في ألبوم الجوال / فشل + زر إعادة المحاولة (GallerySaveController، مرة لكل رحلة في الجلسة). `summaryVideoSaved` استُبدل بـ`summaryGallerySaved`.
- أذونات: أندرويد WRITE_EXTERNAL_STORAGE بـmaxSdkVersion=28 فقط (بلا READ_EXTERNAL_STORAGE؛ 10+ عبر MediaStore بلا إذن)، مجلد Movies/Rihla. iOS: NSPhotoLibraryAddUsageDescription ثنائي اللغة؛ لا ألبوم مخصص على iOS عمداً (يتطلب إذن قراءة وكتابة كامل) فيظهر الفيديو في "الأحدث".
- تحقق: analyze بلا ملاحظات؛ test 108 ناجحاً (9 جديدة: إلغاء أثناء start، dispose، استثناء غير RecorderException، فشل completeTrip، فشل الاثنين، حفظ+معرّف، فشل ثم إعادة، جاري الحفظ، لا حفظ بلا فيديو).
- لم يُجرَّب: gal على جهاز (الإذن، ظهور الفيديو في المعرض)، تكرار الحفظ لو أُعيد فتح الملخص بعد إعادة تشغيل التطبيق (لا معرّف يمنعه مع gal).

## F0ب (أندرويد الأصلي، كود فقط) (2026-11-14): مبني ومُجمَّع، لم يُجرَّب على جهاز

### المنجز
- packages/rihla_recorder/android (Kotlin، CameraX 1.4.2 + MediaCodec + AudioRecord): `GlRenderer` (EGL/GLES2 على خيط واحد: نسيج الكاميرا OES ونسيج الخريطة RGBA؛ يرسم لسطح معاينة Flutter ولسطح المرمِّز لوحة 16:9: خريطة يسار "احتواء" وكاميرا يمين "قص مركزي" حسب D16)، `RecordingSession` (H.264 بمعدل 4/8Mbps، AAC 96kbps أحادي 44.1k، ساعة واحدة elapsedRealtime للصوت والفيديو، كتم = أصفار بالمدة نفسها، بلا ميكروفون = صمت مُسيَّر بالساعة)، `SegmentWriter` (مقاطع mp4 كل 60ث تبدأ بإطار مفتاحي، يُغلق كل مقطع بسليم ويُسجَّل في segments.txt)، `SegmentConcat` (دمج بلا إعادة ترميز بإزاحة الزمن؛ يحذف المقاطع تدريجياً إن ضاقت المساحة)، `RihlaRecorderPlugin` (قنوات `rihla_recorder` و`rihla_recorder/events`، Texture عبر SurfaceProducer، دقة 720/1080، تقدير الحجم والمساحة الحرة، فحص مساحة كل 5ث: تنبيه <1GB وإيقاف وحفظ <300MB، استرداد جلسات قُتلت عبر recoverPending).
- الانقطاع: ON_PAUSE للنشاط أو خطأ كاميرا أو فشل كتابة أو قلة مساحة يوقف التسجيل ويدمج ويحفظ ويرسل حدث `interrupted` مع الملف؛ ON_STOP يحرّر الكاميرا وON_START يعيد ربطها بنفس النسيج.
- Dart: `RihlaRecorder` (واجهة) + `MethodChannelRihlaRecorder` + `FakeRihlaRecorder` في packages/rihla_recorder/lib/src/recorder.dart. `NativeCameraPreviewSource` صار يستعمل المُسجِّل (Texture بـcover) بدل الـstub؛ `recorderProvider` في home_controller. الشاشة لا تزال "جلسة واجهة" ولم يُوصَّل start/stop/pushMapFrame بها (F6).

### تحقق فعلاً
- `flutter build apk --debug`: نجح (الإضافة مسجَّلة في GeneratedPluginRegistrant والـdex). نسخة نظيفة من `git ls-files -co --exclude-standard` في scratchpad: pub get وanalyze (بلا ملاحظات) وtest (92) وbuild apk وgradle test نجحت؛ .gitignore لا يتجاهل ملفات الإضافة.
- `flutter analyze` بلا ملاحظات؛ `flutter test`: 92 في الجذر (88 + 4 جديدة)، و15 في الحزمة (4 + 11 جديدة بقناة وهمية: المعاملات، الأخطاء، الأحداث، التقدير، المزيّف).
- Kotlin وحدة (`cd android && ./gradlew :rihla_recorder:testDebugUnitTest`): 10 ناجحة، للمنطق الصافي فقط: المنحنى الزمني/الساعة، الترتيب والعلامة المائية، سياسة المقاطع، سجل المقاطع، تخطيط القص/الاحتواء والمصفوفات، التقدير.

### لم يُختبر (لا جهاز ولا محاكي هنا): لا يُقال إنه يعمل
- فتح الكاميرا فعلاً، المعاينة (SurfaceProducer مع EGL)، اتجاه الصورة وقيمة rotationDegrees (طُبِّق 0/180 فقط للأفقي؛ 90/270 تقدير غير مجرَّب)، قص الكاميرا في الفيديو.
- ترميز H.264 على سطح EGL (مستوى/Profile على 1080p، EGL_RECORDABLE)، AAC، تزامن الصوت (<100ms غير مقيس)، الميكروفون والكتم.
- كتابة المقاطع ودمجها (MediaMuxer/MediaExtractor، الإزاحات، فتح الناتج في المعرض)، الاسترداد بعد القتل، الانقطاع (قفل، زر الرئيسية، مكالمة)، مراقبة المساحة، معدل الإطارات والحرارة.
- تمرير pushMapFrame بمعدل 2/ث (نسخ 1.8MB عبر القناة) وظهور الإسناد في الفيديو.
- iOS: غير منفَّذ (مهمة منفصلة؛ القناة والواجهة جاهزتان).

### قرارات تحتاج المعماري
- D17 (DECISIONS): مقاطع + دمج بلا ترميز بدل movie fragments (MediaMuxer لا يدعم fragmented mp4). الثمن: وقت دمج عند الإيقاف (يتناسب مع الحجم) وفقدان حتى ~60ث إن قُتلت العملية وليس انقطاعاً عادياً. البديل: media3 FragmentedMp4Muxer (اعتماد جديد).
- مكالمة واردة بلا تغيّر دورة النشاط (إشعار علوي) لا تُكتشف؛ ربط AudioFocus/AudioRecordingCallback غير منفَّذ (يُوقف موسيقى المستخدم أو يحتاج صلاحية).

## D16 + أول بناء APK (2026-11-14)
- D16: الفيديو يطابق الشاشة (خريطة يسار، كاميرا يمين). `DualCompositor.mapOnRight` افتراضيه false؛ حُدّث الاختباران وARCHITECTURE (7، 62، 64، F0أ). مخاطرة الإسناد (قرب منتصف الفيديو، يجب ألا تغطيه الكاميرا) موثّقة في D16 وتُفحص بصرياً في F0ب.
- Android SDK في scratchpad فقط (cmdline-tools، platform-tools، platforms 35/36/37.0، build-tools 35.0.0؛ CMake 3.22.1 نزّله gradle)، التراخيص قُبلت بموافقة المالك المسبقة، ANDROID_HOME لجلسة الأوامر فقط. JDK 21 موجود.
- `flutter build apk --debug`: المحاولة 1 فشلت (checkDebugAarMetadata): permission_handler_android يتطلب compileSdk 37 فأكثر والمشروع على 36 (flutter.compileSdkVersion). عُدّل android/app/build.gradle.kts إلى `compileSdk = 37` فنجح البناء: build/app/outputs/flutter-apk/app-debug.apk، 178,036,714 بايت (~170 MiB، debug). تنبيه: مضيفا dl.google.com وrepo.maven.apache.org أسقطا بعض الاتصالات (ws_closed_mid_exchange) أثناء المحاولة الأولى لكن gradle أعاد المحاولة ونجح. لم يُشغَّل على جهاز.
- analyze: بلا ملاحظات. test: 88 ناجحاً في الجذر + 4 في rihla_recorder.

## F5 الشاشة الرئيسية المقسومة + إصلاحات F4 (2026-11-14): منجز على المضيف، لا جهاز

### التحقق فعلاً (Linux، Flutter 3.50.0)
- `flutter pub get` نجح مع flutter_map 7.x وvector_map_tiles 8.0.0 وlatlong2 وgeolocator 14 وwakelock_plus وconnectivity_plus؛ `flutter analyze`: بلا ملاحظات (قبل وبعد الكود). هذا إثبات تحليل وتجميع فقط.
- `flutter test`: 88 ناجحاً (66 سابقة، اختبارات الرئيسية تغيّرت لاختفاء placeholder homeEmpty، + 22 جديداً). نسخة نظيفة من `git ls-files -co --exclude-standard` في scratchpad: pub get وanalyze وtest (88) نجحت؛ git check-ignore لا يتجاهل المجلدات الجديدة. check_no_secrets: OK.

### إصلاحات F4
- AndroidManifest: أُضيف ACCESS_COARSE_LOCATION بجانب FINE (وأُضيف INTERNET وACCESS_NETWORK_STATE لأن F5 يحتاجهما في بناء release، وsensorLandscape). Info.plist (آيفون) أفقي فقط.
- PermissionHandlerService: اكتشاف الموقع التقريبي عبر geolocator getLocationAccuracy (reduced يعني approximateOnly؛ unknown أو فشل الاستعلام يُعاملان دقيقاً). المنطق مختبَر بحقن دوال القراءة (6 اختبارات)؛ الاستدعاء الأصلي الحقيقي لم يُجرَّب على جهاز.
- **iOS عند أول بناء على macOS (لم يُنشأ الآن):** لا ios/Podfile في المستودع (يُولَّد). عند أول `flutter build ios`/pod install يجب إضافة في post_install: GCC_PREPROCESSOR_DEFINITIONS بـ`PERMISSION_CAMERA=1` و`PERMISSION_LOCATION=1` و`PERMISSION_MICROPHONE=1` (permission_handler)، وإلا تُعطَّل الأذونات. وقد يلزم تفعيل macros/Swift Package حسب إصدارات الحزم (تحقق عند البناء). مكتوب هنا فقط (F0ب).
- ربط /permissions بالإقلاع: أُنجز ضمن F5 (انظر أدناه)، لا داعي لتأجيله.

### F5 المنجز
- lib/features/home: HomeScreen (Row باتجاه LTR ثابت: خريطة يسار، كاميرا يمين، Expanded 1:1 = 50/50 لا ينعكس مع اللغة؛ مختبَر بالعربية والإنجليزية)، HomeController (Riverpod): GPS، الكاميرا، الشبكة، بدء/إيقاف، كتم، جودة 720/1080 (ورقة سفلية، معطلة أثناء التسجيل)، مؤقت ومسافة (core/geo) ومسار حي. شريط علوي HUD (مؤقت، مسافة، حالة GPS، مكتوم، إعدادات قبل البدء). أحجام: بدء/إيقاف 88، كتم وجودة 64، مسافات 16 (مختبَرة). رسالة سبب تعطيل البدء، "تعذّر فتح الكاميرا" + إعادة المحاولة، شريحة GPS ضعيف (البدء ممكن)، شريط "لا إنترنت". الشاشة تبقى مضاءة أثناء التسجيل (wakelock). أفقي فقط (SystemChrome + manifest + plist).
- RecordingMap (features/home/widgets): flutter_map + طبقة بلاطات OpenFreeMap (vector_map_tiles، نمط liberty) داخل RepaintBoundary بمفتاح قابل للتمرير (للالتقاط في F0ب/F6)، مسار كهرماني 6dp بحد داكن، نقطة موقعي بسهم الاتجاه، تتبع تلقائي وزر إعادة التمركز (يعود بعد 8ث)، الإسناد `OpenFreeMap © OpenMapTiles Data from OpenStreetMap` + `© OpenStreetMap contributors` مرسوم داخل الـRepaintBoundary أسفل اليمين (مختبَر: داخل الحدود، غير مقصوص، يلتصق بالحافة). نص الإسناد حرفي وليس في ARB عمداً (نص قانوني لا يُترجم).
- واجهات مجردة ونسخ مزيّفة: LocationSource (Geolocator/Fake)، CameraPreviewSource (Native/Fake)، MapTilesSource (OpenFreeMap/Fake)، NetworkStatusSource (connectivity_plus/Fake)، ScreenAwake (wakelock_plus/Fake). كل الاختبارات بالمزيّفة.
- الإقلاع: main يفحص الأذونات ويختار `initialLocationFor` (/permissions إن نقصت الكاميرا أو الموقع الدقيق؛ الميكروفون اختياري)؛ والرئيسية تُعيد الفحص عند الفتح والعودة من الإعدادات. بدون الكاميرا والموقع الدقيق لا يُشترك بـGPS ولا تُفتح الكاميرا ولا يبدأ شيء.

### لم يُنجز / تحفظات (مهم)
- **تعارض يحتاج قرار المعماري:** ARCHITECTURE 4.1 وDualCompositor (F0أ) يضعان الكاميرا يسار الفيديو والخريطة يمين، بينما DESIGN 7.2 وطلب F5 يضعان الكاميرا يمين والخريطة يسار "ليطابق الفيديو". نُفِّذت الشاشة حسب DESIGN/الطلب ولم يُعدَّل المُركِّب. يجب توحيد أحدهما قبل F6.
- **الكاميرا الحقيقية غير موجودة:** NativeCameraPreviewSource تفشل دائماً بـCameraOpenException عمداً (الإضافة الأصلية غير مبنية، D12). على جهاز حقيقي ستظهر "تعذّر فتح الكاميرا" ولن يمكن البدء حتى F0ب/F6. المعاينة مختبَرة بالمزيّفة فقط.
- **العرض الحقيقي للخريطة لم يُختبر:** الاختبارات تستخدم FakeMapTiles (بلا شبكة). لم يُعرض OpenFreeMap فعلاً ولا الأسماء العربية ولا toImage. توافق vector_map_tiles 8.0.0 مثبت بالتحليل والتجميع فقط، وقد يفشل وقت التشغيل (الاحتياطي: خلفية سادة عند فشل قراءة النمط، ثم احتياطيا ب/ج في ARCHITECTURE 4.2).
- User-Agent الذي يعرّف التطبيق لطلبات البلاطات (شرط OpenFreeMap) غير مضبوط: StyleReader لا يتيح رؤوساً، ومسار البلاطات يحتاج httpHeaders مخصصاً؛ يُضاف قبل الإطلاق/F0ب. ذاكرة البلاطات على القرص مضبوطة قصيرة (ساعة، 20MB) ولا استخدام دون اتصال ولا prefetch.
- العدّ التنازلي 3-2-1 وحوار تأكيد الإيقاف والاهتزاز ولوحة تقدير المساحة والخصوصية الأولى: خارج F5 (F6/F8). "بدء" الآن جلسة واجهة فقط: بلا ترميز ولا حفظ في DB (المؤقت عدّاد ثوانٍ يُستبدل بساعة التسجيل في F6). مؤشر المساحة في HUD غير موجود.
- مرجع GPS الضعيف: دقة > 50م (ثابت weakGpsAccuracyM). نقاط دقتها أسوأ لا تدخل المسار الحي (تحديث الموقع يستمر).
- الأذونات لا تُراقَب لحظياً أثناء التسجيل (فحص عند الفتح/الاستئناف فقط).
- لم يُشغَّل شيء على محاكي أو جهاز؛ الاختبارات ويدجت على Linux (800x360 و640x300 بخط 130%).

## F4 الأذونات (2026-11-14): منجز على المضيف، الطلب الفعلي لم يُختبر

### المنجز
- واجهة PermissionService (lib/data/permissions) + PermissionHandlerService (permission_handler ^13.0.2، حزمة مذكورة في ARCHITECTURE 2) + FakePermissionService للاختبار.
- lib/features/onboarding_permissions: PermissionsController (Riverpod) وPermissionsScreen: 3 خطوات (كاميرا، موقع، ميكروفون) بشرح قبل الطلب، حالات: ممنوح، مرفوض (إعادة محاولة + فتح الإعدادات)، رفض دائم (الإعدادات فقط)، موقع تقريبي (إعدادات)، ميكروفون مرفوض (شريحة "الصوت غير متاح" ومتابعة بلا صوت)، إعادة الفحص عند العودة من الإعدادات. canStartRecording = كاميرا + موقع دقيق. تخطيط أفقي بعمودين. مسار /permissions. نصوص عربي/إنجليزي في ARB. AndroidManifest (CAMERA، RECORD_AUDIO، ACCESS_FINE_LOCATION) وInfo.plist (3 نصوص ثنائية اللغة في نص واحد).
- `flutter analyze`: بلا ملاحظات. `flutter test`: 66 ناجحاً (13 جديداً في test/features/onboarding_permissions). نسخة نظيفة من الملفات المتتبَّعة (git ls-files -co) نجح فيها pub get وanalyze وtest. git check-ignore لا يُرجع شيئاً للمجلدات الجديدة.

### لم يُختبر / تحفظات
- نافذة طلب النظام الحقيقية، فتح إعدادات الجوال، وقراءة الحالات الحقيقية: لم تُجرَّب على جهاز (الاختبارات بالنسخة المزيّفة فقط).
- "الموقع التقريبي فقط": الواجهة تدعمه، لكن PermissionHandlerService لا يكشفه بعد (يحتاج geolocator/استعلاماً أصلياً)؛ لا يُعتمد عليه قبل F5.
- iOS: permission_handler يتطلب ماكرو PERMISSION_CAMERA/LOCATION/MICROPHONE=1 في ios/Podfile وإلا يُعطَّل الإذن؛ لا Podfile في المستودع (يُولَّد على macOS) فيُضاف عند أول بناء iOS (F0ب).
- نصوص iOS الثنائية في Info.plist نص واحد (عربي / إنجليزي)، لا InfoPlist.strings مترجمة لكل لغة (تحتاج تسجيلاً في Xcode).
- لم تُربط الشاشة بالتدفق: الرئيسية لا تحوّل إلى /permissions ولا تعطّل البدء بعد (زر البدء في F5)؛ provider جاهز (permissionsProvider.canStartRecording). لا عرض إذن مرفوض لاحقاً بعد الإعداد الأول بعد.
- INTERNET غير مضاف للـmanifest الرئيسي (خارج النطاق، ARCHITECTURE 8).

## تنظيف D15 + F3 (2026-11-14): منجز (على المضيف)

### تنظيف بقايا مفتاح جوجل
- حُذف lib/core/config/env.dart وtool/gen_secrets.sh؛ حُذف اختبار Env من test/f0a_composite_test.dart؛ حُذف android/secrets.properties وios/Flutter/Secrets.xcconfig (غير متتبَّعين، فارغا القيمة) وسطراهما من .gitignore. check_no_secrets.sh صار حارساً عاماً (AIza، AKIA، مفاتيح خاصة) بلا اعتماد على .env. لا CI فعلي (المسودة فقط، لا إشارات للمفتاح فيها). بقيت إشارات تاريخية في DECISIONS/ARCHITECTURE عمداً.

### F3 (قاعدة البيانات المحلية)
- drift + sqlite3_flutter_libs + path_provider + path (حزم). lib/data/db/app_database.dart (Trips، TrackPoints، فهرس فريد (tripId, seq)، FK مع CASCADE، PRAGMA foreign_keys، schemaVersion=1 مع onCreate/onUpgrade) وlib/data/repositories/trip_repository.dart (startTrip، addPoints بتصفية دقة>50م/إحداثيات غير صالحة/سرعة>100م/ث، completeTrip بالمسافة والمدة، markInterruptedTrips، getTrip/getPoints، watchTrips، deleteTrip). الملف المولَّد app_database.g.dart متتبَّع (انظر D13).
- `flutter analyze`: بلا ملاحظات. `flutter test`: 49 ناجحاً (9 جديدة في test/data/db_test.dart على قاعدة في الذاكرة).

### لم يُنجز / تحفظات
- التفضيلات (shared_preferences) ضمن صف F3 في ARCHITECTURE لم تُنفَّذ (لم تُحمَّل الحزمة؛ لا حاجة لها بعد).
- لا ترحيل فعلي بعد: الإصدار 1 فقط؛ الاختبار يتحقق من فتح قاعدة v1 قائمة فقط. أول تغيير جدول يضيف خطوة ترحيل واختبارها.
- ملف قاعدة البيانات على القرص (path_provider) لم يُوصَّل ولم يُجرَّب؛ الاختبارات في الذاكرة على sqlite المضيف. لم يُجرَّب على أندرويد/iOS. استدعاء markInterruptedTrips عند الإقلاع غير موصول بعد (F5/F6).
- ARCHITECTURE يذكر domain/trip.dart؛ استُخدمت صفوف drift (TripRow/TrackPointRow) مباشرة ولم تُنشأ طبقة domain.

## تغيير المزوّد D15 (2026-11-14): توثيق فقط، لا كود
- حُدِّثت ARCHITECTURE وDECISIONS (D15 يلغي D9/D4) وSPEC وCLAUDE وDESIGN و.env.example. F0ب لم تعد تحتاج مفتاحاً ولا فوترة (أجهزة فقط).
- لم يُشغَّل شيء: توافق flutter_map ^7 + vector_map_tiles مع Flutter 3.50 غير مُتحقَّق، ومعدل toImage والأسماء العربية غير مقاسين.
- كود قائم صار قديماً ويُنظَّف في مهمة لاحقة: lib/core/config/env.dart (hasMapsKey)، tool/gen_secrets.sh، android/secrets.properties، ios/Flutter/Secrets.xcconfig (غير متتبَّعان)، وأي إشارة لـGoogleSnapshotSource/google_maps_flutter في packages/rihla_recorder؛ وإبقاء check_no_secrets.sh حارساً عاماً. الاختبارات الحالية قد تحتاج تعديلاً.
- بانتظار المالك: موافقته على مراسلة info@openfreemap.org للتأكيد قبل الإطلاق (لم تُرسل).

## F2 + إصلاحات F1 (2026-11-14): منجز (على المضيف)

### تحقق فعلاً
- `flutter analyze`: بلا ملاحظات. `flutter test`: 35 ناجحاً (14 سابقة + 21 جديدة في test/core/geo/geo_test.dart).
- F2 (lib/core/geo، دوال نقية): haversine، طول المسار، المدة، Douglas-Peucker بتسامح وبعدد أقصى (تكراري)، رابط خرائط جوجل (3 نقاط منتصف افتراضياً، ≤2048، ترميز %7C و%2C)، GPX 1.1 مع هروب XML. travelmode=driving افتراضي (معامل قابل للتغيير). اختبارات GPX تحلّل المخرجات بحزمة xml (dev). عُثر بالاختبار على خلل فعلي (نقطة NaN ترمي RangeError في simplify) وأُصلح. حالات حدّية مختبرة: NaN، خارج النطاق، نقاط متطابقة، فارغ، نقطة، خط مستقيم، عبور خط التاريخ، مسار 20000 نقطة، عربي/رموز XML.
- (أ) D13 سُجّل. (ب) الخط IBM Plex Sans Arabic مضمَّن (400/600/700) من npm، مع OFL.txt؛ D14. (ج) مسودة CI في ci/rihla-ci.yml.draft فقط (لا .github).

### تحفظات
- الخط حُوِّل من woff إلى ttf بإعادة تغليف الجداول؛ لم يُختبر عرض الحرف العربي بصرياً على جهاز (الاختبارات لا تفحص الشكل).
- رابط الاتجاهات لم يُفتح فعلياً في تطبيق خرائط جوجل (F10)؛ الحد الفعلي لكل منصة يُثبَّت بالتجربة (D6). GPX لم يُجرَّب في Strava.
- CI لم يُشغَّل ولم يُضف للمستودع؛ بانتظار موافقة المالك.

## F1 (2026-11-14): منجز جزئياً (الهيكل)

### تحقق فعلاً (Linux، Flutter 3.50.0)
- `flutter analyze`: بلا ملاحظات (استُثنيت ملفات l10n المولَّدة من التحليل بسبب تحذيرات deprecation فيها).
- `flutter test`: 14 اختباراً ناجحاً (8 من F0أ + 6 جديدة في test/f1_shell_test.dart: ar/en، RTL/LTR، بلا overflow على 800x360 و640x300 بخط 130%، تنقل رئيسية/إعدادات/رجوع، صفحة 404، الثيم الداكن). `check_no_secrets.sh`: OK.
- المنجز: go_router (مساران + 404)، Riverpod (ProviderScope، localeProvider)، ثيم داكن بألوان DESIGN 2 وسلم الخطوط 3، ARB عربي (القالب) وإنجليزي، العربية افتراضية عند عدم دعم لغة النظام.

### لم يُنجز / لم يُختبر
- CI: مسودة فقط (انظر F2 أعلاه). الخط: صار مضمَّناً (D14).
- الوضع الفاتح، المجلدات الفارغة المذكورة في ARCHITECTURE 3 (تُنشأ مع ميزاتها)، شاشة "لا إنترنت" (DESIGN 8.3) لم تُبنَ.
- لا تشغيل على محاكي/جهاز (D12)؛ الاختبارات ويدجت فقط.
- قياس التباين على جهاز لم يُجرَ.

## F0أ (2026-11-14): منجز جزئياً، على المضيف فقط

### تحقق فعلاً (Linux، Flutter 3.50.0)
- `flutter analyze`: بلا ملاحظات، في المشروع والحزمة.
- `flutter test`: المشروع 8 اختبارات ناجحة (تشمل ترميز ملف فعلي بـffmpeg/ffprobe المضيف: 16:9، المدة، 30fps، مسار صوت، تزامن)؛ الحزمة 4 اختبارات ناجحة (packages/rihla_recorder/test).
- المُركِّب 16:9، المصادر الاصطناعية، FakeMapFrameSource، حقن المفتاح بلا مفتاح.

### لم يُختبر
- الجزء الأصلي Kotlin/Swift: غير مبني أصلاً (لا مجلد android/ios في الحزمة) ولم يُحلَّل.
- المحاكي والجهاز الحقيقي، الكاميرا والصوت الحقيقيان.
- GoogleSnapshotSource/takeSnapshot، معدل الالتقاط، شعار جوجل، الحرارة، الحجم.
- كل ذلك في F0ب (يحتاج Android SDK/macOS، أجهزة، ومفتاح المالك). انظر D12.

### فحص بيئة
- تنزيل Android command-line tools من dl.google.com ممكن (HTTP 200، zip سليم 153MB). لم تُقبل التراخيص ولم يُثبَّت شيء.

## F3 إصلاحات المراجعة (2026-11-14، محاولة 2)

- .gitignore: سطر `data/` كان في .gitignore جذر المستودع (السطر 5) لا في apps/rihla. أُضيف `!data/` في apps/rihla/.gitignore؛ `git check-ignore` لا يُرجع شيئاً لملفات lib/data وtest/data، وتظهر `??` في git status. clone نظيف (git ls-files) نجح فيه pub get وanalyze (بلا ملاحظات) وtest (52 ناجحاً). ملاحظة: سطر الجذر نفسه لم يُعدَّل (خارج النطاق).
- markInterruptedTrips: تضبط endedAt (آخر نقطة أو البدء) وdurationSec وdistanceM. addPoints: تسلسل لكل رحلة (سلسلة Futures). مرجع الجودة: بعد 3 قفزات متسقة تُعاد التثبيت، وتُحذف النقطة الأولى إن كانت الوحيدة (الشاذة). 3 اختبارات جديدة.
- main: يفتح القاعدة على القرص (lib/data/db/open_database.dart) ويستدعي markInterruptedTrips عند الإقلاع. لم يُشغَّل على جهاز؛ مسار createInBackground/path_provider غير مختبر فعلاً (الاختبارات بذاكرة فقط). المستودع لم يُربط بـProvider بعد (ينتظر واجهة F4).
- ملاحظة: drift يعيد DateTime محلية لا UTC (نفس اللحظة).

## Kotlin: إصلاحات المراجعة (محاولة 2، 2026-11-14): لم يُجرَّب على جهاز
- RecordingSession.start: تنظيف كامل عند أي فشل (مرمِّزات، خيوط، سطح الإدخال، مجلد العمل)؛ الخيوط تُقطع بـaborted ولا تُغلق المرمِّزات وخيط حيّ. الـplugin يعيّن session قبل start ويصفّرها عند الفشل، فـonFatal المبكر يمر عبر finishRecording.
- ensureRenderer: renderer لا يُعيَّن إلا بعد نجاح كل شيء، وإلا يُحرَّر المُصيِّر والمنتج. closeCamera يفكك المُصيِّر وSurfaceProducer وخيط GL (ويحفظ تسجيلاً نشطاً). onDetachedFromEngine يغلق executor (daemon + shutdown). أُضيف SurfaceProducer.Callback لإعادة setPreviewSurface.
- SegmentConcat: ملف ".part" يُحذف عند الفشل ويُعاد تسميته عند النجاح؛ لا حذف تدريجي للمصادر (إن لم تتسع المساحة يُرفض الدمج وتبقى المقاطع لـrecoverPending)؛ صوت أول مقطع الغائب يُعالَج بفحص مسبق. SegmentWriter: فشل muxer.stop يحذف المقطع ويُحسب في skippedSegments ويُرسل حدث segmentLost (يتجاهله Dart حالياً).
- stop(): مهل join تنتهي بقطع الخيوط؛ أخطاء الكاميرا القابلة للتعافي (CAMERA_IN_USE...) لا توقف التسجيل. انجراف الصوت: AudioRecord.getTimestamp + AudioPtsTracker (مزامنة عند انحراف >40ms).
- توصية (غير منفذة، القناة لم تتغير): تقليل حجم إطار الخريطة عبر pushMapFrame (نصف الدقة أو ضغط) لخفض نسخ RGBA الكبيرة عبر القناة.
- تحقق: gradlew :rihla_recorder:testDebugUnitTest ناجح (14 اختباراً)، flutter analyze/test (الحزمة 15 والجذر 99) وbuild apk --debug ناجحة. المنطق الصرف فقط مُختبر؛ الكاميرا والترميز والدمج بلا اختبار حتى جهاز.

## Kotlin: إصلاحات المراجعة (محاولة 3، 2026-11-14): لم يُجرَّب على جهاز
- SegmentWriter: إزاحة المقطع المغلق تُحسب من بداية المقطع المفتوح (SegmentTimeline.curStartUs يُضبط في markOpened) لا من حالة السياسة بعد قرار ROTATE؛ اختبار وحدة لتسجيل أطول من segmentSeconds (إزاحات تزايدية).
- SegmentConcat: استُبدل Files.move (API 26) بـrenameTo مع حذف الهدف ثم نسخ+حذف عند الفشل (minSdk 24).
- openCamera: فشل بعد ensureRenderer يستدعي releaseCamera (المُصيِّر وSurfaceProducer وخيط GL).
- recoverPending: عداد محاولات في recover_attempts داخل مجلد الجلسة؛ بعد 3 محاولات فاشلة يُحذف المجلد.
- onDetachedFromEngine: RejectedExecutionException مُعالَج.
- مهلة stop: أسوأ حالة أصلية ~ 3+5+5 ث انضمام + دمج؛ لا مهلة في Dart للحزمة (_call بلا timeout) ولا في lib الجذر (بُحث ولم يوجد timeout)، فلا تعديل.
