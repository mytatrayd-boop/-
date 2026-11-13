import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../engine/adhan.dart';
import '../engine/asset_loader.dart';
import '../engine/prayer.dart';
import '../engine/schedule.dart';
import '../engine/arabic.dart';
import '../engine/settings.dart';
import '../engine/weather.dart';
import '../engine/widget_theme.dart';
import 'adhan_service.dart';
import 'app_settings.dart';
import 'cities.dart';
import 'places.dart';
import 'services.dart';

final engineDataProvider = FutureProvider<EngineData>((ref) => loadEngineData());

final citiesProvider = FutureProvider<List<City>>(
    (ref) async => parseCities(await rootBundle.loadString('assets/cities.json')));

final preferencesProvider =
    FutureProvider<SharedPreferences>((ref) => SharedPreferences.getInstance());

final widgetBridgeProvider = Provider<WidgetBridge>((ref) => HomeWidgetBridge());

final locationServiceProvider =
    Provider<LocationService>((ref) => GeolocatorLocationService());

final backgroundStoreProvider =
    Provider<BackgroundStore>((ref) => AppGroupBackgroundStore());

final placeGeocoderProvider =
    Provider<PlaceGeocoder>((ref) => GeocodingPlaceGeocoder());

final compassSourceProvider =
    Provider<CompassSource>((ref) => defaultTargetPlatform == TargetPlatform.iOS
        ? IosHeadingSource()
        : FlutterCompassSource());

final declinationProvider =
    Provider<DeclinationSource>((ref) => AndroidDeclinationSource());

final widgetLaunchProvider = Provider<WidgetLaunch>((ref) => HomeWidgetLaunch());

final weatherServiceProvider =
    Provider<WeatherService>((ref) => OpenMeteoWeatherService());

final systemColorsProvider =
    Provider<SystemColorsSource>((ref) => AndroidSystemColorsSource());

final vibrationProvider = Provider<Vibration>((ref) => DeviceVibration());

final notificationPermissionProvider =
    Provider<NotificationPermission>((ref) => AndroidNotificationPermission());

/// جدولة الأذان بالإشعارات المحلية؛ بلا منصة (ويب، سطح مكتب) أو قبل جاهزية التخزين: لا شيء.
/// آخر خطأ في جدولة الأذان أو تجربته (يُعرض في الإعدادات)؛ يُبطَل بعد كل جدولة أو تجربة.
final adhanErrorProvider = FutureProvider.autoDispose<String?>((ref) => ref.watch(adhanNotifierProvider).lastError());

final adhanNotifierProvider = Provider<AdhanNotifier>((ref) {
  final prefs = ref.watch(preferencesProvider).value;
  final mobile = !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);
  if (prefs == null || !mobile) return NoopAdhanNotifier();
  return LocalAdhanNotifier(prefs);
});

/// مفتاح آخر قراءة طقس في shared_preferences.
const weatherPrefsKey = 'weather';

/// الساعة (تُثبَّت في الاختبارات).
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// عدد أيام الجدول المحفوظ للودجت (ARCHITECTURE).
const scheduleDays = 30;

class AppState {
  const AppState({
    required this.settings,
    required this.schedule,
    required this.cities,
    required this.data,
    this.backgroundPath,
    this.systemColors,
  });

  final LamhaSettings settings;

  /// الجدول كما يُحفظ للودجت؛ المعاينة تُبنى منه.
  final Map<String, Object?> schedule;
  final List<City> cities;
  final EngineData data;

  /// المسار الكامل للقطة الخلفية للمعاينة فقط (لا يُحفظ).
  final String? backgroundPath;

  /// ألوان النظام (أندرويد ١٢+) لسمة «ألوان النظام» في المعاينة.
  final SystemColors? systemColors;
}

/// نتيجة «موقعي»: [named] باسم من geocoding، و[nearest] باسم أقرب مدينة («قرب ...»).
enum LocationResult { named, nearest, denied, failed }

/// معرّفا المكان غير الموجود في قائمة المدن.
const gpsPlaceId = 'gps';
const searchPlaceId = 'search';

class SettingsController extends AsyncNotifier<AppState> {
  late SharedPreferences _prefs;
  String? _backgroundPath;
  WeatherReading? _weather;
  SystemColors? _systemColors;

  /// اللقطة لآيفون فقط؛ في أندرويد `background` في الجدول null.
  bool get _ios => defaultTargetPlatform == TargetPlatform.iOS;

  @override
  Future<AppState> build() async {
    final data = await ref.watch(engineDataProvider.future);
    final cities = await ref.watch(citiesProvider.future);
    _prefs = await ref.watch(preferencesProvider.future);
    final saved = _prefs.getString(LamhaSettings.prefsKey);
    var settings = saved == null
        ? LamhaSettings.defaults(cities.first, data.deposits.defaultIds)
        : LamhaSettings.fromJson(jsonDecode(saved) as Map<String, dynamic>);
    // إيداع محفوظ لم يعد في deposits.json لا يُكسر الجدول.
    final known = settings.deposits.intersection(data.deposits.ids);
    if (known.length != settings.deposits.length) {
      settings = settings.copyWith(
          deposits: known.isEmpty ? data.deposits.defaultIds : known);
    }
    final bg = settings.backgroundFile;
    if (_ios && bg != null) {
      try {
        _backgroundPath = await ref.read(backgroundStoreProvider).resolve(bg);
      } on Exception catch (e) {
        debugPrint('background: $e');
      }
    }
    final w = _prefs.getString(weatherPrefsKey);
    if (w != null) {
      try {
        _weather = WeatherReading.fromJson(jsonDecode(w) as Map<String, dynamic>);
      } on Object catch (e) {
        debugPrint('weather prefs: $e');
      }
    }
    _systemColors = await ref.read(systemColorsProvider).read();
    final s = _state(settings, cities, data);
    // يُبنى الجدول ويُحفظ عند فتح التطبيق (ARCHITECTURE: متى يُحسب الجدول).
    await _publish(s);
    // الطقس عند فتح التطبيق، دون انتظار.
    unawaited(Future(refreshWeather));
    return s;
  }

  AppState _state(LamhaSettings s, List<City> cities, EngineData data) {
    final now = ref.read(clockProvider)();
    return AppState(
      settings: s,
      schedule: buildSchedule(
        now,
        s.toEngine(withBackground: _ios),
        data,
        days: scheduleDays,
        generatedAt: now,
        weather: _weather,
      ),
      cities: cities,
      data: data,
      backgroundPath: _ios ? _backgroundPath : null,
      systemColors: _systemColors,
    );
  }

  /// آخر حفظ للودجت؛ الحفظات تتسلسل فلا يتداخل حفظان ويبقى الأخير هو الأحدث.
  Future<void> _queued = Future<void>.value();

  /// يحفظ أحدث حالة للودجت بعد الحفظات السابقة.
  Future<void> _publishLatest() => _queued = _queued.then((_) {
        if (!ref.mounted || !state.hasValue) return null;
        return _publish(state.requireValue);
      });

  /// حفظ الحالة الحالية الآن (عند إفلات شريط التمرير).
  Future<void> commitNow() => _publishLatest();

  /// يحفظ الإعدادات، ثم الجدول للودجت، ثم يطلب تحديثها.
  Future<void> _publish(AppState s) async {
    await _prefs.setString(LamhaSettings.prefsKey, s.settings.encode());
    final bridge = ref.read(widgetBridgeProvider);
    try {
      await bridge.saveSchedule(jsonEncode(s.schedule), opacity: s.settings.opacity);
      await bridge.requestUpdate();
    } catch (e) {
      // فشل الحفظ للودجت لا يوقف التطبيق.
      debugPrint('home_widget: $e');
    }
    await _syncAdhan(s);
  }

  /// بصمة آخر جدولة للأذان: لا تُعاد الجدولة مع حفظ لا يمسّ الأذان (الشفافية مثلاً).
  String? _adhanSignature;

  /// يجدوِل تنبيهات الأذان القادمة من أوقات الصلاة والإعدادات (عند الفتح وبعد كل تغيير).
  Future<void> _syncAdhan(AppState s) async {
    try {
      final a = s.settings.adhan;
      final calc = PrayerCalculator(
        latitude: s.settings.latitude,
        longitude: s.settings.longitude,
        timeZoneName: s.settings.timeZone,
        method: s.settings.prayerMethod,
        isRamadan: (d) => s.data.hijri.tryConvert(d)?.month == 9,
      );
      final events = planAdhan(calc, ref.read(clockProvider)(), a);
      final signature = adhanSignature(events, a.sound, s.settings.cityName);
      if (signature == _adhanSignature) return;
      _adhanSignature = signature;
      await ref.read(adhanNotifierProvider).apply(events, a.sound, s.settings.cityName);
      ref.invalidate(adhanErrorProvider);
    } catch (e) {
      // الأذان لا يوقف التطبيق.
      debugPrint('adhan: $e');
    }
  }

  Future<void> _update(LamhaSettings s, {bool commit = true}) async {
    final cur = state.requireValue;
    final next = _state(s, cur.cities, cur.data);
    state = AsyncData(next);
    if (commit) await _publishLatest();
  }

  /// تغيير لا يمسّ الأيام (الشفافية والتخطيط والعدّاد): يعدّل مفاتيحه في الجدول الجاهز فقط، فلا يُعاد
  /// حساب ٣٠ يوماً (٢٣ مللي ثانية لكل نقلة شريط) وتبقى المعاينة فورية. النتيجة تطابق بناءً كاملاً
  /// (يتحقق منه اختبار).
  Future<void> _updateLight(LamhaSettings s, {bool commit = true}) async {
    final cur = state.requireValue;
    final layout = normalizeLayout(s.layout);
    final fixed = s.copyWith(layout: layout);
    final schedule = <String, Object?>{
        ...cur.schedule,
        'opacity': fixed.opacity,
        if (fixed.frame != null) 'frame': fixed.frame!.toJson(),
        // كما يبنيها buildSchedule: المستطيلات الفعلية والشجرة.
        'layout': [for (final t in withRects(layout, rectsOf(layout))) t.toScheduleJson()],
        'grid': [freeCols, freeRows],
        'tree': (cutTree(rectsOf(layout)) ?? const CutNode.empty()).toJson(),
        'visible': {
          for (final e in WidgetElement.values)
            e.name: layout.any((t) => t.id == e && t.visible),
        },
    };
    // إطار الخلفية المُعاد للكامل لا يبقى في الجدول من التحديث السابق.
    if (fixed.frame == null) schedule.remove('frame');
    state = AsyncData(AppState(
      settings: fixed,
      schedule: schedule,
      cities: cur.cities,
      data: cur.data,
      backgroundPath: cur.backgroundPath,
      systemColors: cur.systemColors,
    ));
    if (commit) await _publishLatest();
  }

  LamhaSettings get _s => state.requireValue.settings;

  /// أثناء السحب [commit] = false (المعاينة فقط)، وعند الإفلات يُحفظ.
  Future<void> setOpacity(int value, {bool commit = true}) =>
      _updateLight(_s.copyWith(opacity: value.clamp(0, 100)), commit: commit);

  /// إطار الخلفية الحر (DECISIONS ٣٠): [r] مكان لوحة الخلفية ومقاسها؛ null يعيدها لتملأ الودجت. العناصر
  /// الداخلية لا تتأثر. أثناء السحب [commit] = false.
  Future<void> setFrame(FloatRect? r, {bool commit = true}) => _updateLight(
        r == null ? _s.copyWith(clearFrame: true) : _s.copyWith(frame: r),
        commit: commit,
      );

  /// يغيّر إعدادات الأذان. عند تفعيله أول مرة يطلب الأذونات؛ إن رُفض إذن الإشعارات يبقى مطفأً.
  /// يعيد نتيجة طلب الأذونات (null إن لم يُطلب شيء) ليعرض التطبيق ما ينقص.
  Future<AdhanPermissionResult?> setAdhan(AdhanSettings a) async {
    AdhanPermissionResult? permissions;
    var next = a;
    if (a.enabled && !_s.adhan.enabled) {
      permissions = await ref.read(adhanNotifierProvider).requestPermissions();
      if (!permissions.notifications) next = a.copyWith(enabled: false);
    }
    await _updateLight(_s.copyWith(adhan: next));
    return permissions;
  }

  /// تنبيه فوري بالصوت المختار.
  Future<void> testAdhan() async {
    await ref.read(adhanNotifierProvider).test(_s.adhan.sound);
    ref.invalidate(adhanErrorProvider);
  }

  Future<void> setCity(City c) async {
    await _update(_s.copyWith(
      cityId: c.id,
      cityName: c.name,
      latitude: c.latitude,
      longitude: c.longitude,
      timeZone: c.timeZone,
    ));
    await refreshWeather();
  }

  /// يجلب الطقس للمدينة الحالية ويحفظه في الإعدادات والجدول. بلا إنترنت تبقى آخر قراءة.
  /// يعيد true عند النجاح.
  Future<bool> refreshWeather() async {
    if (!state.hasValue) return false;
    final s = _s;
    final WeatherReading r;
    try {
      r = await ref.read(weatherServiceProvider).current(s.latitude, s.longitude);
    } catch (e) {
      debugPrint('weather: $e');
      return false;
    }
    if (!ref.mounted || !state.hasValue) return false;
    _weather = r;
    await _prefs.setString(weatherPrefsKey, jsonEncode(r.toJson()));
    // المدينة تغيّرت أثناء الجلب: القراءة لا تُعرض لها (isFor في الجدول).
    await _update(_s);
    return true;
  }

  Future<void> setTheme(WidgetTheme t) => _update(_s.copyWith(theme: t));

  Future<void> setFontScale(FontScale f) => _update(_s.copyWith(fontScale: f));

  Future<void> setDigits(DigitStyle d) => _update(_s.copyWith(digits: d));

  /// عند التشغيل يُطلب إذن الإشعارات (أندرويد ١٣+)؛ يعيد false إذا رُفض.
  Future<bool> setLockNotification(bool on) async {
    if (on) {
      bool granted;
      try {
        granted = await ref.read(notificationPermissionProvider).request();
      } catch (e) {
        debugPrint('notification permission: $e');
        granted = false;
      }
      if (!granted) return false;
    }
    await _update(_s.copyWith(lockNotification: on));
    return true;
  }

  /// مكان من البحث أو من الموقع: إحداثياته الفعلية، وتوقيت الرياض (المدن سعودية).
  Future<void> setPlace(Place p, {String id = searchPlaceId}) async {
    await _update(_s.copyWith(
      cityId: id,
      cityName: p.name,
      latitude: p.latitude,
      longitude: p.longitude,
      timeZone: state.requireValue.cities.first.timeZone,
    ));
    await refreshWeather();
  }

  /// قراءة واحدة للموقع، والحساب بإحداثياته الفعلية. الاسم من geocoding بالعربية،
  /// وإن تعذّر فـ[nearLabel] لأقرب مدينة في القائمة (مثل «قرب أبها»).
  Future<LocationResult> useMyLocation(
      {required String Function(String city) nearLabel}) async {
    final ({double latitude, double longitude})? p;
    try {
      p = await ref.read(locationServiceProvider).currentPosition();
    } catch (e) {
      debugPrint('location: $e');
      return LocationResult.failed;
    }
    if (p == null) return LocationResult.denied;
    String? name;
    try {
      name = await ref.read(placeGeocoderProvider).placeName(p.latitude, p.longitude);
    } catch (e) {
      // بلا إنترنت أو بلا خدمة geocoding: اسم أقرب مدينة.
      debugPrint('geocoding: $e');
    }
    final near = nearestCity(state.requireValue.cities, p.latitude, p.longitude);
    await setPlace(
      Place(name: name ?? nearLabel(near.name), latitude: p.latitude, longitude: p.longitude),
      id: gpsPlaceId,
    );
    return name == null ? LocationResult.nearest : LocationResult.named;
  }

  /// البحث عن مدينة أو محافظة؛ يرمي عند فشل الاتصال.
  Future<List<Place>> searchPlaces(String query) =>
      ref.read(placeGeocoderProvider).search(query);

  Future<void> setPrayerMethod(String id) =>
      _update(_s.copyWith(prayerMethod: id));

  /// تخطيط الودجت (الميزة ٥): إعدادات مربع واحد. [commit] = false أثناء سحب شريط (معاينة فقط).
  Future<void> updateTile(
          WidgetElement id, TileLayout Function(TileLayout t) change,
          {bool commit = true}) =>
      _updateLight(
          _s.copyWith(layout: [
            for (final t in _s.layout) t.id == id ? change(t) : t,
          ]),
          commit: commit);

  /// «ألوان جاهزة»: اللونان لكل العناصر في حفظ واحد (null = تلقائي).
  Future<void> applyColors(TileColor? primary, TileColor? secondary) =>
      _updateLight(_s.copyWith(layout: [
        for (final t in _s.layout)
          t.copyWith(primaryColor: () => primary, secondaryColor: () => secondary),
      ]));

  /// التخطيط الحر: يضع [id] في [target] (تحريك أو تكبير)، ويدفع ما يتداخل ثم يصعد الجميع. يعيد false
  /// دون حفظ إذا تعذر تقسيم الناتج صفوفاً وأعمدة (cutTree) فلا ترسمه الودجتان.
  Future<bool> placeTile(WidgetElement id, GridRect target) async {
    final min = minSize(id);
    final t = GridRect(target.x, target.y, target.w < min.w ? min.w : target.w, target.h < min.h ? min.h : target.h);
    final next = place(rectsOf(_s.layout), id, t);
    if (cutTree(next) == null) return false;
    await _updateLight(_s.copyWith(layout: withRects(_s.layout, next)));
    return true;
  }

  /// إظهار عنصر يضعه في أول فراغ (لا في مستطيله القديم فوق غيره).
  Future<void> setVisible(WidgetElement e, bool on) =>
      updateTile(e, (t) => t.copyWith(visible: on, rect: on ? () => null : null));

  /// العوم الحر لأي مربع (DECISIONS ٢٩): يطفو فوق المربعات بموضعه ومقاسه الحرّين خارج الرصّ، ويبدأ من مكانه
  /// ومقاسه الحاليين؛ إطفاؤه يعيده مربعاً عادياً في أول فراغ.
  Future<void> setFloating(WidgetElement id, bool on) {
    final current = rectsOf(_s.layout)[id];
    final l = [
      for (final t in _s.layout)
        if (t.id == id)
          on
              ? t.copyWith(
                  float: () {
                    if (t.float != null) return t.float;
                    final r = current ?? firstFit(defaultSize(id), const []);
                    return FloatRect(r.x / freeCols, r.y / freeRows, r.w / freeCols, r.h / freeRows);
                  },
                  rect: () => null)
              : t.copyWith(float: () => null, rect: () => null)
        else
          t,
    ];
    return _updateLight(_s.copyWith(layout: withRects(l, rectsOf(l))));
  }

  /// فصل «اليوم والطقس» (طلب المالك ١٣ نوفمبر) إلى مربعين مستقلين: «اليوم» في النصف الأعلى و«الموقع والحرارة» في
  /// الأسفل، في مكان المربع الأصلي نفسه (رصّ أو عائماً) وبألوانه وحجم خطه؛ ويُخفى الأصلي. لا يفعل شيئاً إن كانا
  /// ظاهرين من قبل.
  Future<void> splitDayWeather() async {
    final all = _s.layout;
    final src = all.firstWhere((t) => t.id == WidgetElement.dayWeather);
    TileLayout style(TileLayout t) => t.copyWith(
          visible: true,
          fontScale: src.fontScale,
          primaryColor: () => src.primaryColor,
          secondaryColor: () => src.secondaryColor,
        );
    final rect = rectsOf(all)[WidgetElement.dayWeather];
    final fl = src.float;
    var l = [
      for (final t in all)
        if (t.id == WidgetElement.dayWeather)
          t.copyWith(visible: false)
        else if (t.id == WidgetElement.weekday || t.id == WidgetElement.cityTemp)
          style(t)
        else
          t,
    ];
    if (fl != null) {
      // عائم: النصفان عائمان بمقاسه نفسه موزعين رأسياً.
      final half = fl.h / 2;
      l = [
        for (final t in l)
          if (t.id == WidgetElement.weekday)
            t.copyWith(float: () => FloatRect(fl.x, fl.y, fl.w, half), rect: () => null)
          else if (t.id == WidgetElement.cityTemp)
            t.copyWith(float: () => FloatRect(fl.x, fl.y + half, fl.w, half), rect: () => null)
          else
            t,
      ];
      return _updateLight(_s.copyWith(layout: withRects(l, rectsOf(l))));
    }
    // مرصوص: نصفان في مستطيله (ارتفاع الأعلى ≥ ١) ثم تُدفع المتداخلات فتصعد.
    final r = rect ?? firstFit(defaultSize(WidgetElement.dayWeather), const []);
    final h1 = (r.h ~/ 2).clamp(1, r.h);
    final h2 = (r.h - h1).clamp(1, r.h);
    var cur = rectsOf([for (final t in l) if (t.id != WidgetElement.weekday && t.id != WidgetElement.cityTemp) t]);
    cur = place(cur, WidgetElement.weekday, GridRect(r.x, r.y, r.w, h1));
    cur = place(cur, WidgetElement.cityTemp, GridRect(r.x, r.y + h1, r.w, h2));
    if (cutTree(cur) == null) {
      // تعذّر تقسيمها صفوفاً وأعمدة: رصّ بالصفوف فيبقى الودجت صالحاً.
      l = reflow(l);
      return _updateLight(_s.copyWith(layout: l));
    }
    await _updateLight(_s.copyWith(layout: withRects(l, cur)));
  }

  /// موضع المربع العائم ومقاسه (يُحفظ عند الإفلات؛ [commit] false أثناء السحب).
  Future<void> setFloat(WidgetElement id, FloatRect r, {bool commit = true}) => updateTile(
        id,
        (t) => t.floating ? t.copyWith(float: () => r) : t,
        commit: commit,
      );

  /// حجم أيقونة القبلة (٠٫٥–١٫٦)؛ عرض الخانة يتبعه تلقائياً (qiblaSpanFor).
  Future<void> setQiblaIconScale(double v, {bool commit = true}) =>
      updateTile(WidgetElement.qibla, (t) => t.copyWith(iconScale: v),
          commit: commit);

  /// نقل مربع من [from] إلى [to] (موضعه بعد حذفه من [from]، كـ onReorderItem).
  Future<void> moveTile(int from, int to) {
    final l = [..._s.layout];
    final t = l.removeAt(from);
    l.insert(to.clamp(0, l.length), t);
    // التخطيط الحر: الترتيب الجديد يُرصّ من جديد بمقاسات العناصر نفسها.
    return _updateLight(_s.copyWith(layout: reflow(l)));
  }

  Future<void> resetLayout() =>
      _updateLight(_s.copyWith(layout: defaultLayout));

  /// يعيد false إذا كان هذا آخر إيداع مفعّل (لا يُلغى).
  Future<bool> setDeposit(String id, bool on) async {
    final d = {..._s.deposits};
    if (!on && d.length == 1 && d.contains(id)) return false;
    on ? d.add(id) : d.remove(id);
    await _update(_s.copyWith(deposits: d));
    return true;
  }

  /// يعيد true إذا اختيرت صورة وحُفظت.
  /// يحفظ لقطة الخلفية المقصوصة [png] ويعيد رسم الودجت بها.
  Future<void> saveBackground(Uint8List png) async {
    final store = ref.read(backgroundStoreProvider);
    final name = await store.save(png);
    _backgroundPath = await store.resolve(name);
    await _update(_s.copyWith(backgroundFile: name));
  }

  /// حذف لقطة الخلفية والعودة للون السمة وحده (الملف يبقى في الحاوية ويُستبدل عند اختيار لقطة جديدة).
  Future<void> clearBackground() async {
    _backgroundPath = null;
    await _update(_s.copyWith(clearBackground: true));
  }
}

final settingsControllerProvider =
    AsyncNotifierProvider<SettingsController, AppState>(SettingsController.new);
